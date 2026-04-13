import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:neo_genesis/services/groq_service.dart';
import 'package:neo_genesis/services/remote_api.dart';

class AppState extends ChangeNotifier {
  bool isConnected = false;
  bool isLoading = false;
  String statusLabel = 'STANDBY';
  String? errorMessage;

  String? _authToken;
  String? _telegramId;
  bool get isAuthenticated => _authToken != null;

  late final GroqService _groq;
  late final RemoteApi _api;
  Timer? _heartbeatTimer;

  // MethodChannel для управления foreground service из Dart
  static const _serviceChannel = MethodChannel('neo_genesis/service');

  AppState() {
    _groq = GroqService(
      apiKey: dotenv.env['GROQ_API_KEY'] ?? '',
      endpoint: dotenv.env['GROQ_ENDPOINT'] ??
          'https://api.groq.com/openai/v1/chat/completions',
    );
    _api = RemoteApi(
      baseUrl: dotenv.env['REMOTE_BASE_URL'] ?? '',
    );
  }

  // ─── Авторизация через бота ───────────────────────────────────────────────

  Future<Map<String, dynamic>> requestAuthCode() => _api.requestCode();

  Future<Map<String, dynamic>> checkAuthStatus(String sessionId) =>
      _api.checkAuthStatus(sessionId);

  void setAuthFromBot(String token, String telegramId) {
    _authToken = token;
    _telegramId = telegramId;
    notifyListeners();
  }

  // ─── Foreground Service ───────────────────────────────────────────────────

  Future<void> _startForegroundService() async {
    try {
      await _serviceChannel.invokeMethod('startService');
    } catch (e) {
      debugPrint('[AppState] Could not start foreground service: $e');
    }
  }

  Future<void> _stopForegroundService() async {
    try {
      await _serviceChannel.invokeMethod('stopService');
    } catch (e) {
      debugPrint('[AppState] Could not stop foreground service: $e');
    }
  }

  // ─── Подключение / отключение ─────────────────────────────────────────────

  Future<void> toggleConnection() async {
    isConnected ? _disconnect() : await _connect();
  }

  Future<void> _connect() async {
    isLoading = true;
    statusLabel = 'CONNECTING...';
    errorMessage = null;
    notifyListeners();

    try {
      await _groq.chatResponse('ping');

      await _api.sendHeartBeat(_telegramId ?? 'unknown', {
        'event': 'connect',
        'telegramId': _telegramId,
        'timestamp': DateTime.now().toIso8601String(),
      });

      isConnected = true;
      statusLabel = 'ACTIVE';

      // Запускаем foreground service — теперь слушает даже в фоне
      await _startForegroundService();

      _heartbeatTimer =
          Timer.periodic(const Duration(seconds: 30), (_) {
        _api.sendHeartBeat(_telegramId ?? 'unknown', {
          'event': 'heartbeat',
          'telegramId': _telegramId,
          'timestamp': DateTime.now().toIso8601String(),
        }).catchError((_) {});
      });
    } catch (e) {
      errorMessage =
          'Ошибка подключения: ${e.toString().replaceFirst("Exception: ", "")}';
      statusLabel = 'ERROR';
      isConnected = false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _disconnect() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    isConnected = false;
    statusLabel = 'STANDBY';
    errorMessage = null;
    _stopForegroundService();
    notifyListeners();
  }

  Future<String> askGroq(String prompt) => _groq.chatResponse(prompt);

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }
}
