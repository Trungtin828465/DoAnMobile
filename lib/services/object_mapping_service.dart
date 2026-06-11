/// Service để mapping giữa lệnh tiếng Việt và YOLO label

class ObjectMappingService {
  /// Mapping tiếng Việt → YOLO labels (12 classes từ model/best.pt)
  static const Map<String, List<String>> vietnameseToYoloLabel = {
    // Tìm kiếm
    'ghế': ['chair'],
    'ghế ngồi': ['chair'],
    'cái ghế': ['chair'],
    'chiếc ghế': ['chair'],

    'bàn': ['table'],
    'cái bàn': ['table'],
    'chiếc bàn': ['table'],
    'bàn làm việc': ['table'],

    'giường': ['bed'],
    'cái giường': ['bed'],
    'chiếc giường': ['bed'],

    'sofa': ['sofa'],
    'cái sofa': ['sofa'],

    'cửa': ['door'],
    'cái cửa': ['door'],
    'cửa ra vào': ['door'],
    'cửa phòng': ['door'],

    'cửa sổ': ['window'],
    'cái cửa sổ': ['window'],

    'tivi': ['tv'],
    'ti vi': ['tv'],
    'cái tivi': ['tv'],

    'laptop': ['laptop'],
    'máy tính': ['laptop', 'laptop'],

    'đèn': ['lamp'],
    'cái đèn': ['lamp'],
    'chiếc đèn': ['lamp'],

    'tủ quần áo': ['wardrobe'],
    'tủ': ['wardrobe'],
    'cái tủ': ['wardrobe'],

    'người': ['person'],
    'con người': ['person'],

    'cầu thang': ['stairs'],
    'thang': ['stairs'],

    'chậu cây': ['potted plant'],
    'cây cảnh': ['potted plant'],

    'khung ảnh': ['photo frame'],
    'bức ảnh': ['photo frame'],
  };

  /// YOLO label info (name, icon, danger level)
  static const Map<String, Map<String, dynamic>> yoloLabelInfo = {
    'bed': {
      'name': 'Giường',
      'icon': '🛏️',
      'dangerLevel': 1, // 1=low, 2=medium, 3=high
    },
    'sofa': {
      'name': 'Sofa',
      'icon': '🛋️',
      'dangerLevel': 1,
    },
    'chair': {
      'name': 'Ghế',
      'icon': '🪑',
      'dangerLevel': 1,
    },
    'table': {
      'name': 'Bàn',
      'icon': '📦',
      'dangerLevel': 1,
    },
    'lamp': {
      'name': 'Đèn',
      'icon': '💡',
      'dangerLevel': 1,
    },
    'tv': {
      'name': 'Tivi',
      'icon': '📺',
      'dangerLevel': 1,
    },
    'laptop': {
      'name': 'Laptop',
      'icon': '💻',
      'dangerLevel': 1,
    },
    'wardrobe': {
      'name': 'Tủ quần áo',
      'icon': '🚪',
      'dangerLevel': 1,
    },
    'window': {
      'name': 'Cửa sổ',
      'icon': '🪟',
      'dangerLevel': 2,
    },
    'door': {
      'name': 'Cửa',
      'icon': '🚪',
      'dangerLevel': 2,
    },
    'potted plant': {
      'name': 'Chậu cây',
      'icon': '🌿',
      'dangerLevel': 1,
    },
    'photo frame': {
      'name': 'Khung ảnh',
      'icon': '🖼️',
      'dangerLevel': 1,
    },
    'person': {
      'name': 'Người',
      'icon': '👤',
      'dangerLevel': 2,
    },
    'stairs': {
      'name': 'Cầu thang',
      'icon': '🪜',
      'dangerLevel': 3,
    },
  };

  /// Chuyển giọng nói Tiếng Việt thành YOLO label
  /// Input: "Tìm cái bàn"
  /// Output: "table"
  static String? parseVoiceCommand(String voiceText) {
    final lowerText = voiceText.toLowerCase().trim();

    // Tìm label khớp
    for (final entry in vietnameseToYoloLabel.entries) {
      if (lowerText.contains(entry.key)) {
        // Trả về label đầu tiên
        return entry.value.first;
      }
    }

    return null;
  }

  /// Lấy thông tin object từ YOLO label
  static Map<String, dynamic>? getObjectInfo(String yoloLabel) {
    return yoloLabelInfo[yoloLabel];
  }

  /// Lấy tên Tiếng Việt từ YOLO label
  static String getVietnameseName(String yoloLabel) {
    final info = getObjectInfo(yoloLabel);
    return info?['name'] ?? yoloLabel;
  }

  /// Lấy icon từ YOLO label
  static String getIcon(String yoloLabel) {
    final info = getObjectInfo(yoloLabel);
    return info?['icon'] ?? '📦';
  }

  /// Lấy mức độ nguy hiểm (1=low, 2=medium, 3=high)
  static int getDangerLevel(String yoloLabel) {
    final info = getObjectInfo(yoloLabel);
    return info?['dangerLevel'] ?? 1;
  }

  /// Kiểm tra có phải object nguy hiểm không
  static bool isDangerous(String yoloLabel) {
    return getDangerLevel(yoloLabel) >= 2;
  }
}
