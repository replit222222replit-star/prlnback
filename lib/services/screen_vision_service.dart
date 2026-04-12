import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

enum VisionState { idle, running, analyzing }

class ScreenVisionService extends ChangeNotifier {
  final String groqApiKey;

  static const _channel = MethodChannel('neo_genesis/screen');

  VisionState _state = VisionState.idle;
  VisionState get state => _state;

  bool _hasPermission = false;
  bool get hasPermission => _hasPermission;

  String _lastAnalysis = '';
  String get lastAnalysis => _lastAnalysis;

  Timer? _captureTimer;

  ScreenVisionService({required this.groqApiKey});

  // Запросить разрешение на захват экрана
  Future<bool> requestPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestPermission');
      _hasPermission = result ?? false;
      notifyListeners();
      return _hasPermission;
    } catch (e) {
      debugPrint('[Vision] Permission error: $e');
      return false;
    }
  }

  // Запустить анализ каждые 2 секунды
  Future<void> startVision() async {
    if (!_hasPermission) {
      final granted = await requestPermission();
      if (!granted) return;
    }

    _state = VisionState.running;
    notifyListeners();

    _captureTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_state == VisionState.running) {
        await _captureAndAnalyze();
      }
    });
  }

  void stopVision() {
    _captureTimer?.cancel();
    _captureTimer = null;
    _channel.invokeMethod('stopCapture');
    _state = VisionState.idle;
    notifyListeners();
  }

  Future<void> _captureAndAnalyze() async {
    _state = VisionState.analyzing;
    notifyListeners();

    try {
      // Захват экрана через нативный код
      final base64Image =
          await _channel.invokeMethod<String>('captureScreen');

      if (base64Image == null || base64Image.isEmpty) {
        _state = VisionState.running;
        notifyListeners();
        return;
      }

      // Отправляем в Groq Vision
      final analysis = await _analyzeWithGroq(base64Image);
      _lastAnalysis = analysis;
      _state = VisionState.running;
      notifyListeners();
    } catch (e) {
      debugPrint('[Vision] Capture error: $e');
      _state = VisionState.running;
      notifyListeners();
    }
  }

  Future<String> _analyzeWithGroq(String base64Image) async {
    final response = await http.post(
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $groqApiKey',
      },
      body: jsonEncode({
        'model': 'meta-llama/llama-4-scout-17b-16e-instruct',
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/jpeg;base64,$base64Image',
                },
              },
              {
                'type': 'text',
                'text':
                    'Опиши кратко что сейчас на экране телефона. 1-2 предложения.',
              },
            ],
          }
        ],
        'max_tokens': 150,
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['choices'][0]['message']['content'] as String;
    } else {
      debugPrint('[Vision] Groq error: ${response.body}');
      return '';
    }
  }

  @override
  void dispose() {
    stopVision();
    super.dispose();
  }
}
