import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../controllers/room_designer_controller.dart';
import '../config/env.dart';

class RoomService {
  // Lấy baseUrl từ .env
  static String get baseUrl {
      return EnvConfig.baseUrl;
  }

  static const Duration requestTimeout = Duration(seconds: 30);

  /// Lưu layout thiết kế vào database
  /// 
  /// Parameters:
  /// - userId: ID người dùng từ login
  /// - roomName: Tên phòng (vd: "Phòng ngủ")
  /// - roomType: Loại phòng (vd: "bedroom", "living", "kitchen")
  /// - width: Chiều rộng (meter)
  /// - height: Chiều cao (meter)
  /// - items: Danh sách vật trong phòng
  static Future<bool> saveRoomLayout({
    required String userId,
    required String roomName,
    required String roomType,
    required int width,
    required int height,
    required List<PlacedItem> items,
  }) async {
    try {
      debugPrint('📤 Đang lưu room: $roomName cho user: $userId');

      // Format lại Objects theo cấu trúc API expect
      final objectsList = items.map((item) {
        return {
          'ObjectName': item.name,
          'PosX': item.x,
          'PosY': item.y,
          'Width': item.width,
          'Height': item.height,
        };
      }).toList();

      final payload = {
        'RoomName': roomName,
        'Width': width,
        'Height': height,
        'RoomType': roomType,
        'Objects': objectsList,
      };

      debugPrint('📦 Payload: ${jsonEncode(payload)}');

      // POST request tới API
      final response = await http.post(
        Uri.parse('$baseUrl/room/user/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(requestTimeout);

      debugPrint('✓ Response status: ${response.statusCode}');
      debugPrint('✓ Response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        debugPrint('✅ Lưu room thành công!');
        return true;
      } else {
        try {
          final error = jsonDecode(response.body);
          final message = error['message'] ?? 'Lỗi không xác định';
          debugPrint('❌ Lỗi: $message');
        } catch (e) {
          debugPrint('❌ Lỗi: ${response.body}');
        }
        return false;
      }
    } on http.ClientException catch (e) {
      debugPrint('❌ SaveRoom - Lỗi kết nối: $baseUrl');
      debugPrint('Chi tiết: $e');
      return false;
    } catch (e) {
      debugPrint('❌ Exception: $e');
      return false;
    }
  }

  /// Lấy danh sách phòng của người dùng
  static Future<List<Map<String, dynamic>>> getUserRooms(String userId) async {
    try {
      debugPrint('📥 Lấy danh sách rooms của user: $userId');

      final response = await http.get(
        Uri.parse('$baseUrl/room/user/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(requestTimeout);

      debugPrint('✓ Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rooms = List<Map<String, dynamic>>.from(data['data'] ?? []);
        debugPrint('✅ Lấy ${rooms.length} phòng thành công');
        return rooms;
      } else {
        try {
          final error = jsonDecode(response.body);
          final message = error['message'] ?? 'Lỗi không xác định';
          debugPrint('❌ Lỗi: $message');
        } catch (e) {
          debugPrint('❌ Lỗi: ${response.body}');
        }
        return [];
      }
    } on http.ClientException catch (e) {
      debugPrint('❌ GetRooms - Lỗi kết nối: $baseUrl');
      debugPrint('Chi tiết: $e');
      return [];
    } catch (e) {
      debugPrint('❌ Exception: $e');
      return [];
    }
  }

  /// Xóa room (chờ backend support)
  static Future<bool> deleteRoom(String roomId) async {
    try {
      debugPrint('🗑️ Đang xóa room: $roomId');

      final response = await http.delete(
        Uri.parse('$baseUrl/room/$roomId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(requestTimeout);

      debugPrint('✓ Response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint('✅ Xóa room thành công');
        return true;
      } else {
        try {
          final error = jsonDecode(response.body);
          final message = error['message'] ?? 'Lỗi không xác định';
          debugPrint('❌ Lỗi: $message');
        } catch (e) {
          debugPrint('❌ Lỗi: ${response.body}');
        }
        return false;
      }
    } on http.ClientException catch (e) {
      debugPrint('❌ DeleteRoom - Lỗi kết nối: $baseUrl');
      debugPrint('Chi tiết: $e');
      return false;
    } catch (e) {
      debugPrint('❌ Exception: $e');
      return false;
    }
  }
}
