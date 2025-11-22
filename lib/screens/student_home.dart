import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import 'join_class_screen.dart';
import 'student_class_detail.dart';
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

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id')!;
      
      final conn = await DatabaseService.getConnection();
      final result = await conn.query(
        'SELECT id FROM students WHERE user_id = @uid',
        substitutionValues: {'uid': userId},
      );
      _studentId = result.first[0];
      
      final classes = await DatabaseService.getStudentClasses(_studentId!);
      setState(() {
        _classes = classes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
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
        title: const Text('Lớp của tôi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _classes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.class_, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('Chưa tham gia lớp nào'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => JoinClassScreen(studentId: _studentId!),
                            ),
                          );
                          _loadClasses();
                        },
                        child: const Text('Tham gia lớp'),
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
                      final attendanceRate = cls['total_sessions_held'] > 0
                          ? (cls['attended_sessions'] / cls['total_sessions_held'] * 100).toStringAsFixed(1)
                          : '0.0';
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: double.parse(attendanceRate) >= 80
                                ? Colors.green
                                : Colors.orange,
                            child: Text(
                              '$attendanceRate%',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
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
                              Text('Có mặt: ${cls['attended_sessions']}/${cls['total_sessions_held']} buổi'),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StudentClassDetailScreen(
                                  classData: cls,
                                  studentId: _studentId!,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => JoinClassScreen(studentId: _studentId!),
            ),
          );
          _loadClasses();
        },
        icon: const Icon(Icons.add),
        label: const Text('Tham gia lớp'),
      ),
    );
  }
}