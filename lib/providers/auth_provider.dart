import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  Map<String, dynamic>? _user;
  
  Map<String, dynamic>? get user => _user;
  bool get isLoggedIn => _user != null;
  
  Future<void> login(Map<String, dynamic> userData) async {
    _user = userData;
    
    // Lưu vào SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', userData['id']);
    await prefs.setString('role', userData['role']);
    await prefs.setString('full_name', userData['full_name']);
    
    notifyListeners();
  }
  
  Future<void> logout() async {
    _user = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    notifyListeners();
  }
}