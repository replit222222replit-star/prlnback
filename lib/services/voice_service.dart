import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

enum VoiceState { idle, listening, processing, speaking }

class VoiceService extends ChangeNotifier {
  final String groqApiKey;

  final stt.SpeechToText _speech = stt.SpeechToText();
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

  // Системный промпт для Jarvis
  static const String _systemPrompt = '''
Ты — Jarvis, интеллектуальный голосовой ассистент встроенный в Android телефон.
Ты умный, краткий и полезный. Отвечай на том же языке на котором тебя спросили.
Отвечай коротко — максимум 2-3 предложения если не просят подробностей.
Ты можешь управлять телефоном через команды.
''';

  VoiceService({required this.groqApiKey});

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Инициализация STT
    await _speech.initialize(
      onError: (e) => debugPrint('[Voice] STT error: $e'),
    );

    // Настройка TTS
    await _tts.setLanguage('ru-RU');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(0.9);

    _tts.setCompletionHandler(() {
      _setState(VoiceState.idle);
      // После ответа снова слушаем wake word
      _startWakeWordListening();
    });

    _isInitialized = true;
    debugPrint('[Voice] Initialized');
  }

  // ─── Wake Word ────────────────────────────────────────────────────────────

  void startWakeWordDetection() {
    if (!_isInitialized) return;
    _startWakeWordListening();
  }

  void stopWakeWordDetection() {
    _wakeWordTimer?.cancel();
    _speech.stop();
    _setState(VoiceState.idle);
  }

  void _startWakeWordListening() {
    if (_state != VoiceState.idle) return;

    _speech.listen(
      onResult: (result) {
        final text = result.recognizedWords.toLowerCase();
        debugPrint('[Voice] Heard: $text');

        // Wake words на разных языках
        final wakeWords = [
          'jarvis', 'джарвис', 'джервис', 'эй джарвис', 'hey jarvis'
        ];

        if (wakeWords.any((w) => text.contains(w))) {
          _speech.stop();
          _onWakeWordDetected();
        }
      },
      listenMode: stt.ListenMode.confirmation,
      cancelOnError: false,
      partialResults: true,
      localeId: 'ru_RU',
    );

    // Перезапускаем слушание каждые 10 сек (STT имеет таймаут)
    _wakeWordTimer?.cancel();
    _wakeWordTimer = Timer(const Duration(seconds: 10), () {
      if (_state == VoiceState.idle) {
        _speech.stop();
        _startWakeWordListening();
      }
    });
  }

  void _onWakeWordDetected() async {
    debugPrint('[Voice] Wake word detected!');
    await _tts.speak('Слушаю');
    await Future.delayed(const Duration(milliseconds: 800));
    await _startRecording();
  }

  // ─── Запись голоса ────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    _setState(VoiceState.listening);
    _transcript = '';
    _response = '';
    notifyListeners();

    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/jarvis_input.m4a';

      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000),
        path: path,
      );

      // Записываем 5 секунд
      await Future.delayed(const Duration(seconds: 5));
      await _stopRecordingAndProcess(path);
    } catch (e) {
      debugPrint('[Voice] Recording error: $e');
      _setState(VoiceState.idle);
      _startWakeWordListening();
    }
  }

  Future<void> _stopRecordingAndProcess(String path) async {
    await _recorder.stop();
    _setState(VoiceState.processing);
    notifyListeners();

    try {
      // Groq Whisper — распознавание речи
      final transcript = await _transcribeWithGroq(path);
      if (transcript.isEmpty) {
        await _tts.speak('Не расслышал, попробуй ещё раз');
        _setState(VoiceState.idle);
        _startWakeWordListening();
        return;
      }

      _transcript = transcript;
      notifyListeners();
      debugPrint('[Voice] Transcript: $transcript');

      // Groq LLaMA — генерация ответа
      final answer = await _getGroqResponse(transcript);
      _response = answer;
      notifyListeners();

      // TTS — озвучка
      _setState(VoiceState.speaking);
      await _tts.speak(answer);
    } catch (e) {
      debugPrint('[Voice] Processing error: $e');
      await _tts.speak('Произошла ошибка');
      _setState(VoiceState.idle);
      _startWakeWordListening();
    }
  }

  // ─── Groq Whisper STT ─────────────────────────────────────────────────────

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

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      return response.body.trim();
    } else {
      debugPrint('[Voice] Whisper error: ${response.body}');
      return '';
    }
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
    } else {
      throw Exception('LLaMA error: ${response.statusCode}');
    }
  }

  // ─── Ручной запуск (кнопка) ──────────────────────────────────────────────

  Future<void> startManualListening() async {
    if (_state != VoiceState.idle) return;
    _wakeWordTimer?.cancel();
    _speech.stop();
    await _startRecording();
  }

  void _setState(VoiceState s) {
    _state = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _wakeWordTimer?.cancel();
    _speech.stop();
    _recorder.dispose();
    _tts.stop();
    super.dispose();
  }
}
