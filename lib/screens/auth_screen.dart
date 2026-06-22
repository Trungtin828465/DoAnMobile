import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/auth_api_service.dart';
import 'home_screen.dart';

const Color _authPrimary = Color(0xFF58CFC6);
const Color _authDark = Color(0xFF1F2937);
const Color _authButton = Color(0xFF4EAFC0);
const Color _authMuted = Color(0xFF7B8794);
const Color _authLine = Color(0xFF9EE3DD);

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthApiService _authApiService = AuthApiService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController =
      TextEditingController(text: 'Nguyễn Văn A');
  final TextEditingController _emailController =
      TextEditingController(text: 't@gmail.com');
  final TextEditingController _phoneController =
      TextEditingController(text: '0123456789');
  final TextEditingController _passwordController =
      TextEditingController(text: '123456');

  bool _isRegisterMode = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false) || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      final User user = _isRegisterMode
          ? await _authApiService.register(
              fullName: _fullNameController.text.trim(),
              email: _emailController.text.trim(),
              numberPhone: _phoneController.text.trim(),
              password: _passwordController.text.trim(),
            )
          : await _authApiService.login(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
      );
    } catch (error) {
      if (!mounted) return;
      _showAuthNotice('Lỗi đăng nhập/đăng ký: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAuthNotice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFE11D48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  String? _validateRequired(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Không được để trống';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _authPrimary,
      body: Stack(
        children: [
          const _AuthDecorations(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
                child: Form(
                  key: _formKey,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    child: _buildAuthCard(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthCard() {
    final title = _isRegisterMode
        ? 'Bắt đầu với chúng tôi'
        : 'Chào mừng trở lại';
    final subtitle = _isRegisterMode
        ? 'Tạo tài khoản để lưu layout phòng và vị trí đồ vật.'
        : 'Đăng nhập để tiếp tục hỗ trợ di chuyển.';

    return Container(
      key: ValueKey(_isRegisterMode),
      constraints: const BoxConstraints(maxWidth: 430),
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AuthHeader(
            title: title,
            subtitle: subtitle,
            isRegisterMode: _isRegisterMode,
          ),
          const SizedBox(height: 22),
          if (_isRegisterMode) ...[
            _AuthTextField(
              controller: _fullNameController,
              label: 'Họ tên',
              icon: Icons.person_outline,
              validator: _validateRequired,
            ),
            const SizedBox(height: 14),
            _AuthTextField(
              controller: _phoneController,
              label: 'Số điện thoại',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: _validateRequired,
            ),
            const SizedBox(height: 14),
          ],
          _AuthTextField(
            controller: _emailController,
            label: 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: _validateRequired,
          ),
          const SizedBox(height: 14),
          _AuthTextField(
            controller: _passwordController,
            label: 'Mật khẩu',
            icon: Icons.lock_outline,
            obscureText: _obscurePassword,
            validator: _validateRequired,
            suffixIcon: IconButton(
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: _authButton,
              disabledBackgroundColor: _authButton.withOpacity(0.45),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.4,
                    ),
                  )
                : Text(
                    _isRegisterMode ? 'Đăng ký' : 'Đăng nhập',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: _isLoading
                ? null
                : () {
                    setState(() => _isRegisterMode = !_isRegisterMode);
                  },
            child: Text(
              _isRegisterMode
                  ? 'Đã có tài khoản? Đăng nhập'
                  : 'Người dùng mới? Đăng ký ngay',
              style: const TextStyle(
                color: _authButton,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthDecorations extends StatelessWidget {
  const _AuthDecorations();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -58,
            right: -70,
            child: _DecorCircle(size: 180, opacity: 0.18),
          ),
          Positioned(
            bottom: -80,
            left: -72,
            child: _DecorCircle(size: 210, opacity: 0.16),
          ),
          Positioned(
            top: 60,
            left: 28,
            child: _LogoBubble(),
          ),
          const Positioned(
            top: 118,
            right: -20,
            child: _DiagonalStripes(),
          ),
        ],
      ),
    );
  }
}

class _AuthHeader extends StatelessWidget {
  const _AuthHeader({
    required this.title,
    required this.subtitle,
    required this.isRegisterMode,
  });

  final String title;
  final String subtitle;
  final bool isRegisterMode;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _authDark,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _authMuted,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Container(
          width: 96,
          height: 82,
          decoration: BoxDecoration(
            color: _authPrimary.withOpacity(0.22),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(42),
              topRight: Radius.circular(26),
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(48),
            ),
          ),
          child: Icon(
            isRegisterMode
                ? Icons.accessibility_new_rounded
                : Icons.assistant_navigation,
            color: _authButton,
            size: 42,
          ),
        ),
      ],
    );
  }
}

class _AuthTextField extends StatelessWidget {
  const _AuthTextField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(
        color: _authDark,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: _authButton,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        prefixIcon: Icon(icon, color: _authButton),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: _authLine, width: 1.4),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: _authButton, width: 1.8),
        ),
        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFE11D48), width: 1.4),
        ),
        focusedErrorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFE11D48), width: 1.8),
        ),
      ),
    );
  }
}

class _DecorCircle extends StatelessWidget {
  const _DecorCircle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity),
      ),
    );
  }
}

class _LogoBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.18),
      ),
      child: Center(
        child: Container(
          width: 54,
          height: 54,
          decoration: const BoxDecoration(
            color: Color(0xFFE7F8F6),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.assistant_navigation,
            color: _authButton,
            size: 34,
          ),
        ),
      ),
    );
  }
}

class _DiagonalStripes extends StatelessWidget {
  const _DiagonalStripes();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.58,
      child: Row(
        children: List.generate(
          3,
          (index) => Container(
            margin: const EdgeInsets.only(right: 12),
            width: 13,
            height: 128,
            color: Colors.white.withOpacity(0.36),
          ),
        ),
      ),
    );
  }
}
