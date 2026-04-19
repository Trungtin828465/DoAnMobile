import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class AuthController {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();

  TextEditingController get emailController => _emailController;
  TextEditingController get passwordController => _passwordController;
  TextEditingController get fullNameController => _fullNameController;

  // Đăng ký
  Future<Map<String, dynamic>> register() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final fullName = _fullNameController.text.trim();

    if (email.isEmpty || password.isEmpty || fullName.isEmpty) {
      return {
        'success': false,
        'message': 'Vui lòng điền đầy đủ thông tin',
      };
    }

    if (password.length < 6) {
      return {
        'success': false,
        'message': 'Mật khẩu phải có ít nhất 6 ký tự',
      };
    }

    return await AuthService.register(
      email: email,
      password: password,
      fullName: fullName,
    );
  }

  // Đăng nhập
  Future<Map<String, dynamic>> login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      return {
        'success': false,
        'message': 'Vui lòng điền đầy đủ email và mật khẩu',
      };
    }

    return await AuthService.login(
      email: email,
      password: password,
    );
  }

  // Lấy user hiện tại
  Future<User?> getCurrentUser() {
    return AuthService.getCurrentUser();
  }

  // Đăng xuất
  Future<void> logout() {
    return AuthService.logout();
  }

  // Kiểm tra đã đăng nhập
  Future<bool> isLoggedIn() {
    return AuthService.isLoggedIn();
  }

  // Xóa controller
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
  }
}
