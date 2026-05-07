import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../controllers/auth_controller.dart';

const Color _primaryColor = Color(0xFF2563EB);
const Color _accentColor = Color(0xFF10B981);
const Color _surfaceColor = Color(0xFFF8FAFC);
const Color _cardColor = Color(0xFFFFFFFF);
const Color _textPrimary = Color(0xFF1E293B);
const Color _textSecondary = Color(0xFF64748B);

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late AuthController _authController;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _authController = AuthController();
  }

  @override
  void dispose() {
    _authController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_authController.emailController.text.isEmpty ||
        _authController.passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await _authController.login();

    setState(() => _isLoading = false);

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']), backgroundColor: _accentColor),
      );
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Banner
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryColor, Color(0xFF1d47a3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.home_work,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '3D Room Designer',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Thiết kế phòng của bạn một cách dễ dàng',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            // Form
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Đăng Nhập',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Đăng nhập để truy cập các phòng của bạn',
                    style: TextStyle(
                      fontSize: 14,
                      color: _textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Email field
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Email',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _authController.emailController,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          hintText: 'your@email.com',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _primaryColor, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Password field
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mật khẩu',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _authController.passwordController,
                        obscureText: _obscurePassword,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _primaryColor, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: _textSecondary,
                            ),
                            onPressed: () {
                              setState(() => _obscurePassword = !_obscurePassword);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Login button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _isLoading ? null : _handleLogin,
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Đăng Nhập',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Register link
                  Center(
                    child: RichText(
                      text: TextSpan(
                        text: 'Chưa có tài khoản? ',
                        style: const TextStyle(color: _textSecondary),
                        children: [
                          TextSpan(
                            text: 'Đăng ký ngay',
                            style: const TextStyle(
                              color: _primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = _isLoading
                                  ? null
                                  : () {
                                      Navigator.of(context).pushNamed('/register');
                                    },
                          ),
                        ],
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
