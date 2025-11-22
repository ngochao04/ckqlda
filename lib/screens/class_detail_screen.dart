import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/database_service.dart';

class ClassDetailScreen extends StatefulWidget {
  final Map<String, dynamic> classData;
  
  const ClassDetailScreen({Key? key, required this.classData}) : super(key: key);

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      final sessions = await DatabaseService.getSessions(widget.classData['id']);
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createSession() async {
    final sessionNumber = _sessions.length + 1;
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _CreateSessionDialog(
        sessionNumber: sessionNumber,
      ),
    );

    if (result == null) return;

    try {
      await DatabaseService.createSession(
        classId: widget.classData['id'],
        sessionNumber: sessionNumber,
        sessionDate: result['date'],
        sessionTime: result['time'],
        room: result['room'],
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Tạo buổi học thành công!'),
          backgroundColor: Colors.green,
        ),
      );
      _loadSessions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString()}')),
      );
    }
  }

  Future<void> _generateQR(int sessionId) async {
    try {
      final session = await DatabaseService.generateQRCode(sessionId);
      
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => _QRCodeDialog(qrCode: session['qr_code']),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString()}')),
      );
    }
  }

  Future<void> _deleteClass() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc muốn xóa lớp này? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await DatabaseService.deleteClass(widget.classData['id']);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Đã xóa lớp'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.classData['class_name']),
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Xóa lớp', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'delete') _deleteClass();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Thông tin'),
            Tab(text: 'Buổi học'),
            Tab(text: 'Sinh viên'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInfoTab(),
          _buildSessionsTab(),
          _buildStudentsTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: _createSession,
              icon: const Icon(Icons.add),
              label: const Text('Tạo buổi học'),
            )
          : null,
    );
  }

  Widget _buildInfoTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InfoCard(
          title: 'Mã lớp',
          value: widget.classData['class_code'],
          icon: Icons.key,
          color: Colors.blue,
          onTap: () {
            Clipboard.setData(ClipboardData(text: widget.classData['class_code']));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Đã copy mã lớp')),
            );
          },
        ),
        _InfoCard(
          title: 'Môn học',
          value: widget.classData['subject_name'],
          icon: Icons.book,
          color: Colors.green,
        ),
        _InfoCard(
          title: 'Học kỳ',
          value: '${widget.classData['semester'] ?? 'N/A'} - ${widget.classData['academic_year'] ?? 'N/A'}',
          icon: Icons.calendar_month,
          color: Colors.orange,
        ),
        _InfoCard(
          title: 'Lịch học',
          value: widget.classData['schedule'] ?? 'Chưa cập nhật',
          icon: Icons.schedule,
          color: Colors.purple,
        ),
        _InfoCard(
          title: 'Tiến độ',
          value: '${widget.classData['completed_sessions']}/${widget.classData['total_sessions']} buổi',
          icon: Icons.bar_chart,
          color: Colors.teal,
        ),
        _InfoCard(
          title: 'Sinh viên',
          value: '${widget.classData['enrolled_students']} sinh viên',
          icon: Icons.people,
          color: Colors.indigo,
        ),
      ],
    );
  }

  Widget _buildSessionsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Chưa có buổi học nào'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _createSession,
              child: const Text('Tạo buổi học đầu tiên'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSessions,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sessions.length,
        itemBuilder: (context, index) {
          final session = _sessions[index];
          final date = session['session_date'] as DateTime;
          
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: session['is_completed'] ? Colors.green : Colors.orange,
                child: Text('${session['session_number']}'),
              ),
              title: Text('Buổi ${session['session_number']}'),
              subtitle: Text(
                '${date.day}/${date.month}/${date.year} - ${session['session_time']}\n'
                'Phòng: ${session['room'] ?? 'N/A'} | '
                'Có mặt: ${session['total_attendances']}',
              ),
              trailing: session['qr_code'] != null
                  ? IconButton(
                      icon: const Icon(Icons.qr_code),
                      onPressed: () => _generateQR(session['id']),
                    )
                  : ElevatedButton(
                      onPressed: () => _generateQR(session['id']),
                      child: const Text('Tạo QR'),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStudentsTab() {
    return const Center(
      child: Text('Danh sách sinh viên\n(Chức năng đang phát triển)'),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: onTap != null ? const Icon(Icons.copy, size: 20) : null,
        onTap: onTap,
      ),
    );
  }
}

class _CreateSessionDialog extends StatefulWidget {
  final int sessionNumber;

  const _CreateSessionDialog({required this.sessionNumber});

  @override
  State<_CreateSessionDialog> createState() => _CreateSessionDialogState();
}

class _CreateSessionDialogState extends State<_CreateSessionDialog> {
  DateTime _selectedDate = DateTime.now();
  final _timeController = TextEditingController(text: '7h-9h');
  final _roomController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Tạo buổi ${widget.sessionNumber}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title: Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
            trailing: const Icon(Icons.edit),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (date != null) setState(() => _selectedDate = date);
            },
          ),
          TextField(
            controller: _timeController,
            decoration: const InputDecoration(
              labelText: 'Giờ học',
              prefixIcon: Icon(Icons.access_time),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _roomController,
            decoration: const InputDecoration(
              labelText: 'Phòng học',
              prefixIcon: Icon(Icons.meeting_room),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'date': _selectedDate,
              'time': _timeController.text,
              'room': _roomController.text,
            });
          },
          child: const Text('Tạo'),
        ),
      ],
    );
  }
}

class _QRCodeDialog extends StatelessWidget {
  final String qrCode;

  const _QRCodeDialog({required this.qrCode});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mã QR Điểm danh'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView(
            data: qrCode,
            version: QrVersions.auto,
            size: 250,
          ),
          const SizedBox(height: 16),
          const Text(
            'QR code có hiệu lực 10 phút',
            style: TextStyle(color: Colors.orange),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}