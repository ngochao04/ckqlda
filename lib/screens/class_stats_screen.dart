// lib/screens/class_stats_screen.dart
import 'package:flutter/material.dart';
import '../services/database_service.dart';

class ClassStatsScreen extends StatefulWidget {
  final int classId;
  final String className;

  const ClassStatsScreen({
    Key? key,
    required this.classId,
    required this.className,
  }) : super(key: key);

  @override
  State<ClassStatsScreen> createState() => _ClassStatsScreenState();
}

class _ClassStatsScreenState extends State<ClassStatsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _studentStats = [];
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final stats = await DatabaseService.getClassAttendanceStats(widget.classId);
      final sessions = await DatabaseService.getSessions(widget.classId);
      
      setState(() {
        _studentStats = stats;
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading stats: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải thống kê: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _viewSessionDetails(int sessionId, int sessionNumber) async {
    try {
      final attendances = await DatabaseService.getSessionAttendances(sessionId);
      
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.people, color: Colors.blue),
                      const SizedBox(width: 12),
                      Text(
                        'Buổi $sessionNumber - Chi tiết điểm danh',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: attendances.length,
                    itemBuilder: (context, index) {
                      final att = attendances[index];
                      final status = att['status'];
                      
                      IconData icon;
                      Color color;
                      String statusText;
                      
                      if (status == null) {
                        icon = Icons.remove_circle_outline;
                        color = Colors.grey;
                        statusText = 'Chưa học';
                      } else if (status == 'present') {
                        icon = Icons.check_circle;
                        color = Colors.green;
                        statusText = 'Có mặt';
                      } else {
                        icon = Icons.cancel;
                        color = Colors.red;
                        statusText = 'Vắng';
                      }

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withOpacity(0.1),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        title: Text(att['full_name']),
                        subtitle: Text('MSSV: ${att['student_code']}'),
                        trailing: Chip(
                          label: Text(statusText),
                          backgroundColor: color.withOpacity(0.1),
                          labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString()}')),
      );
    }
  }

  // Helper function to safely convert to int
  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is BigInt) return value.toInt();
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  // Helper function to safely convert to double
  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is BigInt) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.className),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Theo sinh viên'),
            Tab(icon: Icon(Icons.event), text: 'Theo buổi học'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildStudentStatsTab(),
                _buildSessionStatsTab(),
              ],
            ),
    );
  }

  Widget _buildStudentStatsTab() {
    if (_studentStats.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Chưa có sinh viên nào'),
          ],
        ),
      );
    }

    // Tính thống kê tổng quan với safe casting
    final totalStudents = _studentStats.length;
    
    double avgAttendance = 0.0;
    if (totalStudents > 0) {
      double sum = 0.0;
      for (var s in _studentStats) {
        sum += _toDouble(s['attendance_rate']);
      }
      avgAttendance = sum / totalStudents;
    }
    
    final excellentCount = _studentStats.where((s) => _toDouble(s['attendance_rate']) >= 80).length;
    final goodCount = _studentStats.where((s) {
      final rate = _toDouble(s['attendance_rate']);
      return rate >= 50 && rate < 80;
    }).length;
    final poorCount = _studentStats.where((s) => _toDouble(s['attendance_rate']) < 50).length;

    return Column(
      children: [
        // Thống kê tổng quan
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade400, Colors.blue.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatCard(
                    icon: Icons.people,
                    label: 'Tổng SV',
                    value: '$totalStudents',
                    color: Colors.white,
                  ),
                  _StatCard(
                    icon: Icons.assessment,
                    label: 'TB tham dự',
                    value: '${avgAttendance.toStringAsFixed(1)}%',
                    color: Colors.white,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatBadge(label: 'Xuất sắc (≥80%)', value: excellentCount, color: Colors.green),
                  _StatBadge(label: 'Khá (50-80%)', value: goodCount, color: Colors.orange),
                  _StatBadge(label: 'Yếu (<50%)', value: poorCount, color: Colors.red),
                ],
              ),
            ],
          ),
        ),

        // Danh sách sinh viên
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadStats,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _studentStats.length,
              itemBuilder: (context, index) {
                final student = _studentStats[index];
                final rate = _toDouble(student['attendance_rate']);
                
                Color rateColor;
                if (rate >= 80) {
                  rateColor = Colors.green;
                } else if (rate >= 50) {
                  rateColor = Colors.orange;
                } else {
                  rateColor = Colors.red;
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: rateColor.withOpacity(0.1),
                      child: Text(
                        '${rate.toInt()}%',
                        style: TextStyle(
                          color: rateColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    title: Text(
                      student['full_name'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('MSSV: ${student['student_code']}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${_toInt(student['attended'])}/${_toInt(student['total_sessions'])}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Text('buổi', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionStatsTab() {
    if (_sessions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Chưa có buổi học nào'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sessions.length,
        itemBuilder: (context, index) {
          final session = _sessions[index];
          final date = session['session_date'] as DateTime;
          final attendances = _toInt(session['total_attendances']);
          final sessionNumber = _toInt(session['session_number']);
          final isCompleted = session['is_completed'] as bool? ?? false;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isCompleted ? Colors.green : Colors.orange,
                child: Text('$sessionNumber'),
              ),
              title: Text('Buổi $sessionNumber'),
              subtitle: Text(
                '${date.day}/${date.month}/${date.year} - ${session['session_time']}\n'
                'Phòng: ${session['room'] ?? 'N/A'}',
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people, color: Colors.blue, size: 20),
                  Text(
                    '$attendances',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              onTap: () => _viewSessionDetails(
                _toInt(session['id']),
                sessionNumber,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: color.withOpacity(0.9), fontSize: 12),
        ),
      ],
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ],
      ),
    );
  }
}