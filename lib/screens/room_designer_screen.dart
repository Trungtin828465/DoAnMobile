import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/room_designer_controller.dart';
import '../models/user_model.dart';

const Color _primaryColor = Color(0xFF2563EB);
const Color _accentColor = Color(0xFF10B981);
const Color _surfaceColor = Color(0xFFF8FAFC);
const Color _cardColor = Color(0xFFFFFFFF);
const Color _textPrimary = Color(0xFF1E293B);
const Color _textSecondary = Color(0xFF64748B);

String _formatMeters(double value) => value.toStringAsFixed(1);

class RoomDesignerScreen extends StatefulWidget {
  final Map<String, dynamic>? existingRoom;

  const RoomDesignerScreen({super.key, this.existingRoom});

  @override
  State<RoomDesignerScreen> createState() => _RoomDesignerScreenState();
}

class _RoomDesignerScreenState extends State<RoomDesignerScreen> {
  late final RoomDesignerController _controller;
  late final TextEditingController _widthController;
  late final TextEditingController _heightController;
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _controller = RoomDesignerController();
    _controller.initialize();
    
    _isEditMode = widget.existingRoom != null;
    
    // Load room data nếu edit mode
    if (_isEditMode) {
      final room = widget.existingRoom!;
      final width = (room['Width'] ?? 4).toString();
      final height = (room['Height'] ?? 5).toString();
      _widthController = TextEditingController(text: width);
      _heightController = TextEditingController(text: height);
      
      // Load room data vào controller
      _controller.loadRoomData(room);
    } else {
      _widthController = TextEditingController(text: '4');
      _heightController = TextEditingController(text: '5');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _showMessage(String text) {
    _messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  void _showSaveRoomDialog() async {
    final roomNameController = TextEditingController();
    
    // Lấy user data từ storage
    String userName = 'Người dùng';
    String userId = '';
    
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userJson = prefs.getString('user_data');
      if (userJson != null) {
        final userData = jsonDecode(userJson);
        final user = User.fromJson(userData);
        userName = user.fullName;
        userId = user.id;
      }
    } catch (e) {
      debugPrint('Lỗi lấy user data: $e');
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          String selectedType = 'bedroom';

          return AlertDialog(
            title: const Text('Lưu phòng thiết kế'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hiển thị username (không input)
                  const SizedBox(height: 12),
                  const Text(
                    'Tên người dùng',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      userName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),

                  // Room name field
                  const SizedBox(height: 16),
                  const Text(
                    'Tên phòng',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: roomNameController,
                    decoration: InputDecoration(
                      hintText: 'vd: Phòng ngủ, Phòng khách',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),

                  // Room type dropdown
                  const SizedBox(height: 16),
                  const Text(
                    'Loại phòng',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: selectedType,
                    items: const [
                      DropdownMenuItem(value: 'bedroom', child: Text('Phòng ngủ')),
                      DropdownMenuItem(value: 'living', child: Text('Phòng khách')),
                      DropdownMenuItem(value: 'kitchen', child: Text('Bếp')),
                      DropdownMenuItem(value: 'bathroom', child: Text('Phòng tắm')),
                      DropdownMenuItem(value: 'office', child: Text('Văn phòng')),
                      DropdownMenuItem(value: 'dining', child: Text('Phòng ăn')),
                      DropdownMenuItem(value: 'other', child: Text('Khác')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedType = value);
                      }
                    },
                  ),

                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '📍 Thông tin lưu: Tên phòng, kích thước, vị trí vật, ảnh vật',
                      style: TextStyle(fontSize: 12, color: _textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
                onPressed: () async {
                  final roomName = roomNameController.text.trim();

                  if (roomName.isEmpty) {
                    _showMessage('Vui lòng nhập tên phòng');
                    return;
                  }

                  if (userId.isEmpty) {
                    _showMessage('Lỗi: Không tìm thấy thông tin người dùng');
                    return;
                  }

                  Navigator.pop(context);
                  
                  // Show loading
                  _showMessage('Đang lưu...');

                  // Call API
                  final success = await _controller.saveRoomToAPI(
                    userId: userId,
                    roomName: roomName,
                    roomType: selectedType,
                  );

                  if (success) {
                    _showMessage('✅ Lưu phòng thành công!');
                    // Redirect về home sau 1.5 giây
                    await Future.delayed(const Duration(milliseconds: 1500));
                    if (mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                    }
                  } else {
                    _showMessage('❌ Lưu phòng thất bại, kiểm tra kết nối');
                  }
                },
                child: const Text('Lưu'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _applyRoomSize() {
    final width = double.tryParse(_widthController.text.trim());
    final height = double.tryParse(_heightController.text.trim());
    if (width == null || height == null) {
      _showMessage('Please enter valid width and height.');
      return;
    }
    _controller.setRoomSize(widthMeters: width, heightMeters: height);
  }

  void _handleBackButton() {
    if (_isEditMode) {
      // Edit mode: quay về home
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } else {
      // Create mode: quay về size step
      _controller.backToSizeStep();
    }
  }

  void _saveToSession() {
    // Hiển thị dialog để nhập thông tin phòng
    _showSaveRoomDialog();
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        backgroundColor: _surfaceColor,
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Column(
                children: [
                  _Header(
                    step: _controller.step,
                    onBack: _handleBackButton,
                    isEditMode: _isEditMode,
                  ),
                  if (_controller.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _ErrorBanner(message: _controller.errorMessage!),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final content = _controller.step ==
                                  RoomDesignerStep.size
                              ? _SizeStep(
                                  widthController: _widthController,
                                  heightController: _heightController,
                                  onApply: _applyRoomSize,
                                )
                              : _DesignStep(
                                  controller: _controller,
                                  onBack: _handleBackButton,
                                  onSave: _saveToSession,
                                  onMessage: _showMessage,
                                  isEditMode: _isEditMode,
                                );
                          return content;
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.step,
    required this.onBack,
    this.isEditMode = false,
  });

  final RoomDesignerStep step;
  final VoidCallback onBack;
  final bool isEditMode;

  @override
  Widget build(BuildContext context) {
    final subtitle = step == RoomDesignerStep.size
        ? 'Step 1/2: Choose room size'
        : 'Step 2/2: Drag items into the room';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Back button
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: onBack,
                  tooltip: 'Quay lại',
                ),
              ),
              const SizedBox(width: 12),
              if (step == RoomDesignerStep.design)
                Image.asset(
                  'assets/anh/logo.png',
                  height: 40,
                  width: 40,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.grid_view, color: _primaryColor, size: 20),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.grid_view, color: _primaryColor, size: 24),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditMode ? 'Sửa phòng' : 'Room Design Studio',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  step == RoomDesignerStep.size ? '1 of 2' : '2 of 2',
                  style: const TextStyle(color: _accentColor, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SizeStep extends StatelessWidget {
  const _SizeStep({
    required this.widthController,
    required this.heightController,
    required this.onApply,
  });

  final TextEditingController widthController;
  final TextEditingController heightController;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Card(
        elevation: 0,
        color: _cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        shadowColor: Colors.black.withOpacity(0.08),
        margin: const EdgeInsets.symmetric(horizontal: 0),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Room size',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter width and height in meters (m).',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _textSecondary,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                '1 cell = ${_formatMeters(RoomDesignerController.metersPerCell)} m',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widthController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Width (m)',
                        labelStyle: const TextStyle(color: _textSecondary),
                        prefixIcon: const Icon(Icons.straighten, color: _primaryColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _primaryColor, width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: heightController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Height (m)',
                        labelStyle: const TextStyle(color: _textSecondary),
                        prefixIcon: const Icon(Icons.straighten, color: _primaryColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _primaryColor, width: 2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Quick select',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _textSecondary,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PresetChip(
                    label: '4 x 5 m',
                    icon: Icons.home,
                    onTap: () {
                      widthController.text = '4';
                      heightController.text = '5';
                    },
                  ),
                  _PresetChip(
                    label: '3 x 4 m',
                    icon: Icons.apartment,
                    onTap: () {
                      widthController.text = '3';
                      heightController.text = '4';
                    },
                  ),
                  _PresetChip(
                    label: '5 x 7 m',
                    icon: Icons.villa,
                    onTap: () {
                      widthController.text = '5';
                      heightController.text = '7';
                    },
                  ),
                  _PresetChip(
                    label: '6 x 8 m',
                    icon: Icons.house,
                    onTap: () {
                      widthController.text = '6';
                      heightController.text = '8';
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onApply,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Continue to design'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.onTap,
    this.icon = Icons.check_circle_outline,
  });

  final String label;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: _primaryColor.withOpacity(0.1),
        highlightColor: _primaryColor.withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _primaryColor, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesignStep extends StatefulWidget {
  const _DesignStep({
    required this.controller,
    required this.onBack,
    required this.onSave,
    required this.onMessage,
    this.isEditMode = false,
  });

  final RoomDesignerController controller;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final ValueChanged<String> onMessage;
  final bool isEditMode;

  @override
  State<_DesignStep> createState() => _DesignStepState();
}

class _DesignStepState extends State<_DesignStep> {
  void _openFurnitureModal() {
    showDialog(
      context: context,
      builder: (context) => _FurnitureModal(
        controller: widget.controller,
        onSelected: (item) {
          // Add item at center position
          final box = context.findRenderObject() as RenderBox?;
          if (box != null) {
            final canvasSize = box.size;
            final centerX = canvasSize.width / 2;
            final centerY = canvasSize.height / 2;
            widget.controller.addItemAtScreen(
              Offset(centerX, centerY),
              canvasSize,
              item,
            );
          }
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Full screen canvas
        _RoomCanvas(
          controller: widget.controller,
          onDropResult: (ok) {
            if (!ok) {
              widget.onMessage('Thả trong vùng phòng.');
            }
          },
        ),

        // Header với nút back + save
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back, color: _textPrimary),
                  tooltip: 'Quay lại',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.isEditMode ? 'Sửa phòng' : 'Thiết kế phòng',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: _textPrimary,
                            ),
                      ),
                      Text(
                        '${widget.controller.roomWidth}×${widget.controller.roomHeight} cells',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                if (widget.controller.hasDoor)
                  IconButton(
                    onPressed: widget.onSave,
                    icon: const Icon(Icons.save_alt, color: _accentColor),
                    tooltip: 'Lưu',
                  ),
              ],
            ),
          ),
        ),

        // FAB để chọn đồ vật
        Positioned(
          bottom: 20,
          left: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FloatingActionButton.extended(
                onPressed: _openFurnitureModal,
                icon: const Icon(Icons.add),
                label: const Text('Thêm đồ vật'),
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
              ),
              const SizedBox(height: 12),
              // Door status
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.controller.hasDoor
                      ? _accentColor.withOpacity(0.12)
                      : Color(0xFFFEA500).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.controller.hasDoor
                        ? _accentColor.withOpacity(0.4)
                        : Color(0xFFFEA500).withOpacity(0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.controller.hasDoor ? Icons.check_circle : Icons.info_outline,
                      color: widget.controller.hasDoor ? _accentColor : Color(0xFFFEA500),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.controller.hasDoor ? 'Có cửa ✓' : 'Cần cửa',
                      style: TextStyle(
                        color: widget.controller.hasDoor ? _accentColor : Color(0xFFFEA500),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FurnitureModal extends StatefulWidget {
  const _FurnitureModal({
    required this.controller,
    required this.onSelected,
  });

  final RoomDesignerController controller;
  final ValueChanged<FurnitureItem> onSelected;

  @override
  State<_FurnitureModal> createState() => _FurnitureModalState();
}

class _FurnitureModalState extends State<_FurnitureModal> {
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Entry',
    'Sleep',
    'Seating',
    'Dining',
    'Storage',
    'Decor',
    'Tech',
  ];

  Map<String, List<FurnitureItem>> _groupByCategory() {
    const categoryOrder = {
      'Entry': ['door', 'window'],
      'Sleep': ['bed'],
      'Seating': ['sofa', 'chair'],
      'Dining': ['table'],
      'Storage': ['cabinet'],
      'Decor': ['lamp', 'plant', 'frame'],
      'Tech': ['tv', 'laptop'],
    };

    final grouped = <String, List<FurnitureItem>>{};
    for (final category in categoryOrder.keys) {
      grouped[category] = [];
    }

    for (final item in widget.controller.catalog) {
      for (final entry in categoryOrder.entries) {
        if (entry.value.contains(item.type)) {
          grouped[entry.key]?.add(item);
          break;
        }
      }
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByCategory();
    final categories = grouped.entries.where((e) => e.value.isNotEmpty).toList();
    
    final filteredItems = _selectedCategory == 'All'
        ? widget.controller.catalog
        : categories
            .firstWhere((e) => e.key == _selectedCategory, orElse: () => MapEntry('', []))
            .value;

    return Dialog(
      backgroundColor: _surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.home_work, color: _primaryColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Chọn đồ vật',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: _textSecondary),
                  padding: const EdgeInsets.all(0),
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Category filter
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final cat in _categories)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        label: Text(cat),
                        selected: _selectedCategory == cat,
                        onSelected: (_) {
                          setState(() => _selectedCategory = cat);
                        },
                        backgroundColor: Colors.transparent,
                        selectedColor: _primaryColor.withOpacity(0.2),
                        side: BorderSide(
                          color: _selectedCategory == cat ? _primaryColor : _textSecondary.withOpacity(0.3),
                        ),
                        labelStyle: TextStyle(
                          color: _selectedCategory == cat ? _primaryColor : _textPrimary,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Grid items
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.9,
                ),
                itemCount: filteredItems.length,
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  return _ModalFurnitureItem(
                    item: item,
                    onTap: () {
                      widget.onSelected(item);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModalFurnitureItem extends StatelessWidget {
  const _ModalFurnitureItem({
    required this.item,
    required this.onTap,
  });

  final FurnitureItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.asset(
                  item.assetPath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: item.color.withOpacity(0.2),
                      child: Icon(
                        Icons.image_not_supported,
                        color: item.color,
                        size: 32,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                item.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _PalettePanel extends StatefulWidget {
  const _PalettePanel({
    required this.controller,
    required this.onBack,
    required this.onSave,
  });

  final RoomDesignerController controller;
  final VoidCallback onBack;
  final VoidCallback onSave;

  @override
  State<_PalettePanel> createState() => _PalettePanelState();
}

class _PalettePanelState extends State<_PalettePanel> {
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Entry',
    'Sleep',
    'Seating',
    'Dining',
    'Storage',
    'Decor',
    'Tech',
  ];

  Map<String, List<FurnitureItem>> _groupByCategory() {
    const categoryOrder = {
      'Entry': ['door', 'window'],
      'Sleep': ['bed'],
      'Seating': ['sofa', 'chair'],
      'Dining': ['table'],
      'Storage': ['cabinet'],
      'Decor': ['lamp', 'plant', 'frame'],
      'Tech': ['tv', 'laptop'],
    };

    final grouped = <String, List<FurnitureItem>>{};
    for (final category in categoryOrder.keys) {
      grouped[category] = [];
    }

    for (final item in widget.controller.catalog) {
      for (final entry in categoryOrder.entries) {
        if (entry.value.contains(item.type)) {
          grouped[entry.key]?.add(item);
          break;
        }
      }
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByCategory();
    final categories = grouped.entries.where((e) => e.value.isNotEmpty).toList();
    
    // Filter categories by selected filter
    final filteredCategories = _selectedCategory == 'All'
        ? categories
        : categories.where((e) => e.key == _selectedCategory).toList();

    return Card(
      elevation: 0,
      color: _cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      shadowColor: Colors.black.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.home_work, color: _primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Furniture library',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: _textPrimary,
                              ),
                        ),
                        Text(
                          '${widget.controller.roomWidth}×${widget.controller.roomHeight} cells',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: _textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.close),
                    color: _textSecondary,
                    tooltip: 'Back',
                    iconSize: 22,
                    padding: const EdgeInsets.all(8),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: Colors.grey.shade200, height: 1),
              const SizedBox(height: 12),

              // Category filter buttons
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final cat in _categories)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FilterChip(
                          label: Text(cat),
                          selected: _selectedCategory == cat,
                          onSelected: (_) {
                            setState(() => _selectedCategory = cat);
                          },
                          backgroundColor: Colors.transparent,
                          selectedColor: _primaryColor.withOpacity(0.2),
                          side: BorderSide(
                            color: _selectedCategory == cat ? _primaryColor : _textSecondary.withOpacity(0.3),
                          ),
                          labelStyle: TextStyle(
                            color: _selectedCategory == cat ? _primaryColor : _textPrimary,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Divider(color: Colors.grey.shade200, height: 1),
              const SizedBox(height: 12),

              // Categories with items (NO Expanded here!)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < filteredCategories.length; i++) ...[
                    _CategorySection(
                      category: filteredCategories[i].key,
                      items: filteredCategories[i].value,
                    ),
                    if (i < filteredCategories.length - 1)
                      Column(
                        children: [
                          const SizedBox(height: 12),
                          Divider(color: Colors.grey.shade100, height: 1),
                          const SizedBox(height: 12),
                        ],
                      )
                    else
                      const SizedBox(height: 16),
                  ]
                ],
              ),

              // Door status
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.controller.hasDoor
                      ? _accentColor.withOpacity(0.12)
                      : Color(0xFFFEA500).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.controller.hasDoor
                        ? _accentColor.withOpacity(0.4)
                        : Color(0xFFFEA500).withOpacity(0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.controller.hasDoor ? Icons.check_circle : Icons.info_outline,
                      color: widget.controller.hasDoor ? _accentColor : Color(0xFFFEA500),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.controller.hasDoor
                            ? 'Ready to save ✓'
                            : 'Add a door first',
                        style: TextStyle(
                          color: widget.controller.hasDoor ? _accentColor : Color(0xFFFEA500),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: widget.onSave,
                  icon: const Icon(Icons.save_alt, size: 18),
                  label: const Text('Save layout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.items,
  });

  final String category;
  final List<FurnitureItem> items;

  static const categoryIcons = {
    'Entry': Icons.door_front_door,
    'Sleep': Icons.bed,
    'Seating': Icons.weekend,
    'Dining': Icons.restaurant,
    'Storage': Icons.storage,
    'Decor': Icons.palette,
    'Tech': Icons.devices,
  };

  static const categoryColors = {
    'Entry': Color(0xFF8B6F47),
    'Sleep': Color(0xFF5C6BC0),
    'Seating': Color(0xFF26A69A),
    'Dining': Color(0xFFEF6C00),
    'Storage': Color(0xFF546E7A),
    'Decor': Color(0xFF2E7D32),
    'Tech': Color(0xFF1565C0),
  };

  @override
  Widget build(BuildContext context) {
    final icon = categoryIcons[category] ?? Icons.widgets;
    final color = categoryColors[category] ?? _primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 8),
            Text(
              category,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: _textPrimary,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${items.length}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items.map((item) => _PaletteItem(item: item)).toList(),
        ),
      ],
    );
  }
}

class _PaletteItem extends StatefulWidget {
  const _PaletteItem({required this.item});

  final FurnitureItem item;

  @override
  State<_PaletteItem> createState() => _PaletteItemState();
}

class _PaletteItemState extends State<_PaletteItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final widthMeters = widget.item.width * RoomDesignerController.metersPerCell;
    final heightMeters = widget.item.height * RoomDesignerController.metersPerCell;

    final chip = GestureDetector(
      onLongPress: () => setState(() => _isHovered = !_isHovered),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 150,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered
                  ? _primaryColor.withOpacity(0.4)
                  : const Color(0xFFE2E8F0),
              width: _isHovered ? 2 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? _primaryColor.withOpacity(0.15)
                    : Colors.black.withOpacity(0.05),
                blurRadius: _isHovered ? 12 : 8,
                offset: Offset(0, _isHovered ? 6 : 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 65,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: widget.item.color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(8),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.asset(
                      widget.item.assetPath,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('✗ Lỗi tải ${widget.item.assetPath}: $error');
                        return Container(
                          color: widget.item.color.withOpacity(0.2),
                          child: Icon(
                            Icons.image_not_supported,
                            color: widget.item.color,
                            size: 32,
                          ),
                        );
                      },
                    ),
                    if (_isHovered)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.drag_indicator,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.item.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_formatMeters(widthMeters)}×${_formatMeters(heightMeters)}m',
                  style: const TextStyle(
                    color: _primaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Draggable<FurnitureItem>(
      data: widget.item,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.9,
          child: Transform.scale(
            scale: 1.1,
            child: chip,
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: chip),
      child: chip,
    );
  }
}

class _RoomCanvas extends StatefulWidget {
  const _RoomCanvas({required this.controller, required this.onDropResult});

  final RoomDesignerController controller;
  final ValueChanged<bool> onDropResult;

  @override
  State<_RoomCanvas> createState() => _RoomCanvasState();
}

class _RoomCanvasState extends State<_RoomCanvas> {
  String? _draggingId;
  Offset? _dragAnchor;

  Size _currentSize() {
    final renderBox = context.findRenderObject() as RenderBox?;
    return renderBox?.size ?? Size.zero;
  }

  void _beginDrag(Offset position) {
    final hit = widget.controller.hitTest(position, _currentSize());
    if (hit == null) {
      widget.controller.selectItem(null);
      return;
    }

    widget.controller.selectItem(hit);
    _draggingId = hit;
    final rect = widget.controller.itemScreenRect(hit, _currentSize());
    if (rect != null) {
      _dragAnchor = position - rect.topLeft;
    }
    debugPrint('Bat dau keo: $_draggingId');
  }

  void _updateDrag(Offset position) {
    if (_draggingId == null || _dragAnchor == null) {
      return;
    }
    widget.controller.moveSelectedToScreenTopLeft(
      position - _dragAnchor!,
      _currentSize(),
    );
  }

  void _endDrag() {
    if (_draggingId != null) {
      debugPrint('Ket thuc keo: $_draggingId');
    }
    _draggingId = null;
    _dragAnchor = null;
  }


  @override
  Widget build(BuildContext context) {
    return DragTarget<FurnitureItem>(
      onAcceptWithDetails: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) {
          debugPrint('✗ Không lấy được RenderBox');
          widget.onDropResult(false);
          return;
        }
        
        // Chuyển global coordinate sang local (canvas coordinate)
        final local = box.globalToLocal(details.offset);
        final size = _currentSize();
        
        debugPrint('📍 Drop coordinate:');
        debugPrint('  Global: ${details.offset}');
        debugPrint('  Local: $local');
        debugPrint('  Canvas size: $size');
        debugPrint('  Item: ${details.data.name}');
        
        final ok = widget.controller.addItemAtScreen(
          local,
          size,
          details.data,
        );
        
        if (ok) {
          debugPrint('✓ Đã thêm ${details.data.name}');
        } else {
          debugPrint('✗ Thả ngoài phòng hoặc lỗi khác');
        }
        
        widget.onDropResult(ok);
      },
      onWillAccept: (data) {
        // Hỗ trợ visual feedback trên mobile
        return data != null;
      },
      builder: (context, candidateData, rejectedData) {
        final isAccepting = candidateData.isNotEmpty;
        return MouseRegion(
          onHover: (event) => widget.controller.updateHoverAtScreen(
            event.localPosition,
            _currentSize(),
          ),
          onExit: (_) => widget.controller.clearHover(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              final hit = widget.controller.hitTest(
                details.localPosition,
                _currentSize(),
              );
              widget.controller.selectItem(hit);
            },
            onPanStart: (details) => _beginDrag(details.localPosition),
            onPanUpdate: (details) => _updateDrag(details.localPosition),
            onPanEnd: (_) => _endDrag(),
            onPanCancel: _endDrag,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: isAccepting
                      ? [const Color(0xFFF0F9FF), const Color(0xFFE0F2FE)]
                      : [const Color(0xFFFAFBFC), const Color(0xFFF1F5F9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: isAccepting 
                      ? _primaryColor.withOpacity(0.5)
                      : const Color(0xFFE2E8F0),
                  width: isAccepting ? 2 : 1,
                ),
              ),
              child: CustomPaint(
                painter: _RoomPainter(widget.controller),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RoomPainter extends CustomPainter {
  _RoomPainter(this.controller) : super(repaint: controller);

  final RoomDesignerController controller;

  @override
  void paint(Canvas canvas, Size size) {
    controller.render(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _RoomPainter oldDelegate) => false;
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFB91C1C),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
