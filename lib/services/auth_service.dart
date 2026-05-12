import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/env.dart';

class AuthService {
  // Lấy baseUrl từ .env
  static String get baseUrl {
    return EnvConfig.baseUrl;
  }
  
  static const String userKey = 'user_data';
  static const Duration requestTimeout = Duration(seconds: 30);
  
  // Đăng ký
  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'Email': email,
          'Password': password,
          'FullName': fullName,
        }),
      ).timeout(requestTimeout);

      if (response.statusCode == 201) {
        try {
          final data = jsonDecode(response.body);
          final user = User.fromJson(data['user']);
          
          // Lưu user vào local storage
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString(userKey, jsonEncode(user.toJson()));
          
          return {
            'success': true,
            'message': 'Đăng ký thành công!',
            'user': user,
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Lỗi xử lý dữ liệu: ${e.toString()}',
          };
        }
      } else {
        try {
          final error = jsonDecode(response.body);
          return {
            'success': false,
            'message': error['message'] ?? 'Đăng ký thất bại',
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Đăng ký thất bại (${response.statusCode}): ${response.body}',
          };
        }
      }
    } on http.ClientException catch (e) {
      print('❌ Register - Lỗi kết nối: $baseUrl');
      print('Chi tiết: $e');
      return {
        'success': false,
        'message': 'Lỗi kết nối đến backend:\n$baseUrl\n\nKiểm tra:\n1. Backend có chạy không?\n2. Port 3000 đúng không?\n3. Network có kết nối không?',
      };
    } catch (e) {
      print('❌ Register - Lỗi: $e');
      return {
        'success': false,
        'message': 'Lỗi: ${e.toString()}',
      };
    }
  }

  // Đăng nhập
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'Email': email,
          'Password': password,
        }),
      ).timeout(requestTimeout);

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          final user = User.fromJson(data['user']);
          
          // Lưu user vào local storage
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString(userKey, jsonEncode(user.toJson()));
          
          return {
            'success': true,
            'message': 'Đăng nhập thành công!',
            'user': user,
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Lỗi xử lý dữ liệu: ${e.toString()}',
          };
        }
      } else {
        try {
          final error = jsonDecode(response.body);
          return {
            'success': false,
            'message': error['message'] ?? 'Đăng nhập thất bại',
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Đăng nhập thất bại (${response.statusCode}): ${response.body}',
          };
        }
      }
    } on http.ClientException catch (e) {
      print('❌ Login - Lỗi kết nối: $baseUrl');
      print('Chi tiết: $e');
      return {
        'success': false,
        'message': 'Lỗi kết nối đến backend:\n$baseUrl\n\nKiểm tra:\n1. Backend có chạy không?\n2. Port 3000 đúng không?\n3. Network có kết nối không?',
      };
    } catch (e) {
      print('❌ Login - Lỗi: $e');
      return {
        'success': false,
        'message': 'Lỗi: ${e.toString()}',
      };
    }
  }

  // Lấy user hiện tại
  static Future<User?> getCurrentUser() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userData = prefs.getString(userKey);
      
      if (userData != null && userData.isNotEmpty) {
        try {
          final json = jsonDecode(userData);
          return User.fromJson(json);
        } catch (e) {
          print('Lỗi parse user: ${e.toString()}');
          return null;
        }
      }
      return null;
    } catch (e) {
      print('Lỗi lấy user: ${e.toString()}');
      return null;
    }
  }

  // Đăng xuất
  static Future<void> logout() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.remove(userKey);
    } catch (e) {
      print('Lỗi đăng xuất: ${e.toString()}');
    }
  }

  // Kiểm tra đã đăng nhập
  static Future<bool> isLoggedIn() async {
    final user = await getCurrentUser();
    return user != null;
  }
}
