import 'package:flutter/material.dart';
import '../services/database_service.dart';

class CreateClassScreen extends StatefulWidget {
  final int teacherId;
  
  const CreateClassScreen({Key? key, required this.teacherId}) : super(key: key);

  @override
  State<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _CreateClassScreenState extends State<CreateClassScreen> {
  final _formKey = GlobalKey<FormState>();
  final _classNameController = TextEditingController();
  final _subjectNameController = TextEditingController();
  final _totalSessionsController = TextEditingController();
  final _semesterController = TextEditingController();
  final _academicYearController = TextEditingController();
  final _scheduleController = TextEditingController();
  final _maxStudentsController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
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

  Future<void> _createClass() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await DatabaseService.createClass(
        teacherId: widget.teacherId,
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
          content: Text('✅ Tạo lớp thành công!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
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
        title: const Text('Tạo lớp điểm danh'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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

            // Button tạo lớp
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createClass,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('TẠO LỚP', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}