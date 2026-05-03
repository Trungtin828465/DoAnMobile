import 'package:flutter/material.dart';

import '../controllers/room_designer_controller.dart';

class RoomDesignerScreen extends StatefulWidget {
  const RoomDesignerScreen({super.key});

  @override
  State<RoomDesignerScreen> createState() => _RoomDesignerScreenState();
}

class _RoomDesignerScreenState extends State<RoomDesignerScreen> {
  late final RoomDesignerController _controller;
  late final TextEditingController _widthController;
  late final TextEditingController _heightController;
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _controller = RoomDesignerController();
    _controller.initialize();
    _widthController = TextEditingController(text: '12');
    _heightController = TextEditingController(text: '8');
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

  void _applyRoomSize() {
    final width = int.tryParse(_widthController.text.trim());
    final height = int.tryParse(_heightController.text.trim());
    if (width == null || height == null) {
      _showMessage('Please enter valid width and height.');
      return;
    }
    _controller.setRoomSize(width: width, height: height);
  }

  void _saveToSession() {
    final status = _controller.saveToSession();
    switch (status) {
      case SaveStatus.ok:
        _showMessage('Saved to session.');
      case SaveStatus.empty:
        _showMessage('Add at least one item before saving.');
      case SaveStatus.missingDoor:
        _showMessage('Door is required before saving.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F1EC),
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Column(
                children: [
                  _Header(step: _controller.step),
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
                          final isWide = constraints.maxWidth >= 980;
                          final content = _controller.step ==
                                  RoomDesignerStep.size
                              ? _SizeStep(
                                  widthController: _widthController,
                                  heightController: _heightController,
                                  onApply: _applyRoomSize,
                                )
                              : _DesignStep(
                                  controller: _controller,
                                  onBack: _controller.backToSizeStep,
                                  onSave: _saveToSession,
                                  onMessage: _showMessage,
                                );
                          return isWide
                              ? content
                              : SingleChildScrollView(
                                  child: content,
                                );
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
  const _Header({required this.step});

  final RoomDesignerStep step;

  @override
  Widget build(BuildContext context) {
    final subtitle = step == RoomDesignerStep.size
        ? 'Step 1/2: Choose room size'
        : 'Step 2/2: Drag items into the room';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.grid_view, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '2D Room Layout Designer',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              step == RoomDesignerStep.size ? 'Size' : 'Design',
              style: const TextStyle(color: Colors.white),
            ),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Room size',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter width and height (grid units).',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: widthController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Width',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: heightController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Height',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _PresetChip(
                        label: '10 x 12',
                        onTap: () {
                          widthController.text = '10';
                          heightController.text = '12';
                        },
                      ),
                      _PresetChip(
                        label: '12 x 18',
                        onTap: () {
                          widthController.text = '12';
                          heightController.text = '18';
                        },
                      ),
                      _PresetChip(
                        label: '20 x 30',
                        onTap: () {
                          widthController.text = '20';
                          heightController.text = '30';
                        },
                      ),
                      _PresetChip(
                        label: '40 x 60',
                        onTap: () {
                          widthController.text = '40';
                          heightController.text = '60';
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
                      label: const Text('Next: choose items'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Card(
            elevation: 0,
            color: const Color(0xFF111827),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tips',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '- Use bigger size for larger layouts.\n'
                    '- You can change size later, items will reset.\n'
                    '- Start with 12x8 for quick tests.',
                    style: TextStyle(color: Colors.white70, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.drag_indicator, color: Colors.white70),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Next step lets you drag furniture cards into the grid.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(label),
      ),
    );
  }
}

class _DesignStep extends StatelessWidget {
  const _DesignStep({
    required this.controller,
    required this.onBack,
    required this.onSave,
    required this.onMessage,
  });

  final RoomDesignerController controller;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final ValueChanged<String> onMessage;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;
        final palette = _PalettePanel(
          controller: controller,
          onBack: onBack,
          onSave: onSave,
        );
        final canvas = _RoomCanvas(
          controller: controller,
          onDropResult: (ok) {
            if (!ok) {
              onMessage('Drop inside the room area.');
            }
          },
        );

        if (isWide) {
          return Row(
            children: [
              SizedBox(width: 320, child: palette),
              const SizedBox(width: 16),
              Expanded(child: canvas),
            ],
          );
        }

        return Column(
          children: [
            palette,
            const SizedBox(height: 16),
            SizedBox(height: 420, child: canvas),
          ],
        );
      },
    );
  }
}

class _PalettePanel extends StatelessWidget {
  const _PalettePanel({
    required this.controller,
    required this.onBack,
    required this.onSave,
  });

  final RoomDesignerController controller;
  final VoidCallback onBack;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Furniture library',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Room: ${controller.roomWidth} x ${controller.roomHeight}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: controller.catalog
                      .map(
                        (item) => _PaletteItem(item: item),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: controller.hasDoor
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    controller.hasDoor
                        ? Icons.check_circle
                        : Icons.info_outline,
                    color: controller.hasDoor
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFEF6C00),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      controller.hasDoor
                          ? 'Door added. You can save now.'
                          : 'Door is required before saving.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save_alt),
                label: const Text('Save to session'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaletteItem extends StatelessWidget {
  const _PaletteItem({required this.item});

  final FurnitureItem item;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: item.color.withOpacity(0.15),
            foregroundColor: item.color,
            child: Icon(item.icon),
          ),
          const SizedBox(height: 10),
          Text(
            item.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text('${item.width} x ${item.height} cells'),
        ],
      ),
    );

    return Draggable<FurnitureItem>(
      data: item,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(opacity: 0.85, child: chip),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: chip),
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
  static const double _rotateHandleRadius = 14;

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
    _draggingId = null;
    _dragAnchor = null;
  }

  bool _isRotateHandleHit(Offset position) {
    final hoveredId = widget.controller.hoveredId;
    if (hoveredId == null || !widget.controller.isRotatable(hoveredId)) {
      return false;
    }
    final rect = widget.controller.itemScreenRect(hoveredId, _currentSize());
    if (rect == null) {
      return false;
    }
    final dx = position.dx - rect.center.dx;
    final dy = position.dy - rect.center.dy;
    return (dx * dx + dy * dy) <= _rotateHandleRadius * _rotateHandleRadius;
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<FurnitureItem>(
      onAcceptWithDetails: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) {
          widget.onDropResult(false);
          return;
        }
        final local = box.globalToLocal(details.offset);
        final ok = widget.controller.addItemAtScreen(
          local,
          _currentSize(),
          details.data,
        );
        widget.onDropResult(ok);
      },
      builder: (context, candidateData, rejectedData) {
        return MouseRegion(
          onHover: (event) => widget.controller.updateHoverAtScreen(
            event.localPosition,
            _currentSize(),
          ),
          onExit: (_) => widget.controller.clearHover(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              if (_isRotateHandleHit(details.localPosition)) {
                final hoveredId = widget.controller.hoveredId;
                if (hoveredId != null) {
                  widget.controller.rotateItem(hoveredId);
                }
                return;
              }
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
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFFF9F7F3), Color(0xFFEDE7E1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: const Color(0xFFE2E8F0)),
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
        child: Text(message, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}
