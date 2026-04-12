import 'dart:convert';
import 'package:http/http.dart' as http;

class RemoteApi {
  final String baseUrl;
  RemoteApi({required this.baseUrl});

  // Запросить код авторизации
  Future<Map<String, dynamic>> requestCode() async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/request-code'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Сервер недоступен: ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // Проверить статус сессии
  Future<Map<String, dynamic>> checkAuthStatus(String sessionId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/status/$sessionId'),
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Status check failed: ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // Heartbeat
  Future<Map<String, dynamic>> sendHeartBeat(
      String uid, Map<String, dynamic> payload) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/log'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw Exception('Heartbeat failed: ${response.statusCode}');
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('sendHeartBeat error: $e');
    }
  }
}
