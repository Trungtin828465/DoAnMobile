import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/auth_controller.dart';
import '../models/user_model.dart';
import '../services/room_service.dart';
import 'room_designer_screen.dart';

const Color _primaryColor = Color(0xFF2563EB);
const Color _accentColor = Color(0xFF10B981);
const Color _surfaceColor = Color(0xFFF8FAFC);
const Color _cardColor = Color(0xFFFFFFFF);
const Color _textPrimary = Color(0xFF1E293B);
const Color _textSecondary = Color(0xFF64748B);

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late AuthController _authController;
  User? _currentUser;
  bool _isLoading = true;
  List<Map<String, dynamic>> _rooms = [];
  bool _isFetchingRooms = false;

  @override
  void initState() {
    super.initState();
    _authController = AuthController();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _authController.dispose();
    super.dispose();
  }

  void _loadCurrentUser() async {
    final user = await _authController.getCurrentUser();
    setState(() {
      _currentUser = user;
      _isLoading = false;
    });

    if (user == null) {
      Navigator.of(context).pushReplacementNamed('/login');
    } else {
      // Fetch danh sách phòng
      _fetchRooms(user.id);
    }
  }

  void _fetchRooms(String userId) async {
    setState(() => _isFetchingRooms = true);
    final rooms = await RoomService.getUserRooms(userId);
    setState(() {
      _rooms = rooms;
      _isFetchingRooms = false;
    });
  }

  void _handleLogout() async {
    await _authController.logout();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _handleCreateNewRoom() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RoomDesignerScreen(),
      ),
    ).then((_) {
      // Refresh rooms khi quay lại từ designer
      if (_currentUser != null) {
        _fetchRooms(_currentUser!.id);
      }
    });
  }

  void _handleSelectRoom(Map<String, dynamic> room) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoomDesignerScreen(existingRoom: room),
      ),
    ).then((_) {
      // Refresh rooms khi quay lại từ designer
      if (_currentUser != null) {
        _fetchRooms(_currentUser!.id);
      }
    });
  }

  void _handleDeleteRoom(String roomId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa phòng'),
        content: const Text('Bạn chắc chắn muốn xóa phòng này?\nHành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đang xóa phòng...')),
              );

              final success = await RoomService.deleteRoom(roomId);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Xóa phòng thành công')),
                );
                // Refresh rooms
                if (_currentUser != null) {
                  _fetchRooms(_currentUser!.id);
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('❌ Lỗi xóa phòng')),
                );
              }
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: _surfaceColor,
      appBar: AppBar(
        title: const Text('3D Room Designer'),
        centerTitle: true,
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Banner thông tin ứng dụng
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryColor, Color(0xFF1d47a3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(24),
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
                          Icons.home_work,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '3D Room Designer',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Xin chào, ${_currentUser?.fullName ?? "User"}',
                              style: const TextStyle(
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
                            'Thiết kế phòng của bạn một cách dễ dàng. Tạo, lưu, sửa và xóa các phòng theo ý muốn.',
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

            // Danh sách phòng
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Phòng của bạn',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                        ),
                      ),
                      Text(
                        '${_rooms.length} phòng',
                        style: const TextStyle(
                          fontSize: 14,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_isFetchingRooms)
                    const Center(
                      child: CircularProgressIndicator(),
                    )
                  else if (_rooms.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.home_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Bạn chưa có phòng nào',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Hãy tạo phòng mới để bắt đầu thiết kế',
                            style: TextStyle(
                              fontSize: 14,
                              color: _textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _rooms.length,
                      itemBuilder: (context, index) {
                        final room = _rooms[index];
                        final roomName = room['RoomName'] ?? room['roomName'] ?? 'Phòng ${index + 1}';
                        final roomType = room['RoomType'] ?? room['roomType'] ?? 'other';
                        final width = room['Width'] ?? room['width'] ?? 0;
                        final height = room['Height'] ?? room['height'] ?? 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: _cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _getRoomIcon(roomType),
                                color: _primaryColor,
                              ),
                            ),
                            title: Text(
                              roomName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              '${width}m × ${height}m • ${_getRoomTypeLabel(roomType)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: _textSecondary,
                              ),
                            ),
                            trailing: PopupMenuButton(
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  child: const Row(
                                    children: [
                                      Icon(Icons.edit, size: 20),
                                      SizedBox(width: 8),
                                      Text('Sửa'),
                                    ],
                                  ),
                                  onTap: () => _handleSelectRoom(room),
                                ),
                                PopupMenuItem(
                                  child: const Row(
                                    children: [
                                      Icon(Icons.delete, size: 20, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Xóa', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                  onTap: () => _handleDeleteRoom(room['_id'] ?? room['id'] ?? ''),
                                ),
                              ],
                            ),
                            onTap: () => _handleSelectRoom(room),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _handleCreateNewRoom,
        backgroundColor: _accentColor,
        icon: const Icon(Icons.add),
        label: const Text('Tạo phòng mới'),
      ),
    );
  }

  IconData _getRoomIcon(String roomType) {
    switch (roomType.toLowerCase()) {
      case 'bedroom':
        return Icons.bed;
      case 'living':
        return Icons.weekend;
      case 'kitchen':
        return Icons.kitchen;
      case 'bathroom':
        return Icons.bathroom;
      case 'office':
        return Icons.work;
      case 'dining':
        return Icons.dinner_dining;
      default:
        return Icons.home;
    }
  }

  String _getRoomTypeLabel(String roomType) {
    switch (roomType.toLowerCase()) {
      case 'bedroom':
        return 'Phòng ngủ';
      case 'living':
        return 'Phòng khách';
      case 'kitchen':
        return 'Bếp';
      case 'bathroom':
        return 'Phòng tắm';
      case 'office':
        return 'Văn phòng';
      case 'dining':
        return 'Phòng ăn';
      default:
        return 'Khác';
    }
  }
}
