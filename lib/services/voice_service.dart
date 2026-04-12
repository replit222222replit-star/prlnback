import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum VoiceState { idle, wakeListening, listening, processing, speaking }

class VoiceService extends ChangeNotifier {
  final String groqApiKey;

  final FlutterTts _tts = FlutterTts();
  final AudioRecorder _recorder = AudioRecorder();

  VoiceState _state = VoiceState.idle;
  VoiceState get state => _state;

  String _transcript = '';
  String get transcript => _transcript;

  String _response = '';
  String get response => _response;

  bool _isInitialized = false;
  Timer? _wakeWordTimer;

  static const String _systemPrompt = '''
Ты — Jarvis, интеллектуальный голосовой ассистент встроенный в Android телефон.
Ты умный, краткий и полезный. Отвечай на том же языке на котором тебя спросили.
Отвечай коротко — максимум 2-3 предложения если не просят подробностей.
''';

  // Wake words на разных языках
  static const List<String> _wakeWords = [
    'jarvis', 'джарвис', 'джервис', 'hey jarvis', 'эй джарвис',
    'ok jarvis', 'ок джарвис',
  ];

  VoiceService({required this.groqApiKey});

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _tts.setLanguage('ru-RU');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(0.9);
    _tts.setCompletionHandler(() {
      _setState(VoiceState.wakeListening);
      _scheduleWakeWordCheck();
    });
    _isInitialized = true;
    debugPrint('[Voice] Initialized');
  }

  // ─── Wake Word через периодическую запись + Whisper ───────────────────────

  void startWakeWordDetection() {
    if (_state != VoiceState.idle) return;
    _setState(VoiceState.wakeListening);
    _scheduleWakeWordCheck();
  }

  void stopWakeWordDetection() {
    _wakeWordTimer?.cancel();
    _recorder.stop();
    _setState(VoiceState.idle);
  }

  void _scheduleWakeWordCheck() {
    _wakeWordTimer?.cancel();
    // Каждые 3 сек записываем 2.5 сек и проверяем wake word
    _wakeWordTimer = Timer(const Duration(seconds: 1), () async {
      if (_state == VoiceState.wakeListening) {
        await _checkForWakeWord();
      }
    });
  }

  Future<void> _checkForWakeWord() async {
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/wake_check.m4a';

      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000),
        path: path,
      );
      await Future.delayed(const Duration(milliseconds: 2500));
      await _recorder.stop();

      if (_state != VoiceState.wakeListening) return;

      // Быстрая транскрипция
      final text = await _transcribeWithGroq(path);
      debugPrint('[Voice] Wake check: $text');

      final lower = text.toLowerCase();
      if (_wakeWords.any((w) => lower.contains(w))) {
        await _onWakeWordDetected();
      } else {
        _scheduleWakeWordCheck();
      }
    } catch (e) {
      debugPrint('[Voice] Wake check error: $e');
      _scheduleWakeWordCheck();
    }
  }

  Future<void> _onWakeWordDetected() async {
    debugPrint('[Voice] Wake word detected!');
    _setState(VoiceState.listening);
    await _tts.speak('Слушаю');
    await Future.delayed(const Duration(milliseconds: 1000));
    await _startCommandRecording();
  }

  // ─── Запись команды ───────────────────────────────────────────────────────

  Future<void> _startCommandRecording() async {
    _transcript = '';
    _response = '';
    notifyListeners();

    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/jarvis_cmd.m4a';

      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000),
        path: path,
      );
      await Future.delayed(const Duration(seconds: 5));
      await _recorder.stop();

      _setState(VoiceState.processing);
      await _processCommand(path);
    } catch (e) {
      debugPrint('[Voice] Command recording error: $e');
      _setState(VoiceState.wakeListening);
      _scheduleWakeWordCheck();
    }
  }

  Future<void> _processCommand(String path) async {
    try {
      final transcript = await _transcribeWithGroq(path);
      if (transcript.isEmpty) {
        await _tts.speak('Не расслышал');
        _setState(VoiceState.wakeListening);
        _scheduleWakeWordCheck();
        return;
      }

      _transcript = transcript;
      notifyListeners();

      final answer = await _getGroqResponse(transcript);
      _response = answer;
      notifyListeners();

      _setState(VoiceState.speaking);
      await _tts.speak(answer);
    } catch (e) {
      debugPrint('[Voice] Process error: $e');
      await _tts.speak('Ошибка');
      _setState(VoiceState.wakeListening);
      _scheduleWakeWordCheck();
    }
  }

  // ─── Ручной запуск (нажатие на сферу) ────────────────────────────────────

  Future<void> startManualListening() async {
    if (_state == VoiceState.processing || _state == VoiceState.speaking) return;
    _wakeWordTimer?.cancel();
    await _recorder.stop();
    _setState(VoiceState.listening);
    await _startCommandRecording();
  }

  // ─── Groq Whisper ─────────────────────────────────────────────────────────

  Future<String> _transcribeWithGroq(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return '';

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions'),
    );
    request.headers['Authorization'] = 'Bearer $groqApiKey';
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    request.fields['model'] = 'whisper-large-v3';
    request.fields['response_format'] = 'text';

    final streamed = await request.send().timeout(const Duration(seconds: 10));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) return response.body.trim();
    debugPrint('[Voice] Whisper error: ${response.body}');
    return '';
  }

  // ─── Groq LLaMA ──────────────────────────────────────────────────────────

  Future<String> _getGroqResponse(String userText) async {
    final response = await http.post(
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $groqApiKey',
      },
      body: jsonEncode({
        'model': 'llama-3.3-70b-versatile',
        'messages': [
          {'role': 'system', 'content': _systemPrompt},
          {'role': 'user', 'content': userText},
        ],
        'temperature': 0.7,
        'max_tokens': 300,
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['choices'][0]['message']['content'] as String;
    }
    throw Exception('LLaMA error: ${response.statusCode}');
  }

  void _setState(VoiceState s) {
    _state = s;
    notifyListeners();
  }

  void clearConversation() {
    _transcript = '';
    _response = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _wakeWordTimer?.cancel();
    _recorder.dispose();
    _tts.stop();
    super.dispose();
  }
}
