// lib/screens/join_class_screen.dart
import 'package:flutter/material.dart';
import '../services/database_service.dart';

class JoinClassScreen extends StatefulWidget {
  final int studentId;
  
  const JoinClassScreen({Key? key, required this.studentId}) : super(key: key);

  @override
  State<JoinClassScreen> createState() => _JoinClassScreenState();
}

class _JoinClassScreenState extends State<JoinClassScreen> {
  final _classCodeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _classCodeController.dispose();
    super.dispose();
  }

  Future<void> _joinClass() async {
    final classCode = _classCodeController.text.trim().toUpperCase();
    
    if (classCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập mã lớp')),
      );
      return;
    }

    if (classCode.length != 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mã lớp phải có 8 ký tự')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await DatabaseService.joinClass(classCode, widget.studentId);

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Tham gia lớp thành công!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true); // Return true để refresh
    } catch (e) {
      if (!mounted) return;
      
      String errorMessage = 'Lỗi: ${e.toString()}';
      if (e.toString().contains('Không tìm thấy')) {
        errorMessage = 'Mã lớp không tồn tại';
      } else if (e.toString().contains('đã tham gia')) {
        errorMessage = 'Bạn đã tham gia lớp này rồi';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tham gia lớp'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code_scanner,
              size: 100,
              color: Colors.blue.shade300,
            ),
            const SizedBox(height: 24),
            const Text(
              'Nhập mã lớp',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nhập mã lớp 8 ký tự do giảng viên cung cấp',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            
            TextField(
              controller: _classCodeController,
              decoration: InputDecoration(
                labelText: 'Mã lớp',
                hintText: 'VD: ABC12345',
                prefixIcon: const Icon(Icons.key),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                counterText: '',
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 8,
              style: const TextStyle(
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
              onChanged: (value) {
                // Auto uppercase
                final upperValue = value.toUpperCase();
                if (value != upperValue) {
                  _classCodeController.value = _classCodeController.value.copyWith(
                    text: upperValue,
                    selection: TextSelection.collapsed(offset: upperValue.length),
                  );
                }
              },
            ),
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _joinClass,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('THAM GIA', style: TextStyle(fontSize: 16)),
              ),
            ),
            
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Mã lớp được giảng viên cung cấp khi tạo lớp điểm danh. Bạn có thể tìm thấy mã lớp trong thông báo hoặc hỏi giảng viên.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}