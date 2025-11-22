import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import 'create_class_screen.dart';
import 'class_detail_screen.dart';
import 'login_screen.dart';

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({Key? key}) : super(key: key);

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  List<Map<String, dynamic>> _classes = [];
  bool _isLoading = true;
  int? _teacherId;

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
      
      // Lấy teacher_id
      final conn = await DatabaseService.getConnection();
      final result = await conn.query(
        'SELECT id FROM teachers WHERE user_id = @uid',
        substitutionValues: {'uid': userId},
      );
      _teacherId = result.first[0];
      
      final classes = await DatabaseService.getTeacherClasses(_teacherId!);
      setState(() {
        _classes = classes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
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
                      const Text('Chưa có lớp nào'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CreateClassScreen(teacherId: _teacherId!),
                            ),
                          );
                          _loadClasses();
                        },
                        child: const Text('Tạo lớp đầu tiên'),
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
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text('${index + 1}'),
                          ),
                          title: Text(
                            cls['class_name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Mã: ${cls['class_code']}'),
                              Text('SV: ${cls['enrolled_students']} | '
                                  'Buổi: ${cls['completed_sessions']}/${cls['total_sessions']}'),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ClassDetailScreen(classData: cls),
                              ),
                            ).then((_) => _loadClasses());
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
              builder: (_) => CreateClassScreen(teacherId: _teacherId!),
            ),
          );
          _loadClasses();
        },
        icon: const Icon(Icons.add),
        label: const Text('Tạo lớp'),
      ),
    );
  }
}