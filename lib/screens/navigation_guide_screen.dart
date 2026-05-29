import 'package:flutter/material.dart';
import '../models/navigation_model.dart';

const Color _primaryColor = Color(0xFF2563EB);
const Color _accentColor = Color(0xFF10B981);
const Color _surfaceColor = Color(0xFFF8FAFC);
const Color _cardColor = Color(0xFFFFFFFF);
const Color _textPrimary = Color(0xFF1E293B);

class NavigationGuideScreen extends StatefulWidget {
  final NavigationRoute route;
  final Function(NavigationRoute route, Function(bool verified) onVerified) onWaypointReached;
  final Function() onNavigationComplete;
  final Function() onNavigationCanceled;

  const NavigationGuideScreen({
    Key? key,
    required this.route,
    required this.onWaypointReached,
    required this.onNavigationComplete,
    required this.onNavigationCanceled,
  }) : super(key: key);

  @override
  State<NavigationGuideScreen> createState() => _NavigationGuideScreenState();
}

class _NavigationGuideScreenState extends State<NavigationGuideScreen> {
  late NavigationRoute _route;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _route = widget.route;
  }

  void _handleTakPhoto() {
    setState(() => _isVerifying = true);
    
    // Gọi callback, pass route + callback để ChatScreen gọi khi xong verify
    widget.onWaypointReached(_route, (verified) {
      if (mounted) {
        setState(() => _isVerifying = false);
        
        if (verified) {
          // Verified success, move to next
          _moveToNextWaypoint();
        } else {
          // Show snackbar, user có thể retry hoặc skip
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✗ Chưa xác nhận được vị trí. Hãy thử lại hoặc tiếp tục.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    });
  }

  void _moveToNextWaypoint() {
    bool hasMore = _route.moveToNextWaypoint();
    setState(() {});

    if (!hasMore) {
      // Hoàn thành toàn bộ lộ trình
      widget.onNavigationComplete();
    }
  }

  String _formatDistance(double meters) {
    if (meters < 1) {
      return '${(meters * 100).toStringAsFixed(0)}cm';
    }
    return '${meters.toStringAsFixed(1)}m';
  }

  @override
  Widget build(BuildContext context) {
    final currentWaypoint = _route.getCurrentWaypoint();

    return Scaffold(
      backgroundColor: _surfaceColor,
      appBar: AppBar(
        title: const Text('Hướng Dẫn Đi'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Hủy hướng dẫn?'),
                content: const Text('Bạn có chắc muốn dừng điều hướng không?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Tiếp tục'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onNavigationCanceled();
                      Navigator.pop(context);
                    },
                    child: const Text('Dừng'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      body: currentWaypoint == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.done_all,
                    size: 64,
                    color: _accentColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Bạn đã tới ${_route.endObjectName}!',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      widget.onNavigationComplete();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Quay Lại',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Progress bar
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: _cardColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Tiến độ',
                              style: const TextStyle(
                                fontSize: 14,
                                color: _textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${_route.getProgress().toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _accentColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _route.getProgress() / 100,
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              _accentColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Chặn ${currentWaypoint.index + 1}/${_route.waypoints.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Main instruction
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      border: Border.all(color: Colors.blue.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hướng dẫn hiện tại:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currentWaypoint.instruction,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _primaryColor,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _primaryColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Khoảng cách: ${_formatDistance(currentWaypoint.distance)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Góc: ${currentWaypoint.angle.toStringAsFixed(0)}°',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Target info
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.green.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Đích chặn này:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currentWaypoint.targetObjectName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF047857),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Khi tới nơi, hãy bấm "Chụp ảnh" để xác nhận',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action buttons
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Main capture button
                        ElevatedButton.icon(
                          onPressed: _isVerifying ? null : _handleTakPhoto,
                          icon: _isVerifying
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.camera_alt),
                          label: Text(
                            _isVerifying
                                ? 'Đang xác nhận...'
                                : 'Chụp ảnh để xác nhận',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accentColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Skip button (nếu không detect được)
                        OutlinedButton(
                          onPressed: _isVerifying ? null : _moveToNextWaypoint,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _primaryColor,
                            side: const BorderSide(color: _primaryColor),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Tiếp tục (không xác nhận)'),
                        ),
                      ],
                    ),
                  ),

                  // Route summary
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tóm tắt lộ trình:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Từ: ${_route.startObjectName}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Đến: ${_route.endObjectName}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tổng quãng đường: ${_formatDistance(_route.totalDistance)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _accentColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Số chặn: ${_route.waypoints.length}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
