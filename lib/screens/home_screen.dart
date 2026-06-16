import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'camera_screen.dart';
import 'room_layout_screen.dart';

const Color _primaryColor = Color(0xFF2563EB);
const Color _accentColor = Color(0xFF10B981);
const Color _surfaceColor = Color(0xFFF8FAFC);
const Color _cardColor = Color(0xFFFFFFFF);
const Color _textPrimary = Color(0xFF1E293B);
const Color _textSecondary = Color(0xFF64748B);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  void _handleLogout() {
    SystemNavigator.pop();
  }

  void _openCameraSupport() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const CameraScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
      ),
    );
  }

  void _openRoomLayout() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const RoomLayoutScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceColor,
      appBar: AppBar(
        title: const Text('AI Hỗ trợ Người Khiếm Thị'),
        centerTitle: true,
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.view_in_ar),
            tooltip: 'Tạo phòng 3D',
            onPressed: _openRoomLayout,
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Bắt đầu hỗ trợ',
            onPressed: _openCameraSupport,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Thoát',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryColor, Color(0xFF1D47A3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.assistant_navigation,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI Hỗ trợ di chuyển',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Nhận diện vật thể, giọng nói và tạo khối phòng 3D',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info, color: Colors.white70, size: 18),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Bạn có thể mở camera hỗ trợ hoặc tạo khối phòng trống 3D từ chiều dài, chiều rộng và chiều cao.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _FeatureCard(
                    icon: Icons.camera_alt_outlined,
                    iconColor: _primaryColor,
                    title: 'Mở camera hỗ trợ',
                    description:
                        'Sử dụng mic, TTS và nhận diện vật thể để hỗ trợ người dùng.',
                    buttonText: 'Bắt đầu hỗ trợ',
                    buttonColor: _accentColor,
                    onPressed: _openCameraSupport,
                  ),
                  const SizedBox(height: 16),
                  _FeatureCard(
                    icon: Icons.view_in_ar_outlined,
                    iconColor: _primaryColor,
                    title: 'Tạo khối phòng 3D',
                    description:
                        'Nhập W/D/H, chọn màu tường, chọn sàn và xem phòng trống dạng 3D.',
                    buttonText: 'Tạo phòng',
                    buttonColor: _primaryColor,
                    onPressed: _openRoomLayout,
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

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.buttonColor,
    required this.onPressed,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String buttonText;
  final Color buttonColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 56, color: iconColor),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: _textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.arrow_forward),
              label: Text(buttonText),
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
