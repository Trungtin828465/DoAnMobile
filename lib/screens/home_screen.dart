import 'dart:async';

import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/room_api_service.dart';
import 'auth_screen.dart';
import 'camera_screen.dart';
import 'room_layout_screen.dart';

const Color _homePrimary = Color(0xFF58CFC6);
const Color _homeButton = Color(0xFF4EAFC0);
const Color _homeDark = Color(0xFF111827);
const Color _homeMuted = Color(0xFF6B7280);
const Color _homeDanger = Color(0xFFE11D48);
const Color _homeSuccess = Color(0xFF10B981);

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
    final roomId = (room['_id'] ?? '').toString();
    final roomName = (room['RoomName'] ?? 'phòng').toString();
    if (roomId.isEmpty) return;

    final confirmed = await _confirmDeleteRoom(roomName);
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
            margin: const EdgeInsets.all(18),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.16),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: _homeDanger),
                    SizedBox(width: 10),
                    Text(
                      'Xóa phòng?',
                      style: TextStyle(
                        color: _homeDark,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Bạn có chắc muốn xóa "$roomName" không? Dữ liệu layout và vị trí vật trong phòng này sẽ bị xóa.',
                  style: const TextStyle(
                    color: _homeMuted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          foregroundColor: _homeDark,
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text('Hủy'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: _homeDanger,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.76,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _roomApiService.getRoomsByUser(widget.user.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _EmptyState(
                    icon: Icons.error_outline,
                    title: 'Không tải được danh sách phòng',
                    message: '${snapshot.error}',
                  );
                }

                final rooms = snapshot.data ?? [];
                if (rooms.isEmpty) {
                  return const _EmptyState(
                    icon: Icons.meeting_room_outlined,
                    title: 'Chưa có phòng đã lưu',
                    message: 'Tạo một phòng mới rồi bấm lưu để phòng xuất hiện ở đây.',
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SheetHeader(
                      icon: Icons.home_work_outlined,
                      title: 'Danh sách phòng',
                      subtitle: 'Xem, sửa hoặc xóa layout đã lưu.',
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
                        itemCount: rooms.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
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
          'Bạn cần tạo và lưu ít nhất một phòng trước khi mở camera.',
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        builder: (context) {
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SheetHeader(
                    icon: Icons.home_work_outlined,
                    title: 'Chọn layout để di chuyển',
                    subtitle:
                        'Chọn phòng đã lưu để mở camera và bắt đầu chỉ đường.',
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
                      itemCount: rooms.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final room = rooms[index];
                        return _SelectableRoomTile(
                          room: room,
                          onTap: () => Navigator.pop(context, room),
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

    final color = type == _NoticeType.success ? _homeSuccess : _homeDanger;
    final icon =
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

    Overlay.of(context).insert(_noticeEntry!);
    _noticeTimer = Timer(const Duration(seconds: 3), () {
      _noticeEntry?.remove();
      _noticeEntry = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _homePrimary,
      body: Stack(
        children: [
          const _HomeBackgroundDecor(),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                    child: _HomeTopBar(onLogout: _handleLogout),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
                    child: _WelcomeBlock(user: widget.user),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(18, 28, 18, 24),
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(34),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.16),
                          blurRadius: 34,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bạn muốn làm gì?',
                          style: TextStyle(
                            color: _homeDark,
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Chọn chức năng để bắt đầu demo hỗ trợ người khiếm thị.',
                          style: TextStyle(
                            color: _homeMuted,
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _PrimaryFeatureCard(onTap: _openCameraSupport),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _MiniFeatureCard(
                                icon: Icons.add_home_work_outlined,
                                title: 'Tạo phòng',
                                subtitle: 'Layout 3D',
                                color: _homeButton,
                                onTap: _openRoomLayout,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _MiniFeatureCard(
                                icon: Icons.folder_open_outlined,
                                title: 'Phòng đã lưu',
                                subtitle: 'Sửa / xóa',
                                color: const Color(0xFF8B5CF6),
                                onTap: _showSavedRooms,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const _DemoNoteCard(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _NoticeType { success, error }

class _HomeBackgroundDecor extends StatelessWidget {
  const _HomeBackgroundDecor();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -70,
            right: -72,
            child: _SoftCircle(size: 220, opacity: 0.18),
          ),
          Positioned(
            bottom: -86,
            left: -78,
            child: _SoftCircle(size: 220, opacity: 0.13),
          ),
          const Positioned(
            top: 105,
            right: -12,
            child: _HomeStripes(),
          ),
        ],
      ),
    );
  }
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Trang chủ',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
            ),
          ),
        ),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.20),
            borderRadius: BorderRadius.circular(18),
          ),
          child: IconButton(
            onPressed: onLogout,
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout_rounded),
            color: Colors.white,
            iconSize: 28,
          ),
        ),
      ],
    );
  }
}

class _WelcomeBlock extends StatelessWidget {
  const _WelcomeBlock({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final displayName =
        user.fullName.trim().isEmpty ? 'người dùng' : user.fullName.trim();
final parts = displayName.trim().split(RegExp(r'\s+'));

final shortName = parts.length >= 2
    ? '${parts[parts.length - 2]} ${parts[parts.length - 1]}'
    : displayName;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.20),
          ),
          child: Center(
            child: Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.assistant_navigation,
                color: _homeButton,
                size: 36,
              ),
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xin chào, $shortName',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    height: 1.06,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.82),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryFeatureCard extends StatelessWidget {
  const _PrimaryFeatureCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          constraints: const BoxConstraints(minHeight: 190),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4EAFC0), Color(0xFF58CFC6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: _homeButton.withOpacity(0.26),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -24,
                top: -18,
                child: Icon(
                  Icons.camera_alt_rounded,
                  size: 122,
                  color: Colors.white.withOpacity(0.12),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Bắt đầu hỗ trợ di chuyển',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                      height: 1.08,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Chọn layout, mở mic và tìm vật',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.88),
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: _homeButton,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class _MiniFeatureCard extends StatelessWidget {
  const _MiniFeatureCard({
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
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          height: 150,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFE8F0EF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: color, size: 29),
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _homeDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _homeMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: color),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DemoNoteCard extends StatelessWidget {
  const _DemoNoteCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _homePrimary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _homePrimary.withOpacity(0.20)),
      ),
      child: const Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: _homeButton),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Demo: layout 3D hiển thị vị trí người dùng, camera detect chạy ngầm.',
              style: TextStyle(
                color: _homeDark,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 10),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: _homePrimary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: _homeButton, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _homeDark,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _homeMuted,
                        height: 1.32,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SelectableRoomTile extends StatelessWidget {
  const _SelectableRoomTile({required this.room, required this.onTap});

  final Map<String, dynamic> room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final roomName = (room['RoomName'] ?? 'Phòng chưa đặt tên').toString();
    final objectCount = room['Objects'] is List ? room['Objects'].length : 0;
    final width = room['Width'];
    final depth = room['Depth'];

    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: _homePrimary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.home_work_outlined,
                  color: _homeButton,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      roomName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _homeDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _RoomBadge(text: '${width ?? '-'} x ${depth ?? '-'} m'),
                        _RoomBadge(text: '$objectCount vật'),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _homeMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomBadge extends StatelessWidget {
  const _RoomBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _homeMuted,
          fontSize: 12,
          fontWeight: FontWeight.w800,
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
    final objectCount = room['Objects'] is List ? room['Objects'].length : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8F0EF)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: _homePrimary.withOpacity(0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.home_work_outlined,
              color: _homeButton,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  roomName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _homeDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _RoomBadge(text: '${width ?? '-'} x ${depth ?? '-'} m'),
                    _RoomBadge(text: '$objectCount vật'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _RoomIconAction(
            icon: Icons.edit_outlined,
            color: _homeButton,
            tooltip: 'Sửa',
            onTap: onEdit,
          ),
          const SizedBox(width: 4),
          _RoomIconAction(
            icon: Icons.delete_outline,
            color: _homeDanger,
            tooltip: 'Xóa',
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}

class _RoomIconAction extends StatelessWidget {
  const _RoomIconAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
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
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: _homePrimary.withOpacity(0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: _homeButton),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _homeDark,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _homeMuted, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftCircle extends StatelessWidget {
  const _SoftCircle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _HomeStripes extends StatelessWidget {
  const _HomeStripes();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.55,
      child: Row(
        children: List.generate(
          3,
          (index) => Container(
            margin: const EdgeInsets.only(right: 13),
            width: 14,
            height: 132,
            color: Colors.white.withOpacity(0.30),
          ),
        ),
      ),
    );
  }
}





