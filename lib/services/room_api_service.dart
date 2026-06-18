import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/env.dart';

class RoomApiService {
  RoomApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String get _baseUrl => EnvConfig.baseUrl.replaceFirst(RegExp(r'/+$'), '');

  Future<List<Map<String, dynamic>>> getRoomsByUser(String userId) async {
    final uri = Uri.parse('$_baseUrl/room/user/$userId');
    final response = await _client.get(uri);
    final Map<String, dynamic> body = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['message'] ?? 'Lỗi lấy danh sách phòng');
    }

    final dynamic data = body['data'];
    if (data is! List) {
      return [];
    }

    return data
        .whereType<Map>()
        .map((room) => Map<String, dynamic>.from(room))
        .toList();
  }

  Future<Map<String, dynamic>> createRoom({
    required String userId,
    required Map<String, dynamic> payload,
  }) async {
    final uri = Uri.parse('$_baseUrl/room/user/$userId');
    return _sendRoomRequest(() {
      return _client.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    });
  }

  Future<Map<String, dynamic>> updateRoom({
    required String roomId,
    required Map<String, dynamic> payload,
  }) async {
    final uri = Uri.parse('$_baseUrl/room/$roomId');
    return _sendRoomRequest(() {
      return _client.put(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    });
  }

  Future<void> deleteRoom(String roomId) async {
    final uri = Uri.parse('$_baseUrl/room/$roomId');
    final response = await _client.delete(uri);
    final Map<String, dynamic> body = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['message'] ?? 'Lỗi xóa phòng');
    }
  }

  Future<Map<String, dynamic>> _sendRoomRequest(
    Future<http.Response> Function() request,
  ) async {
    final response = await request();
    final Map<String, dynamic> body = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['message'] ?? 'Lỗi lưu phòng');
    }

    return body;
  }
}
