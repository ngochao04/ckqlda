// lib/screens/student_home.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import 'join_class_screen.dart';
import 'student_class_detail.dart';
import 'profile_screen.dart';
import 'login_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({Key? key}) : super(key: key);

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  List<Map<String, dynamic>> _classes = [];
  bool _isLoading = true;
  int? _studentId;
  String? _fullName;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      
      if (userId == null) {
        _logout();
        return;
      }

      // Lấy student_id từ login response hoặc từ database
      int? storedStudentId = prefs.getInt('student_id');
      
      if (storedStudentId == null) {
        // Nếu chưa có trong prefs, lấy từ database
        final conn = await DatabaseService.getConnection();
        final result = await conn.query(
          'SELECT id FROM students WHERE user_id = @uid',
          substitutionValues: {'uid': userId},
        );
        
        if (result.isEmpty) {
          throw Exception('Không tìm thấy thông tin sinh viên');
        }
        
        storedStudentId = result.first[0] as int;
        await prefs.setInt('student_id', storedStudentId);
      }
      
      setState(() {
        _studentId = storedStudentId;
        _fullName = prefs.getString('full_name');
      });
      
      _loadClasses();
    } catch (e) {
      print('Error loading user info: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${e.toString()}')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadClasses() async {
    if (_studentId == null) return;
    
    setState(() => _isLoading = true);
    try {
      final classes = await DatabaseService.getStudentClasses(_studentId!);
      
      if (mounted) {
        setState(() {
          _classes = classes;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading classes: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải danh sách lớp: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await DatabaseService.closeConnection();
    
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Lớp của tôi', style: TextStyle(fontSize: 18)),
            if (_fullName != null)
              Text(
                _fullName!,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
              // Reload name if changed
              final prefs = await SharedPreferences.getInstance();
              setState(() {
                _fullName = prefs.getString('full_name');
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _studentId == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text('Không tìm thấy thông tin sinh viên'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _logout,
                        child: const Text('Đăng nhập lại'),
                      ),
                    ],
                  ),
                )
              : _classes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.class_, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('Chưa tham gia lớp nào'),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => JoinClassScreen(studentId: _studentId!),
                                ),
                              );
                              if (result == true) _loadClasses();
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Tham gia lớp'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadClasses,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _classes.length,
                        itemBuilder: (context, index) {
                          final cls = _classes[index];
                          
                          // Safe casting - handle both int and BigInt from PostgreSQL
                          int totalSessions = 0;
                          int attendedSessions = 0;
                          
                          try {
                            final totalVal = cls['total_sessions_held'];
                            if (totalVal is int) {
                              totalSessions = totalVal;
                            } else if (totalVal is BigInt) {
                              totalSessions = totalVal.toInt();
                            } else if (totalVal != null) {
                              totalSessions = int.tryParse(totalVal.toString()) ?? 0;
                            }
                            
                            final attendedVal = cls['attended_sessions'];
                            if (attendedVal is int) {
                              attendedSessions = attendedVal;
                            } else if (attendedVal is BigInt) {
                              attendedSessions = attendedVal.toInt();
                            } else if (attendedVal != null) {
                              attendedSessions = int.tryParse(attendedVal.toString()) ?? 0;
                            }
                          } catch (e) {
                            print('Error parsing attendance data: $e');
                          }
                          
                          final attendanceRate = totalSessions > 0
                              ? (attendedSessions / totalSessions * 100)
                              : 0.0;
                          
                          Color rateColor;
                          if (attendanceRate >= 80) {
                            rateColor = Colors.green;
                          } else if (attendanceRate >= 50) {
                            rateColor = Colors.orange;
                          } else {
                            rateColor = Colors.red;
                          }

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: rateColor.withOpacity(0.1),
                                child: Text(
                                  '${attendanceRate.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: rateColor,
                                  ),
                                ),
                              ),
                              title: Text(
                                cls['class_name'],
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('GV: ${cls['teacher_name']}'),
                                  Text(
                                    'Có mặt: $attendedSessions/$totalSessions buổi',
                                    style: TextStyle(color: rateColor),
                                  ),
                                ],
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => StudentClassDetailScreen(
                                      classData: cls,
                                      studentId: _studentId!,
                                    ),
                                  ),
                                );
                                _loadClasses(); // Refresh after returning
                              },
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: _studentId != null
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => JoinClassScreen(studentId: _studentId!),
                  ),
                );
                if (result == true) _loadClasses();
              },
              icon: const Icon(Icons.add),
              label: const Text('Tham gia lớp'),
            )
          : null,
    );
  }
}