// lib/screens/teacher_home.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import 'create_class_screen.dart';
import 'class_detail_screen.dart';
import 'edit_class_screen.dart';
import 'class_stats_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({Key? key}) : super(key: key);

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  List<Map<String, dynamic>> _classes = [];
  bool _isLoading = true;
  int? _teacherId;
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

      // Lấy teacher_id từ login response hoặc từ database
      int? storedTeacherId = prefs.getInt('teacher_id');
      
      if (storedTeacherId == null) {
        // Nếu chưa có trong prefs, lấy từ database
        final conn = await DatabaseService.getConnection();
        final result = await conn.query(
          'SELECT id FROM teachers WHERE user_id = @uid',
          substitutionValues: {'uid': userId},
        );
        
        if (result.isEmpty) {
          throw Exception('Không tìm thấy thông tin giảng viên');
        }
        
        storedTeacherId = result.first[0] as int;
        await prefs.setInt('teacher_id', storedTeacherId);
      }
      
      setState(() {
        _teacherId = storedTeacherId;
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
    if (_teacherId == null) return;
    
    setState(() => _isLoading = true);
    try {
      final classes = await DatabaseService.getTeacherClasses(_teacherId!);
      
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
          SnackBar(content: Text('Lỗi: $e')),
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

  void _showClassOptions(Map<String, dynamic> cls) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Chỉnh sửa lớp'),
              onTap: () async {
                Navigator.pop(context);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditClassScreen(classData: cls),
                  ),
                );
                if (result == true) _loadClasses();
              },
            ),
            ListTile(
              leading: const Icon(Icons.assessment, color: Colors.green),
              title: const Text('Xem thống kê'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClassStatsScreen(
                      classId: cls['id'],
                      className: cls['class_name'],
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info, color: Colors.orange),
              title: const Text('Chi tiết lớp'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClassDetailScreen(classData: cls),
                  ),
                ).then((_) => _loadClasses());
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.grey),
              title: const Text('Hủy'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
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
          : _teacherId == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text('Không tìm thấy thông tin giảng viên'),
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
                          const Text('Chưa có lớp nào'),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CreateClassScreen(teacherId: _teacherId!),
                                ),
                              );
                              _loadClasses();
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Tạo lớp đầu tiên'),
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
                          final totalSessions = cls['total_sessions'] as int? ?? 0;
                          final completedSessions = cls['completed_sessions'] as int? ?? 0;
                          final enrolledStudents = cls['enrolled_students'] as int? ?? 0;
                          
                          final progress = totalSessions > 0 
                              ? (completedSessions / totalSessions * 100).toStringAsFixed(0)
                              : '0';

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ClassDetailScreen(classData: cls),
                                  ),
                                ).then((_) => _loadClasses());
                              },
                              onLongPress: () => _showClassOptions(cls),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            cls['class_name'],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.more_vert),
                                          onPressed: () => _showClassOptions(cls),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(Icons.key, size: 16, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          cls['class_code'],
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Icon(Icons.people, size: 16, color: Colors.blue),
                                        const SizedBox(width: 4),
                                        Text('$enrolledStudents SV'),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Tiến độ: $completedSessions/$totalSessions buổi',
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                              const SizedBox(height: 4),
                                              LinearProgressIndicator(
                                                value: totalSessions > 0 
                                                    ? completedSessions / totalSessions 
                                                    : 0,
                                                backgroundColor: Colors.grey.shade200,
                                                color: Colors.green,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Text(
                                          '$progress%',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: _teacherId != null
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateClassScreen(teacherId: _teacherId!),
                  ),
                );
                _loadClasses();
              },
              icon: const Icon(Icons.add),
              label: const Text('Tạo lớp'),
            )
          : null,
    );
  }
}