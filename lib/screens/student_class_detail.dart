import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/database_service.dart';

class StudentClassDetailScreen extends StatefulWidget {
  final Map<String, dynamic> classData;
  final int studentId;
  
  const StudentClassDetailScreen({
    Key? key,
    required this.classData,
    required this.studentId,
  }) : super(key: key);

  @override
  State<StudentClassDetailScreen> createState() => _StudentClassDetailScreenState();
}

class _StudentClassDetailScreenState extends State<StudentClassDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _attendanceHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAttendanceHistory();
  }

  Future<void> _loadAttendanceHistory() async {
    setState(() => _isLoading = true);
    try {
      final history = await DatabaseService.getAttendanceHistory(
        widget.classData['id'],
        widget.studentId,
      );
      setState(() {
        _attendanceHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _scanQRCode() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const _QRScannerScreen(),
      ),
    );

    if (result == null) return;

    try {
      await DatabaseService.checkIn(
        qrCode: result,
        studentId: widget.studentId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Điểm danh thành công!'),
          backgroundColor: Colors.green,
        ),
      );
      _loadAttendanceHistory();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.classData['class_name']),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Thông tin'),
            Tab(text: 'Lịch sử điểm danh'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInfoTab(),
          _buildHistoryTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scanQRCode,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Điểm danh'),
      ),
    );
  }

  Widget _buildInfoTab() {
    final attendanceRate = widget.classData['total_sessions_held'] > 0
        ? (widget.classData['attended_sessions'] / widget.classData['total_sessions_held'] * 100)
        : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Tỷ lệ điểm danh
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Text(
                  'Tỷ lệ tham dự',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  '${attendanceRate.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: attendanceRate >= 80 ? Colors.green : Colors.orange,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: attendanceRate / 100,
                  backgroundColor: Colors.grey.shade200,
                  color: attendanceRate >= 80 ? Colors.green : Colors.orange,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Thông tin chi tiết
        _InfoRow(
          icon: Icons.person,
          label: 'Giảng viên',
          value: widget.classData['teacher_name'],
        ),
        _InfoRow(
          icon: Icons.book,
          label: 'Môn học',
          value: widget.classData['subject_name'],
        ),
        _InfoRow(
          icon: Icons.calendar_month,
          label: 'Học kỳ',
          value: '${widget.classData['semester'] ?? 'N/A'} - ${widget.classData['academic_year'] ?? 'N/A'}',
        ),
        _InfoRow(
          icon: Icons.schedule,
          label: 'Lịch học',
          value: widget.classData['schedule'] ?? 'Chưa cập nhật',
        ),
        _InfoRow(
          icon: Icons.check_circle,
          label: 'Có mặt',
          value: '${widget.classData['attended_sessions']} buổi',
        ),
        _InfoRow(
          icon: Icons.event_note,
          label: 'Tổng buổi',
          value: '${widget.classData['total_sessions_held']} buổi',
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_attendanceHistory.isEmpty) {
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
      onRefresh: _loadAttendanceHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _attendanceHistory.length,
        itemBuilder: (context, index) {
          final record = _attendanceHistory[index];
          final date = record['session_date'] as DateTime;
          final status = record['status'];
          
          IconData statusIcon;
          Color statusColor;
          String statusText;
          
          if (status == null) {
            statusIcon = Icons.remove_circle_outline;
            statusColor = Colors.grey;
            statusText = 'Chưa học';
          } else if (status == 'present') {
            statusIcon = Icons.check_circle;
            statusColor = Colors.green;
            statusText = 'Có mặt';
          } else {
            statusIcon = Icons.cancel;
            statusColor = Colors.red;
            statusText = 'Vắng';
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: statusColor.withOpacity(0.1),
                child: Icon(statusIcon, color: statusColor),
              ),
              title: Text('Buổi ${record['session_number']}'),
              subtitle: Text(
                '${date.day}/${date.month}/${date.year} - ${record['session_time']}\n'
                'Phòng: ${record['room'] ?? 'N/A'}',
              ),
              trailing: Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _QRScannerScreen extends StatefulWidget {
  const _QRScannerScreen();

  @override
  State<_QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<_QRScannerScreen> {
  bool _isScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét mã QR điểm danh'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_isScanned) return;
              
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;
              
              final String? code = barcodes.first.rawValue;
              if (code != null) {
                setState(() => _isScanned = true);
                Navigator.pop(context, code);
              }
            },
          ),
          // Overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 50),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Đưa mã QR vào khung hình để điểm danh',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}