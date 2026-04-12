import 'package:flutter/material.dart';
import 'package:neo_genesis/widgets/neomorphic_sphere.dart';
import 'package:neo_genesis/services/app_state.dart';
import 'package:neo_genesis/services/voice_service.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final voice = context.watch<VoiceService>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text(
                'NEO-GENESIS',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5),
              ),
              const SizedBox(height: 4),
              Text(
                'Jarvis AI Interface • Groq Vision • Deep Accessibility',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.white70),
              ),

              const SizedBox(height: 20),

              // Сфера
              SizedBox(
                height: 180,
                child: Center(
                  child: GestureDetector(
                    onTap: state.isConnected
                        ? () => voice.startManualListening()
                        : null,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Пульсация когда слушает
                        if (voice.state == VoiceState.listening)
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 1.0, end: 1.3),
                            duration: const Duration(milliseconds: 800),
                            builder: (_, v, child) => Transform.scale(
                              scale: v,
                              child: child,
                            ),
                            child: Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.cyanAccent.withOpacity(0.15),
                              ),
                            ),
                          ),
                        AspectRatio(
                          aspectRatio: 1,
                          child: NeomorphicSphere(
                            active: state.isConnected,
                            label: _getSphereLabel(state, voice),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Транскрипт / ответ
              if (state.isConnected) ...[
                if (voice.transcript.isNotEmpty)
                  _infoCard(
                    icon: Icons.mic,
                    color: Colors.cyanAccent,
                    text: voice.transcript,
                  ),
                if (voice.response.isNotEmpty)
                  _infoCard(
                    icon: Icons.smart_toy_outlined,
                    color: Colors.greenAccent,
                    text: voice.response,
                  ),
                if (voice.state == VoiceState.idle && voice.transcript.isEmpty)
                  Center(
                    child: Text(
                      'Скажи "Jarvis" или нажми на сферу',
                      style: TextStyle(
                          color: Colors.white38,
                          fontSize: 13),
                    ),
                  ),
              ],

              const Spacer(),

              // Ошибка
              if (state.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A0E0E),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.redAccent, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            state.errorMessage!,
                            style: const TextStyle(
                                color: Colors.redAccent, fontSize: 13),
                          ),
                        ),
                        GestureDetector(
                          onTap: state.clearError,
                          child: const Icon(Icons.close,
                              color: Colors.redAccent, size: 16),
                        ),
                      ],
                    ),
                  ),
                ),

              // CONNECT / DISCONNECT
              ElevatedButton(
                onPressed: state.isLoading
                    ? null
                    : () => state.toggleConnection(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: state.isConnected
                      ? const Color(0xFF1A3A2A)
                      : const Color(0xFF2E3A4D),
                  disabledBackgroundColor: const Color(0xFF1E2530),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22)),
                ),
                child: state.isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        state.isConnected ? 'DISCONNECT' : 'CONNECT',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: state.isConnected
                              ? Colors.greenAccent
                              : Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildFeatureCard(
                      context,
                      'Live Vision',
                      'Groq анализирует экран',
                      Icons.remove_red_eye_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildFeatureCard(
                      context,
                      'Accessibility',
                      'Управление UI',
                      Icons.accessibility_new,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getSphereLabel(AppState state, VoiceService voice) {
    if (!state.isConnected) return state.statusLabel;
    switch (voice.state) {
      case VoiceState.listening:
        return 'LISTENING';
      case VoiceState.processing:
        return 'THINKING';
      case VoiceState.speaking:
        return 'SPEAKING';
      case VoiceState.idle:
        return 'ACTIVE';
    }
  }

  Widget _infoCard(
      {required IconData icon,
      required Color color,
      required String text}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111924),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(color: color, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
      BuildContext context, String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111924),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.lightBlueAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 12)),
                Text(subtitle,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
