import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:neo_genesis/services/app_state.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // Состояния экрана
  String _step = 'initial'; // initial | waiting | expired | error
  String? _code;
  String? _sessionId;
  String? _errorMsg;
  bool _isLoading = false;

  Timer? _pollTimer;
  int _secondsLeft = 300; // 5 минут
  Timer? _countdownTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // Запросить код
  Future<void> _requestCode() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final state = context.read<AppState>();
      final result = await state.requestAuthCode();

      setState(() {
        _code = result['code'] as String;
        _sessionId = result['sessionId'] as String;
        _step = 'waiting';
        _secondsLeft = 300;
        _isLoading = false;
      });

      _startPolling();
      _startCountdown();
    } catch (e) {
      setState(() {
        _errorMsg = 'Сервер недоступен. Проверь REMOTE_BASE_URL.';
        _step = 'error';
        _isLoading = false;
      });
    }
  }

  // Поллинг каждые 2 сек
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_sessionId == null) return;
      try {
        final state = context.read<AppState>();
        final result = await state.checkAuthStatus(_sessionId!);
        final status = result['status'] as String?;

        if (status == 'authenticated') {
          _pollTimer?.cancel();
          _countdownTimer?.cancel();
          state.setAuthFromBot(
            result['token'] as String,
            result['telegramId'] as String,
          );
        } else if (status == 'expired') {
          _pollTimer?.cancel();
          _countdownTimer?.cancel();
          setState(() => _step = 'expired');
        }
      } catch (_) {
        // тихий фэйл — продолжаем поллить
      }
    });
  }

  // Обратный отсчёт
  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft <= 0) {
        _countdownTimer?.cancel();
        _pollTimer?.cancel();
        setState(() => _step = 'expired');
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  // Открыть бота в Telegram
  Future<void> _openBot() async {
    final botUsername = dotenv.env['BOT_USERNAME'] ?? '';
    final uri = Uri.parse('https://t.me/$botUsername');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // Скопировать команду
  void _copyCommand() {
    Clipboard.setData(ClipboardData(text: '/auth $_code'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Команда скопирована!'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF1A78C2),
      ),
    );
  }

  String get _timeStr {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B10),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              // Заголовок
              Text(
                'NEO-GENESIS',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Telegram Authorization',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.lightBlueAccent,
                      letterSpacing: 1.2,
                    ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),

              // Контент в зависимости от шага
              if (_step == 'initial') _buildInitial(),
              if (_step == 'waiting') _buildWaiting(),
              if (_step == 'expired') _buildExpired(),
              if (_step == 'error') _buildError(),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Начальный экран ──────────────────────────────────────────────────────

  Widget _buildInitial() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF111924),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          const Icon(Icons.lock_outline, color: Colors.lightBlueAccent, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Нажми кнопку — получишь одноразовый код.\nОтправь его боту в Telegram.',
            style: TextStyle(color: Colors.white70, height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _requestCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A78C2),
              padding: const EdgeInsets.symmetric(vertical: 18),
              minimumSize: const Size(double.infinity, 0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Получить код',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1)),
          ),
        ],
      ),
    );
  }

  // ─── Ожидание подтверждения ───────────────────────────────────────────────

  Widget _buildWaiting() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF111924),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          // Код
          Text(
            _code ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.w900,
              letterSpacing: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Истекает через $_timeStr',
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 20),
          const Text(
            'Открой бота и отправь команду:',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),

          // Команда для бота
          GestureDetector(
            onTap: _copyCommand,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1620),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '/auth $_code',
                    style: const TextStyle(
                      color: Colors.lightBlueAccent,
                      fontSize: 18,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.copy, color: Colors.white38, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Кнопка открыть бота
          ElevatedButton.icon(
            onPressed: _openBot,
            icon: const Icon(Icons.telegram, size: 20),
            label: const Text('Открыть бота',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A78C2),
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size(double.infinity, 0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 16),

          // Спиннер ожидания
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 14,
                width: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: Colors.white38),
              ),
              SizedBox(width: 10),
              Text('Ожидаю подтверждения...',
                  style: TextStyle(color: Colors.white38, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Код истёк ────────────────────────────────────────────────────────────

  Widget _buildExpired() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF111924),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          const Icon(Icons.timer_off_outlined,
              color: Colors.orangeAccent, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Код истёк.\nЗапроси новый.',
            style: TextStyle(color: Colors.white70, height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() => _step = 'initial');
              _requestCode();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A78C2),
              padding: const EdgeInsets.symmetric(vertical: 18),
              minimumSize: const Size(double.infinity, 0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Новый код',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ─── Ошибка сервера ───────────────────────────────────────────────────────

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0E0E),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 16),
          Text(
            _errorMsg ?? 'Неизвестная ошибка',
            style: const TextStyle(color: Colors.redAccent, height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() => _step = 'initial');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E3A4D),
              padding: const EdgeInsets.symmetric(vertical: 18),
              minimumSize: const Size(double.infinity, 0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Попробовать снова',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
