import 'dart:async';

import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/room_api_service.dart';
import 'auth_screen.dart';
import 'camera_screen.dart';
import 'room_layout_screen.dart';

const Color _primaryColor = Color(0xFF2563EB);
const Color _accentColor = Color(0xFF10B981);
const Color _dangerColor = Color(0xFFDC2626);
const Color _surfaceColor = Color(0xFFF8FAFC);
const Color _cardColor = Color(0xFFFFFFFF);
const Color _textPrimary = Color(0xFF1E293B);
const Color _textSecondary = Color(0xFF64748B);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.user});

  final User user;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final RoomApiService _roomApiService = RoomApiService();
  OverlayEntry? _noticeEntry;
  Timer? _noticeTimer;

  @override
  void dispose() {
    _noticeTimer?.cancel();
    _noticeEntry?.remove();
    super.dispose();
  }

  void _handleLogout() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }

  Future<void> _openCameraSupport() async {
    final selectedRoom = await _selectRoomForCamera();
    if (!mounted || selectedRoom == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScreen(
          user: widget.user,
          initialRoomLayout: selectedRoom,
        ),
      ),
    );
  }

  void _openRoomLayout() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RoomLayoutScreen(user: widget.user)),
    );
  }

  void _openRoomEditor(Map<String, dynamic> room) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomLayoutScreen(
          user: widget.user,
          initialRoom: room,
        ),
      ),
    );
  }

  Future<void> _deleteRoom(Map<String, dynamic> room) async {
    final String roomId = (room['_id'] ?? '').toString();
    final String roomName = (room['RoomName'] ?? 'phòng').toString();
    if (roomId.isEmpty) return;

    final bool confirmed = await _confirmDeleteRoom(roomName);
    if (!confirmed) return;

    try {
      await _roomApiService.deleteRoom(roomId);
      if (!mounted) return;
      Navigator.pop(context);
      _showNotice('Đã xóa phòng "$roomName"', type: _NoticeType.success);
      _showSavedRooms();
    } catch (error) {
      if (!mounted) return;
      _showNotice('Lỗi xóa phòng: $error', type: _NoticeType.error);
    }
  }

  Future<bool> _confirmDeleteRoom(String roomName) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.16),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: _dangerColor),
                    SizedBox(width: 10),
                    Text(
                      'Xóa phòng?',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Bạn có chắc muốn xóa "$roomName" không?',
                  style: const TextStyle(color: _textSecondary, height: 1.4),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Hủy'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _dangerColor,
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Xóa'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    return result == true;
  }

  Future<void> _showSavedRooms() async {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.74,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _roomApiService.getRoomsByUser(widget.user.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _EmptyState(
                    icon: Icons.error_outline,
                    title: 'Không tải được danh sách',
                    message: '${snapshot.error}',
                  );
                }

                final rooms = snapshot.data ?? [];
                if (rooms.isEmpty) {
                  return const _EmptyState(
                    icon: Icons.meeting_room_outlined,
                    title: 'Chưa có phòng đã lưu',
                    message: 'Tạo một phòng mới rồi bấm Lưu để phòng xuất hiện ở đây.',
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
                      child: Text(
                        'Phòng đã lưu',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: _textPrimary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                        itemCount: rooms.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return _SavedRoomTile(
                            room: rooms[index],
                            onEdit: () => _openRoomEditor(rooms[index]),
                            onDelete: () => _deleteRoom(rooms[index]),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _selectRoomForCamera() async {
    try {
      final rooms = await _roomApiService.getRoomsByUser(widget.user.id);
      if (!mounted) return null;

      if (rooms.isEmpty) {
        _showNotice(
          'Bạn cần tạo và lưu ít nhất một phòng trước khi mở camera',
          type: _NoticeType.error,
        );
        return null;
      }

      rooms.sort((a, b) {
        final aDate = _parseRoomDate(a);
        final bDate = _parseRoomDate(b);
        return bDate.compareTo(aDate);
      });

      return showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        builder: (context) {
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.62,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
                    child: Text(
                      'Chọn layout dùng cho camera',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: _textPrimary,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: Text(
                      'Camera vẫn detect là chính, layout chỉ hỗ trợ suy luận hướng đi nhanh hơn.',
                      style: TextStyle(color: _textSecondary, height: 1.35),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      itemCount: rooms.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final room = rooms[index];
                        final roomName =
                            (room['RoomName'] ?? 'Phòng chưa đặt tên')
                                .toString();
                        final objectCount =
                            room['Objects'] is List ? room['Objects'].length : 0;
                        return Material(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => Navigator.pop(context, room),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.map_outlined,
                                    color: _primaryColor,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          roomName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: _textPrimary,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$objectCount vật trong layout',
                                          style: const TextStyle(
                                            color: _textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: _textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (error) {
      if (mounted) {
        _showNotice('Lỗi tải danh sách phòng: $error', type: _NoticeType.error);
      }
      return null;
    }
  }

  DateTime _parseRoomDate(Map<String, dynamic> room) {
    final updatedAt = room['UpdatedAt']?.toString();
    final createdAt = room['CreatedAt']?.toString();
    return DateTime.tryParse(updatedAt ?? '') ??
        DateTime.tryParse(createdAt ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  void _showNotice(String message, {required _NoticeType type}) {
    _noticeTimer?.cancel();
    _noticeEntry?.remove();

    final overlay = Overlay.of(context);
    final Color color = type == _NoticeType.success ? _accentColor : _dangerColor;
    final IconData icon =
        type == _NoticeType.success ? Icons.check_circle : Icons.error_outline;

    _noticeEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 14,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(_noticeEntry!);
    _noticeTimer = Timer(const Duration(seconds: 3), () {
      _noticeEntry?.remove();
      _noticeEntry = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceColor,
      appBar: AppBar(
        title: const Text('Trang chủ'),
        backgroundColor: Colors.white,
        foregroundColor: _textPrimary,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          children: [
            _UserHeader(user: widget.user),
            const SizedBox(height: 18),
            _HomeActionCard(
              icon: Icons.camera_alt_outlined,
              title: 'Hỗ trợ di chuyển',
              subtitle: 'Mở camera, mic và TTS để tìm vật.',
              color: _accentColor,
              onTap: _openCameraSupport,
            ),
            const SizedBox(height: 12),
            _HomeActionCard(
              icon: Icons.add_home_work_outlined,
              title: 'Tạo phòng mới',
              subtitle: 'Tạo layout 3D và lưu vị trí vật.',
              color: _primaryColor,
              onTap: _openRoomLayout,
            ),
            const SizedBox(height: 12),
            _HomeActionCard(
              icon: Icons.folder_open_outlined,
              title: 'Danh sách phòng',
              subtitle: 'Xem, sửa hoặc xóa phòng đã lưu.',
              color: const Color(0xFF7C3AED),
              onTap: _showSavedRooms,
            ),
          ],
        ),
      ),
    );
  }
}

enum _NoticeType { success, error }

class _UserHeader extends StatelessWidget {
  const _UserHeader({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primaryColor, Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.assistant_navigation,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xin chào, ${user.fullName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: _textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedRoomTile extends StatelessWidget {
  const _SavedRoomTile({
    required this.room,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> room;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final roomName = (room['RoomName'] ?? 'Phòng chưa đặt tên').toString();
    final width = room['Width'];
    final depth = room['Depth'];
    final height = room['Height'];
    final objectCount = room['Objects'] is List ? room['Objects'].length : 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.view_in_ar, color: _primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  roomName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$width x $depth x $height m • $objectCount vật',
                  style: const TextStyle(color: _textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sửa',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Xóa',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: _dangerColor),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: _textSecondary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
