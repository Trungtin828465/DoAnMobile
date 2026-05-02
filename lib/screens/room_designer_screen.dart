import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_joystick/flutter_joystick.dart';

import '../controllers/room_designer_controller.dart';
import '../models/layout_model.dart';

class RoomDesignerScreen extends StatefulWidget {
  const RoomDesignerScreen({super.key});

  @override
  State<RoomDesignerScreen> createState() => _RoomDesignerScreenState();
}

class _RoomDesignerScreenState extends State<RoomDesignerScreen>
    with SingleTickerProviderStateMixin {
  late final RoomDesignerController _controller;
  late final Ticker _ticker;
  Duration? _lastFrame;

  @override
  void initState() {
    super.initState();
    _controller = RoomDesignerController();
    _ticker = createTicker(_onTick)..start();
    _controller.initialize();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final previous = _lastFrame;
    _lastFrame = elapsed;

    if (previous == null) {
      return;
    }

    final dt =
        (elapsed - previous).inMicroseconds / Duration.microsecondsPerSecond;
    _controller.onFrame(dt.clamp(0, 0.1));
  }

  Future<void> _saveLayout() async {
    final savedPath = await _controller.saveLayout();
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          savedPath == null
              ? 'Layout chưa sẵn sàng để lưu.'
              : 'Đã lưu layout: $savedPath',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final selected = _controller.selectedObject;
        return Stack(
          fit: StackFit.expand,
          children: [
            _SceneViewport(controller: _controller),
            if (_controller.errorMessage != null)
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: _ErrorBanner(message: _controller.errorMessage!),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _ControlOverlay(
                controller: _controller,
                onSaveLayout: _saveLayout,
                selectedObject: selected,
              ),
            ),
            const Positioned(top: 8, left: 8, child: _HelpTag()),
          ],
        );
      },
    );
  }
}

class _SceneViewport extends StatelessWidget {
  const _SceneViewport({required this.controller});

  final RoomDesignerController controller;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (details) {
        // Right-side look drag for FPS camera.
        if (details.globalPosition.dx >=
            MediaQuery.of(context).size.width / 2) {
          controller.applyLookDrag(details.delta.dx, details.delta.dy);
        }
      },
      child: CustomPaint(
        painter: _ScenePainter(controller),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.controller) : super(repaint: controller);

  final RoomDesignerController controller;

  @override
  void paint(Canvas canvas, Size size) {
    controller.render(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) => false;
}

class _ControlOverlay extends StatelessWidget {
  const _ControlOverlay({
    required this.controller,
    required this.onSaveLayout,
    required this.selectedObject,
  });

  final RoomDesignerController controller;
  final Future<void> Function() onSaveLayout;
  final LayoutObject? selectedObject;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: Colors.black.withValues(alpha: 0.2),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: SizedBox(
                  width: 130,
                  height: 130,
                  child: Joystick(
                    listener: (details) {
                      controller.setMoveInput(details.x, -details.y);
                    },
                    period: const Duration(milliseconds: 16),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: _EditorPanel(
                controller: controller,
                selectedObject: selectedObject,
                onSaveLayout: onSaveLayout,
              ),
            ),
            Expanded(
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Drag phai\n(de nhin)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorPanel extends StatelessWidget {
  const _EditorPanel({
    required this.controller,
    required this.selectedObject,
    required this.onSaveLayout,
  });

  final RoomDesignerController controller;
  final LayoutObject? selectedObject;
  final Future<void> Function() onSaveLayout;

  @override
  Widget build(BuildContext context) {
    final items = controller.layoutObjects;

    return Card(
      color: Colors.black.withValues(alpha: 0.6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                dropdownColor: Colors.black87,
                value: selectedObject?.id,
                hint: const Text(
                  'Chon object',
                  style: TextStyle(color: Colors.white),
                ),
                style: const TextStyle(color: Colors.white),
                items: items
                    .map(
                      (entry) => DropdownMenuItem<String>(
                        value: entry.id,
                        child: Text('${entry.className} (${entry.id})'),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) {
                    controller.selectObject(value);
                  }
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    selectedObject == null
                        ? 'Chua chon object'
                        : 'Class: ${selectedObject!.className}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                if (controller.isUsingFallbackForSelection)
                  const Tooltip(
                    message:
                        'Dang dung fallback geometry do model GLB/.model chua san sang.',
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.amber,
                      size: 18,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        selectedObject == null
                            ? null
                            : () => controller.rotateSelectedObjectY(-15),
                    child: const Text('Rotate -15 deg'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        selectedObject == null
                            ? null
                            : () => controller.rotateSelectedObjectY(15),
                    child: const Text('Rotate +15 deg'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 70,
              child: GestureDetector(
                onPanUpdate:
                    selectedObject == null
                        ? null
                        : (details) {
                          controller.moveSelectedObjectByDelta(
                            deltaX: details.delta.dx * 0.01,
                            deltaZ: details.delta.dy * 0.01,
                          );
                        },
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Center(
                    child: Text(
                      'Move mode: drag de doi vi tri tren san (X/Z)',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Move speed', style: TextStyle(color: Colors.white)),
                Expanded(
                  child: Slider(
                    value: controller.moveSpeed,
                    min: 0.5,
                    max: 3.0,
                    divisions: 25,
                    label: controller.moveSpeed.toStringAsFixed(2),
                    onChanged: controller.setMoveSpeed,
                  ),
                ),
                Text(
                  '${controller.moveSpeed.toStringAsFixed(1)} m/s',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onSaveLayout,
                icon: const Icon(Icons.save_alt),
                label: const Text('Save layout'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.withValues(alpha: 0.8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(message, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _HelpTag extends StatelessWidget {
  const _HelpTag();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.black.withValues(alpha: 0.45),
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Text(
          'FPS controls:\n- Joystick trai: move/strafe\n- Drag phai: yaw/pitch',
          style: TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }
}
