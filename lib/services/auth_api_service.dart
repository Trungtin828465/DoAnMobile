import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/env.dart';
import '../models/user_model.dart';

class AuthApiService {
  AuthApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String get _baseUrl => EnvConfig.baseUrl.replaceFirst(RegExp(r'/+$'), '');

  Future<User> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'Email': email,
        'Password': password,
      }),
    );

    return _parseUserResponse(response);
  }

  Future<User> register({
    required String fullName,
    required String email,
    required String numberPhone,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'FullName': fullName,
        'Email': email,
        'NumberPhone': numberPhone,
        'Password': password,
      }),
    );

    return _parseUserResponse(response);
  }

  User _parseUserResponse(http.Response response) {
    final Map<String, dynamic> body = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['message'] ?? 'Lỗi xác thực');
    }

    final dynamic userJson = body['user'] ?? body['data'];
    if (userJson is! Map<String, dynamic>) {
      throw Exception('Backend không trả về thông tin người dùng');
    }

    return User.fromJson(userJson);
  }
}
