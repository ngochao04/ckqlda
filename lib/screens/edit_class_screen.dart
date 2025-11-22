// lib/screens/edit_class_screen.dart
import 'package:flutter/material.dart';
import '../services/database_service.dart';

class EditClassScreen extends StatefulWidget {
  final Map<String, dynamic> classData;
  
  const EditClassScreen({Key? key, required this.classData}) : super(key: key);

  @override
  State<EditClassScreen> createState() => _EditClassScreenState();
}

class _EditClassScreenState extends State<EditClassScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _classNameController;
  late TextEditingController _subjectNameController;
  late TextEditingController _totalSessionsController;
  late TextEditingController _semesterController;
  late TextEditingController _academicYearController;
  late TextEditingController _scheduleController;
  late TextEditingController _maxStudentsController;
  late TextEditingController _descriptionController;
  
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    // Khởi tạo controllers với dữ liệu hiện tại
    _classNameController = TextEditingController(text: widget.classData['class_name']);
    _subjectNameController = TextEditingController(text: widget.classData['subject_name']);
    _totalSessionsController = TextEditingController(text: widget.classData['total_sessions'].toString());
    _semesterController = TextEditingController(text: widget.classData['semester'] ?? '');
    _academicYearController = TextEditingController(text: widget.classData['academic_year'] ?? '');
    _scheduleController = TextEditingController(text: widget.classData['schedule'] ?? '');
    _maxStudentsController = TextEditingController(
      text: widget.classData['max_students']?.toString() ?? ''
    );
    _descriptionController = TextEditingController(text: widget.classData['description'] ?? '');
    
    _startDate = widget.classData['start_date'];
    _endDate = widget.classData['end_date'];
  }

  @override
  void dispose() {
    _classNameController.dispose();
    _subjectNameController.dispose();
    _totalSessionsController.dispose();
    _semesterController.dispose();
    _academicYearController.dispose();
    _scheduleController.dispose();
    _maxStudentsController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _updateClass() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await DatabaseService.updateClass(
        classId: widget.classData['id'],
        className: _classNameController.text.trim(),
        subjectName: _subjectNameController.text.trim(),
        totalSessions: int.parse(_totalSessionsController.text),
        semester: _semesterController.text.trim(),
        academicYear: _academicYearController.text.trim(),
        schedule: _scheduleController.text.trim(),
        maxStudents: _maxStudentsController.text.isNotEmpty 
            ? int.parse(_maxStudentsController.text) 
            : null,
        description: _descriptionController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
      );

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Cập nhật lớp thành công!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true); // Return true để refresh
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh sửa lớp'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isLoading ? null : _updateClass,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Mã lớp (không cho sửa)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.key, color: Colors.blue),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Mã lớp', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                        widget.classData['class_code'],
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tên lớp
            TextFormField(
              controller: _classNameController,
              decoration: const InputDecoration(
                labelText: 'Tên lớp *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.class_),
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Vui lòng nhập tên lớp' : null,
            ),
            const SizedBox(height: 16),

            // Môn học
            TextFormField(
              controller: _subjectNameController,
              decoration: const InputDecoration(
                labelText: 'Môn học *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.book),
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Vui lòng nhập môn học' : null,
            ),
            const SizedBox(height: 16),

            // Tổng số buổi
            TextFormField(
              controller: _totalSessionsController,
              decoration: const InputDecoration(
                labelText: 'Tổng số buổi *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.event_note),
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v?.isEmpty ?? true) return 'Vui lòng nhập số buổi';
                if (int.tryParse(v!) == null) return 'Phải là số';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Học kỳ
            TextFormField(
              controller: _semesterController,
              decoration: const InputDecoration(
                labelText: 'Học kỳ (VD: HK1, HK2)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_month),
              ),
            ),
            const SizedBox(height: 16),

            // Năm học
            TextFormField(
              controller: _academicYearController,
              decoration: const InputDecoration(
                labelText: 'Năm học (VD: 2024-2025)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.date_range),
              ),
            ),
            const SizedBox(height: 16),

            // Lịch học
            TextFormField(
              controller: _scheduleController,
              decoration: const InputDecoration(
                labelText: 'Lịch học (VD: Thứ 2, 7h-9h)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.schedule),
              ),
            ),
            const SizedBox(height: 16),

            // Sĩ số tối đa
            TextFormField(
              controller: _maxStudentsController,
              decoration: const InputDecoration(
                labelText: 'Sĩ số tối đa',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.people),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // Ngày bắt đầu
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(_startDate == null 
                  ? 'Ngày bắt đầu' 
                  : 'Bắt đầu: ${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _selectDate(context, true),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade400),
              ),
            ),
            const SizedBox(height: 16),

            // Ngày kết thúc
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(_endDate == null 
                  ? 'Ngày kết thúc' 
                  : 'Kết thúc: ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _selectDate(context, false),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade400),
              ),
            ),
            const SizedBox(height: 16),

            // Mô tả
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Mô tả',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Button lưu
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateClass,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('LƯU THAY ĐỔI', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}