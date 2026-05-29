import 'package:flutter/material.dart';
import '../models/grid_layout_model.dart';
import '../widgets/grid_layout_visualizer.dart';
import 'package:uuid/uuid.dart';

/// Layout editor cho user tạo phòng 3D
class GridLayoutEditorScreen extends StatefulWidget {
  final GridLayout? initialLayout;

  const GridLayoutEditorScreen({Key? key, this.initialLayout}) : super(key: key);

  @override
  State<GridLayoutEditorScreen> createState() => _GridLayoutEditorScreenState();
}

class _GridLayoutEditorScreenState extends State<GridLayoutEditorScreen> {
  late GridLayout _layout;
  double _zoomLevel = 1.0;

  final _roomNameController = TextEditingController();
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  final _cellSizeController = TextEditingController();
  final _roomHeightController = TextEditingController();

  // Furniture editor
  final _furnitureNameController = TextEditingController();
  final _furnitureXController = TextEditingController();
  final _furnitureYController = TextEditingController();
  final _furnitureZController = TextEditingController();
  final _furnitureWidthController = TextEditingController();
  final _furnitureDepthController = TextEditingController();
  final _furnitureHeightController = TextEditingController();
  final _furnitureRotationController = TextEditingController();
  String _furnitureColor = '#FF6B6B';

  @override
  void initState() {
    super.initState();
    if (widget.initialLayout != null) {
      _layout = widget.initialLayout!;
    } else {
      _layout = GridLayout(
        name: 'Phòng mới',
        gridWidth: 5,
        gridHeight: 3,
        cellSize: 1.0,
        roomHeight: 2.8,
        cells: [],
        furnitures: [],
      );
    }
    _initializeControllers();
  }

  void _initializeControllers() {
    _roomNameController.text = _layout.name;
    _widthController.text = _layout.gridWidth.toString();
    _heightController.text = _layout.gridHeight.toString();
    _cellSizeController.text = _layout.cellSize.toString();
    _roomHeightController.text = _layout.roomHeight.toString();
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _cellSizeController.dispose();
    _roomHeightController.dispose();
    _furnitureNameController.dispose();
    _furnitureXController.dispose();
    _furnitureYController.dispose();
    _furnitureZController.dispose();
    _furnitureWidthController.dispose();
    _furnitureDepthController.dispose();
    _furnitureHeightController.dispose();
    _furnitureRotationController.dispose();
    super.dispose();
  }

  void _saveLayout() {
    setState(() {
      _layout.name = _roomNameController.text;
      _layout.gridWidth = int.tryParse(_widthController.text) ?? 5;
      _layout.gridHeight = int.tryParse(_heightController.text) ?? 3;
      _layout.cellSize = double.tryParse(_cellSizeController.text) ?? 1.0;
      _layout.roomHeight = double.tryParse(_roomHeightController.text) ?? 2.8;
    });
  }

  void _showAddFurnitureDialog() {
    _furnitureNameController.clear();
    _furnitureXController.text = '1.0';
    _furnitureYController.text = '1.0';
    _furnitureZController.text = '0.0';
    _furnitureWidthController.text = '1.0';
    _furnitureDepthController.text = '1.0';
    _furnitureHeightController.text = '1.0';
    _furnitureRotationController.text = '0';
    _furnitureColor = '#FF6B6B';

    showDialog(
      context: context,
      builder: (ctx) => _buildFurnitureDialog(ctx),
    );
  }

  Widget _buildFurnitureDialog(BuildContext ctx) {
    return AlertDialog(
      title: const Text('Thêm nội thất'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Furniture name
            TextField(
              controller: _furnitureNameController,
              decoration: const InputDecoration(
                labelText: 'Tên (bed, sofa, table, ...)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Position X, Y, Z
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _furnitureXController,
                    decoration: const InputDecoration(
                      labelText: 'X (m)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _furnitureYController,
                    decoration: const InputDecoration(
                      labelText: 'Y (m)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Size
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _furnitureWidthController,
                    decoration: const InputDecoration(
                      labelText: 'Rộng (m)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _furnitureDepthController,
                    decoration: const InputDecoration(
                      labelText: 'Sâu (m)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Height & Rotation
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _furnitureHeightController,
                    decoration: const InputDecoration(
                      labelText: 'Cao (m)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _furnitureRotationController,
                    decoration: const InputDecoration(
                      labelText: 'Xoay (°)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Color picker
            Row(
              children: [
                const Text('Màu:'),
                const SizedBox(width: 8),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _parseColor(_furnitureColor),
                    border: Border.all(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: _furnitureColor),
                    decoration: const InputDecoration(
                      hintText: '#FF6B6B',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      setState(() => _furnitureColor = val);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () {
            _addFurniture();
            Navigator.pop(ctx);
          },
          child: const Text('Thêm'),
        ),
      ],
    );
  }

  void _addFurniture() {
    final name = _furnitureNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Vui lòng nhập tên')));
      return;
    }

    final furniture = Furniture3D(
      id: const Uuid().v4(),
      className: name,
      x: double.tryParse(_furnitureXController.text) ?? 0,
      y: double.tryParse(_furnitureYController.text) ?? 0,
      z: double.tryParse(_furnitureZController.text) ?? 0,
      width: double.tryParse(_furnitureWidthController.text) ?? 1,
      depth: double.tryParse(_furnitureDepthController.text) ?? 1,
      height: double.tryParse(_furnitureHeightController.text) ?? 1,
      rotation: double.tryParse(_furnitureRotationController.text) ?? 0,
      color: _furnitureColor,
    );

    setState(() {
      _layout.furnitures.add(furniture);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✓ Đã thêm: $name')),
    );
  }

  void _deleteFurniture(String id) {
    setState(() {
      _layout.furnitures.removeWhere((f) => f.id == id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✓ Đã xóa')),
    );
  }

  Color _parseColor(String hexColor) {
    if (!hexColor.startsWith('#')) {
      return Colors.grey;
    }
    final hex = hexColor.replaceFirst('#', '');
    try {
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  void _saveAndExit() {
    _saveLayout();
    Navigator.pop(context, _layout);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo Layout Phòng 3D'),
        backgroundColor: const Color(0xFF2563EB),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveAndExit,
            tooltip: 'Lưu',
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Thoát',
          ),
        ],
      ),
      body: Column(
        children: [
          // Room settings
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade50,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: _roomNameController,
                      decoration: const InputDecoration(
                        labelText: 'Tên phòng',
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => _saveLayout(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _widthController,
                      decoration: const InputDecoration(
                        labelText: 'W',
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => _saveLayout(),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _heightController,
                      decoration: const InputDecoration(
                        labelText: 'H',
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => _saveLayout(),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _showAddFurnitureDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm'),
                  ),
                ],
              ),
            ),
          ),

          // 3D Layout preview
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.white,
              child: GridLayoutVisualizer(
                layout: _layout,
                zoomLevel: _zoomLevel,
                showGrid: true,
                showFurniture: true,
              ),
            ),
          ),

          // Furniture list
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey.shade50,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      'Nội thất (${_layout.furnitures.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _layout.furnitures.length,
                      itemBuilder: (ctx, idx) {
                        final furniture = _layout.furnitures[idx];
                        return ListTile(
                          title: Text(furniture.className),
                          subtitle: Text(
                            '(${furniture.x.toStringAsFixed(1)}, ${furniture.y.toStringAsFixed(1)}) ${furniture.width.toStringAsFixed(1)}x${furniture.depth.toStringAsFixed(1)}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteFurniture(furniture.id),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Example layout template
GridLayout exampleLayout() {
  return GridLayout(
    name: 'Phòng khách',
    gridWidth: 5,
    gridHeight: 3,
    cellSize: 1.0,
    roomHeight: 2.8,
    cells: [],
    furnitures: [
      Furniture3D(
        id: 'sofa1',
        className: 'sofa',
        x: 0.5,
        y: 0.5,
        z: 0,
        width: 1.5,
        depth: 1.0,
        height: 0.8,
        color: '#4ECDC4',
      ),
      Furniture3D(
        id: 'table1',
        className: 'table',
        x: 2.5,
        y: 1.0,
        z: 0,
        width: 1.0,
        depth: 1.0,
        height: 0.5,
        color: '#F7DC6F',
      ),
      Furniture3D(
        id: 'tv1',
        className: 'tv',
        x: 4.0,
        y: 1.0,
        z: 0,
        width: 0.8,
        depth: 0.2,
        height: 1.2,
        color: '#85C1E2',
      ),
    ],
  );
}
