class ObjectMappingService {
  static const Map<String, List<String>> vietnameseToYoloLabel = {
    'giường': ['bed'],
    'cái giường': ['bed'],
    'chiếc giường': ['bed'],

    'sofa': ['sofa'],
    'ghế sofa': ['sofa'],
    'cái sofa': ['sofa'],

    'ghế': ['chair'],
    'ghế ngồi': ['chair'],
    'cái ghế': ['chair'],
    'chiếc ghế': ['chair'],

    'bàn': ['table'],
    'cái bàn': ['table'],
    'chiếc bàn': ['table'],
    'bàn làm việc': ['table'],

    'tủ quần áo': ['wardrobe'],
    'tủ đồ': ['wardrobe'],
    'cái tủ': ['wardrobe'],

    'tủ lạnh': ['refrigerator'],
    'cái tủ lạnh': ['refrigerator'],

    'tivi': ['tv'],
    'ti vi': ['tv'],
    'tv': ['tv'],
    'cái tivi': ['tv'],

    'cửa': ['door'],
    'cái cửa': ['door'],
    'cửa ra vào': ['door'],
    'cửa phòng': ['door'],

    'cửa sổ': ['window'],
    'cái cửa sổ': ['window'],

    'quạt': ['fan'],
    'cái quạt': ['fan'],
    'quạt máy': ['fan'],

    'laptop': ['laptop'],
    'máy tính': ['laptop'],
    'máy tính xách tay': ['laptop'],

    'máy giặt': ['washing_machine'],
    'cái máy giặt': ['washing_machine'],
  };

  static const Map<String, Map<String, dynamic>> yoloLabelInfo = {
    'bed': {'name': 'Giường', 'icon': '🛏️', 'dangerLevel': 1},
    'sofa': {'name': 'Sofa', 'icon': '🛋️', 'dangerLevel': 1},
    'chair': {'name': 'Ghế', 'icon': '🪑', 'dangerLevel': 1},
    'table': {'name': 'Bàn', 'icon': '📦', 'dangerLevel': 1},
    'wardrobe': {'name': 'Tủ quần áo', 'icon': '🚪', 'dangerLevel': 1},
    'refrigerator': {'name': 'Tủ lạnh', 'icon': '🧊', 'dangerLevel': 1},
    'tv': {'name': 'Tivi', 'icon': '📺', 'dangerLevel': 1},
    'door': {'name': 'Cửa', 'icon': '🚪', 'dangerLevel': 2},
    'window': {'name': 'Cửa sổ', 'icon': '🪟', 'dangerLevel': 2},
    'fan': {'name': 'Quạt', 'icon': '🌀', 'dangerLevel': 1},
    'laptop': {'name': 'Laptop', 'icon': '💻', 'dangerLevel': 1},
    'washing_machine': {'name': 'Máy giặt', 'icon': '🧺', 'dangerLevel': 1},
  };

  static String? parseVoiceCommand(String voiceText) {
    final lowerText = voiceText.toLowerCase().trim();

    for (final entry in vietnameseToYoloLabel.entries) {
      if (lowerText.contains(entry.key)) {
        return entry.value.first;
      }
    }

    return null;
  }

  static Map<String, dynamic>? getObjectInfo(String yoloLabel) {
    return yoloLabelInfo[yoloLabel];
  }

  static String getVietnameseName(String yoloLabel) {
    final info = getObjectInfo(yoloLabel);
    return info?['name'] ?? yoloLabel;
  }

  static String getIcon(String yoloLabel) {
    final info = getObjectInfo(yoloLabel);
    return info?['icon'] ?? '📦';
  }

  static int getDangerLevel(String yoloLabel) {
    final info = getObjectInfo(yoloLabel);
    return info?['dangerLevel'] ?? 1;
  }

  static bool isDangerous(String yoloLabel) {
    return getDangerLevel(yoloLabel) >= 2;
  }
}
