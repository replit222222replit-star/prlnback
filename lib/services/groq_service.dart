import 'dart:convert';
import 'package:http/http.dart' as http;

class GroqService {
  final String apiKey;
  final String endpoint;
  static const String _model = 'llama-3.3-70b-versatile';

  GroqService({required this.apiKey, required this.endpoint});

  Future<String> chatResponse(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.8,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Groq API error: ${response.statusCode} ${response.body}');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = body['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) return 'No response';
      final message = choices[0]['message'] as Map<String, dynamic>?;
      return message?['content'] as String? ?? 'No response';
    } catch (e) {
      throw Exception('GroqService error: $e');
    }
  }
}
