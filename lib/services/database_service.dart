// lib/services/database_service.dart
import 'package:postgres/postgres.dart';

class DatabaseService {
  static PostgreSQLConnection? _connection;
  
  // ⚠️ THAY ĐỔI HOST CHO ANDROID EMULATOR
  static const String host = '10.0.2.2';  // ✅ Dùng cho Android Emulator
  // static const String host = 'localhost';  // ❌ Không dùng cho emulator
  // static const String host = '192.168.1.X';  // ✅ Dùng cho thiết bị thật (thay X)
  
  static const int port = 5432;
  static const String database = 'attendance_management';
  static const String username = 'postgres';
  static const String password = '123456'; // Đổi password của bạn

  // Kết nối database
  static Future<PostgreSQLConnection> getConnection() async {
    if (_connection == null || _connection!.isClosed) {
      print('🔌 Đang kết nối database...');
      print('   Host: $host');
      print('   Port: $port');
      print('   Database: $database');
      
      _connection = PostgreSQLConnection(
        host,
        port,
        database,
        username: username,
        password: password,
        useSSL: false,
      );
      
      try {
        await _connection!.open();
        print('✅ Database connected successfully!');
      } catch (e) {
        print('❌ Lỗi kết nối database:');
        print('   $e');
        rethrow;
      }
    }
    return _connection!;
  }

  // Đóng kết nối
  static Future<void> closeConnection() async {
    if (_connection != null && !_connection!.isClosed) {
      await _connection!.close();
      _connection = null;
      print('❌ Database connection closed');
    }
  }

  // ==================== AUTH ====================
  
  // Đăng nhập
  static Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final conn = await getConnection();
      
      final results = await conn.query(
        'SELECT u.*, t.id as teacher_id, t.teacher_code, t.department, '
        's.id as student_id, s.student_code, s.class_name as student_class, s.academic_year '
        'FROM users u '
        'LEFT JOIN teachers t ON u.id = t.user_id '
        'LEFT JOIN students s ON u.id = s.user_id '
        'WHERE u.email = @email AND u.password = @password AND u.is_active = true',
        substitutionValues: {
          'email': email,
          'password': password,
        },
      );

      if (results.isEmpty) return null;

      final row = results.first;
      return {
        'id': row[0],
        'email': row[1],
        'password': row[2],
        'full_name': row[3],
        'phone': row[4],
        'role': row[5],
        'avatar_url': row[6],
        'is_active': row[7],
        'created_at': row[8],
        'updated_at': row[9],
        'teacher_id': row[10],
        'teacher_code': row[11],
        'department': row[12],
        'student_id': row[13],
        'student_code': row[14],
        'student_class': row[15],
        'academic_year': row[16],
      };
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }

  // Đổi mật khẩu (FIX)
  static Future<void> changePassword(int userId, String oldPassword, String newPassword) async {
    final conn = await getConnection();
    
    // Verify old password
    final check = await conn.query(
      'SELECT id FROM users WHERE id = @id AND password = @oldpwd',
      substitutionValues: {
        'id': userId,
        'oldpwd': oldPassword,
      },
    );
    
    if (check.isEmpty) {
      throw Exception('Mật khẩu cũ không đúng');
    }
    
    // Update password
    await conn.query(
      'UPDATE users SET password = @password, updated_at = NOW() WHERE id = @id',
      substitutionValues: {
        'password': newPassword,
        'id': userId,
      },
    );
  }

  // Cập nhật profile
  static Future<void> updateProfile({
    required int userId,
    required String fullName,
    String? phone,
    String? avatarUrl,
  }) async {
    final conn = await getConnection();
    await conn.query(
      'UPDATE users SET full_name = @name, phone = @phone, '
      'avatar_url = @avatar, updated_at = NOW() WHERE id = @id',
      substitutionValues: {
        'name': fullName,
        'phone': phone,
        'avatar': avatarUrl,
        'id': userId,
      },
    );
  }

  // ==================== CLASSES ====================
  
  // Tạo lớp (Giảng viên)
  static Future<Map<String, dynamic>> createClass({
    required int teacherId,
    required String className,
    required String subjectName,
    required int totalSessions,
    String? semester,
    String? academicYear,
    String? schedule,
    int? maxStudents,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final conn = await getConnection();
    
    // Tạo mã lớp ngẫu nhiên
    final classCode = _generateClassCode();
    
    final results = await conn.query(
      'INSERT INTO attendance_classes '
      '(class_code, class_name, teacher_id, subject_name, semester, academic_year, '
      'total_sessions, schedule, max_students, description, start_date, end_date) '
      'VALUES (@code, @name, @teacher, @subject, @semester, @year, '
      '@sessions, @schedule, @max, @desc, @start, @end) '
      'RETURNING *',
      substitutionValues: {
        'code': classCode,
        'name': className,
        'teacher': teacherId,
        'subject': subjectName,
        'semester': semester,
        'year': academicYear,
        'sessions': totalSessions,
        'schedule': schedule,
        'max': maxStudents,
        'desc': description,
        'start': startDate,
        'end': endDate,
      },
    );

    return _rowToMap(results.first, [
      'id', 'class_code', 'class_name', 'teacher_id', 'subject_name',
      'semester', 'academic_year', 'total_sessions', 'schedule', 
      'max_students', 'description', 'start_date', 'end_date',
      'is_active', 'created_at', 'updated_at'
    ]);
  }

  // Cập nhật lớp (NEW)
  static Future<void> updateClass({
    required int classId,
    required String className,
    required String subjectName,
    required int totalSessions,
    String? semester,
    String? academicYear,
    String? schedule,
    int? maxStudents,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final conn = await getConnection();
    
    await conn.query(
      'UPDATE attendance_classes SET '
      'class_name = @name, subject_name = @subject, semester = @semester, '
      'academic_year = @year, total_sessions = @sessions, schedule = @schedule, '
      'max_students = @max, description = @desc, start_date = @start, '
      'end_date = @end, updated_at = NOW() '
      'WHERE id = @id',
      substitutionValues: {
        'name': className,
        'subject': subjectName,
        'semester': semester,
        'year': academicYear,
        'sessions': totalSessions,
        'schedule': schedule,
        'max': maxStudents,
        'desc': description,
        'start': startDate,
        'end': endDate,
        'id': classId,
      },
    );
  }

  // Lấy danh sách lớp của giảng viên
  static Future<List<Map<String, dynamic>>> getTeacherClasses(int teacherId) async {
    final conn = await getConnection();
    
    final results = await conn.query(
      'SELECT ac.*, '
      'COUNT(DISTINCT cs.student_id) as enrolled_students, '
      'COUNT(DISTINCT CASE WHEN s.is_completed THEN s.id END) as completed_sessions '
      'FROM attendance_classes ac '
      'LEFT JOIN class_students cs ON ac.id = cs.class_id '
      'LEFT JOIN sessions s ON ac.id = s.class_id '
      'WHERE ac.teacher_id = @teacher '
      'GROUP BY ac.id '
      'ORDER BY ac.created_at DESC',
      substitutionValues: {'teacher': teacherId},
    );

    return results.map((row) {
      return _rowToMap(row, [
        'id', 'class_code', 'class_name', 'teacher_id', 'subject_name',
        'semester', 'academic_year', 'total_sessions', 'schedule',
        'max_students', 'description', 'start_date', 'end_date',
        'is_active', 'created_at', 'updated_at', 'enrolled_students', 'completed_sessions'
      ]);
    }).toList();
  }

  // Lấy lớp sinh viên đã tham gia (FIX)
  static Future<List<Map<String, dynamic>>> getStudentClasses(int studentId) async {
    final conn = await getConnection();
    
    final results = await conn.query(
      'SELECT ac.*, u.full_name as teacher_name, cs.enrolled_at, '
      'COUNT(DISTINCT s.id) FILTER (WHERE s.is_completed = true) as total_sessions_held, '
      'COUNT(DISTINCT a.id) FILTER (WHERE a.status = \'present\') as attended_sessions '
      'FROM class_students cs '
      'JOIN attendance_classes ac ON cs.class_id = ac.id '
      'JOIN teachers t ON ac.teacher_id = t.id '
      'JOIN users u ON t.user_id = u.id '
      'LEFT JOIN sessions s ON ac.id = s.class_id '
      'LEFT JOIN attendances a ON s.id = a.session_id AND a.student_id = @student '
      'WHERE cs.student_id = @student AND ac.is_active = true '
      'GROUP BY ac.id, u.full_name, cs.enrolled_at '
      'ORDER BY cs.enrolled_at DESC',
      substitutionValues: {'student': studentId},
    );

    return results.map((row) {
      return _rowToMap(row, [
        'id', 'class_code', 'class_name', 'teacher_id', 'subject_name',
        'semester', 'academic_year', 'total_sessions', 'schedule',
        'max_students', 'description', 'start_date', 'end_date',
        'is_active', 'created_at', 'updated_at', 'teacher_name',
        'total_sessions_held', 'attended_sessions'
      ]);
    }).toList();
  }

  // Tham gia lớp (Sinh viên)
  static Future<void> joinClass(String classCode, int studentId) async {
    final conn = await getConnection();
    
    // Kiểm tra lớp tồn tại
    final classCheck = await conn.query(
      'SELECT id, max_students FROM attendance_classes '
      'WHERE class_code = @code AND is_active = true',
      substitutionValues: {'code': classCode},
    );

    if (classCheck.isEmpty) {
      throw Exception('Không tìm thấy lớp với mã này');
    }

    final classId = classCheck.first[0];
    
    // Kiểm tra đã tham gia chưa
    final enrolled = await conn.query(
      'SELECT id FROM class_students WHERE class_id = @class AND student_id = @student',
      substitutionValues: {'class': classId, 'student': studentId},
    );
    
    if (enrolled.isNotEmpty) {
      throw Exception('Bạn đã tham gia lớp này rồi');
    }
    
    // Thêm vào lớp
    await conn.query(
      'INSERT INTO class_students (class_id, student_id) VALUES (@class, @student)',
      substitutionValues: {
        'class': classId,
        'student': studentId,
      },
    );
  }

  // Xóa lớp
  static Future<void> deleteClass(int classId) async {
    final conn = await getConnection();
    await conn.query(
      'DELETE FROM attendance_classes WHERE id = @id',
      substitutionValues: {'id': classId},
    );
  }

  // ==================== SESSIONS ====================
  
  // Tạo buổi học
  static Future<Map<String, dynamic>> createSession({
    required int classId,
    required int sessionNumber,
    required DateTime sessionDate,
    required String sessionTime,
    String? room,
  }) async {
    final conn = await getConnection();
    
    final results = await conn.query(
      'INSERT INTO sessions '
      '(class_id, session_number, session_date, session_time, room) '
      'VALUES (@class, @number, @date, @time, @room) '
      'RETURNING *',
      substitutionValues: {
        'class': classId,
        'number': sessionNumber,
        'date': sessionDate,
        'time': sessionTime,
        'room': room,
      },
    );

    return _rowToMap(results.first, [
      'id', 'class_id', 'session_number', 'session_date', 'session_time',
      'room', 'qr_code', 'qr_expired_at', 'is_completed', 'notes', 'created_at'
    ]);
  }

  // Tạo QR code
  static Future<Map<String, dynamic>> generateQRCode(int sessionId) async {
    final conn = await getConnection();
    
    // Tạo QR data
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final qrCode = '$sessionId:${_generateToken()}:$timestamp';
    final expiredAt = DateTime.now().add(Duration(minutes: 10));
    
    final results = await conn.query(
      'UPDATE sessions SET qr_code = @qr, qr_expired_at = @expired '
      'WHERE id = @id RETURNING *',
      substitutionValues: {
        'qr': qrCode,
        'expired': expiredAt,
        'id': sessionId,
      },
    );

    return _rowToMap(results.first, [
      'id', 'class_id', 'session_number', 'session_date', 'session_time',
      'room', 'qr_code', 'qr_expired_at', 'is_completed', 'notes', 'created_at'
    ]);
  }

  // Lấy danh sách buổi học
  static Future<List<Map<String, dynamic>>> getSessions(int classId) async {
    final conn = await getConnection();
    
    final results = await conn.query(
      'SELECT s.*, '
      'COUNT(DISTINCT a.id) as total_attendances '
      'FROM sessions s '
      'LEFT JOIN attendances a ON s.id = a.session_id '
      'WHERE s.class_id = @class '
      'GROUP BY s.id '
      'ORDER BY s.session_number',
      substitutionValues: {'class': classId},
    );

    return results.map((row) {
      return _rowToMap(row, [
        'id', 'class_id', 'session_number', 'session_date', 'session_time',
        'room', 'qr_code', 'qr_expired_at', 'is_completed', 'notes',
        'created_at', 'total_attendances'
      ]);
    }).toList();
  }

  // ==================== ATTENDANCE ====================
  
  // Điểm danh
  static Future<void> checkIn({
    required String qrCode,
    required int studentId,
    double? latitude,
    double? longitude,
  }) async {
    final conn = await getConnection();
    
    // Parse QR
    final parts = qrCode.split(':');
    if (parts.length != 3) throw Exception('QR code không hợp lệ');
    
    final sessionId = int.parse(parts[0]);
    
    // Kiểm tra QR còn hạn
    final sessionCheck = await conn.query(
      'SELECT qr_code, qr_expired_at FROM sessions WHERE id = @id',
      substitutionValues: {'id': sessionId},
    );

    if (sessionCheck.isEmpty) throw Exception('Buổi học không tồn tại');
    
    final qrExpired = sessionCheck.first[1] as DateTime;
    if (DateTime.now().isAfter(qrExpired)) {
      throw Exception('Mã QR đã hết hạn');
    }

    // Kiểm tra đã điểm danh chưa
    final attendanceCheck = await conn.query(
      'SELECT id FROM attendances WHERE session_id = @session AND student_id = @student',
      substitutionValues: {'session': sessionId, 'student': studentId},
    );

    if (attendanceCheck.isNotEmpty) {
      throw Exception('Bạn đã điểm danh buổi này rồi');
    }

    // Thêm điểm danh
    await conn.query(
      'INSERT INTO attendances '
      '(session_id, student_id, status, latitude, longitude) '
      'VALUES (@session, @student, @status, @lat, @lng)',
      substitutionValues: {
        'session': sessionId,
        'student': studentId,
        'status': 'present',
        'lat': latitude,
        'lng': longitude,
      },
    );
  }

  // Lấy lịch sử điểm danh
  static Future<List<Map<String, dynamic>>> getAttendanceHistory(
    int classId,
    int studentId,
  ) async {
    final conn = await getConnection();
    
    final results = await conn.query(
      'SELECT s.session_number, s.session_date, s.session_time, '
      's.room, a.status, a.checked_at '
      'FROM sessions s '
      'LEFT JOIN attendances a ON s.id = a.session_id AND a.student_id = @student '
      'WHERE s.class_id = @class '
      'ORDER BY s.session_number',
      substitutionValues: {
        'class': classId,
        'student': studentId,
      },
    );

    return results.map((row) {
      return _rowToMap(row, [
        'session_number', 'session_date', 'session_time',
        'room', 'status', 'checked_at'
      ]);
    }).toList();
  }

  // Lấy thống kê điểm danh của lớp (NEW)
  static Future<List<Map<String, dynamic>>> getClassAttendanceStats(int classId) async {
    final conn = await getConnection();
    
    final results = await conn.query(
      'SELECT '
      'u.full_name, st.student_code, '
      'COUNT(DISTINCT s.id) as total_sessions, '
      'COUNT(DISTINCT CASE WHEN a.status = \'present\' THEN a.id END) as attended, '
      'ROUND(COUNT(DISTINCT CASE WHEN a.status = \'present\' THEN a.id END)::numeric / '
      'NULLIF(COUNT(DISTINCT s.id), 0) * 100, 1) as attendance_rate '
      'FROM class_students cs '
      'JOIN students st ON cs.student_id = st.id '
      'JOIN users u ON st.user_id = u.id '
      'CROSS JOIN sessions s '
      'LEFT JOIN attendances a ON s.id = a.session_id AND a.student_id = cs.student_id '
      'WHERE cs.class_id = @class AND s.class_id = @class '
      'GROUP BY u.full_name, st.student_code, cs.student_id '
      'ORDER BY attendance_rate DESC',
      substitutionValues: {'class': classId},
    );

    return results.map((row) {
      return _rowToMap(row, [
        'full_name', 'student_code', 'total_sessions', 'attended', 'attendance_rate'
      ]);
    }).toList();
  }

  // Lấy danh sách điểm danh theo buổi (NEW)
  static Future<List<Map<String, dynamic>>> getSessionAttendances(int sessionId) async {
    final conn = await getConnection();
    
    final results = await conn.query(
      'SELECT u.full_name, st.student_code, a.status, a.checked_at '
      'FROM sessions s '
      'JOIN attendance_classes ac ON s.class_id = ac.id '
      'JOIN class_students cs ON ac.id = cs.class_id '
      'JOIN students st ON cs.student_id = st.id '
      'JOIN users u ON st.user_id = u.id '
      'LEFT JOIN attendances a ON s.id = a.session_id AND a.student_id = cs.student_id '
      'WHERE s.id = @session '
      'ORDER BY u.full_name',
      substitutionValues: {'session': sessionId},
    );

    return results.map((row) {
      return _rowToMap(row, [
        'full_name', 'student_code', 'status', 'checked_at'
      ]);
    }).toList();
  }

  // ==================== HELPERS ====================
  
  static String _generateClassCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(8, (i) => chars[(DateTime.now().millisecond + i) % chars.length]).join();
  }

  static String _generateToken() {
    return DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  }

  static Map<String, dynamic> _rowToMap(List<dynamic> row, List<String> columns) {
    final map = <String, dynamic>{};
    for (var i = 0; i < columns.length && i < row.length; i++) {
      map[columns[i]] = row[i];
    }
    return map;
  }
}