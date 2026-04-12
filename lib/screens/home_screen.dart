import 'package:flutter/material.dart';
import 'package:neo_genesis/widgets/neomorphic_sphere.dart';
import 'package:neo_genesis/services/app_state.dart';
import 'package:neo_genesis/services/voice_service.dart';
import 'package:neo_genesis/services/screen_vision_service.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final voice = context.watch<VoiceService>();
    final vision = context.watch<ScreenVisionService>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text('NEO-GENESIS',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              const SizedBox(height: 4),
              Text('Jarvis AI Interface • Groq Vision • Deep Accessibility',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),

              const SizedBox(height: 20),

              // Сфера — нажать для голоса
              SizedBox(
                height: 160,
                child: Center(
                  child: GestureDetector(
                    onTap: state.isConnected ? () => voice.startManualListening() : null,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (voice.state == VoiceState.listening)
                          _pulseRing(Colors.cyanAccent),
                        if (vision.state == VisionState.analyzing)
                          _pulseRing(Colors.purpleAccent),
                        AspectRatio(
                          aspectRatio: 1,
                          child: NeomorphicSphere(
                            active: state.isConnected,
                            label: _sphereLabel(state, voice, vision),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Инфо карточки
              if (state.isConnected) ...[
                if (voice.transcript.isNotEmpty)
                  _infoCard(Icons.mic, Colors.cyanAccent, voice.transcript),
                if (voice.response.isNotEmpty)
                  _infoCard(Icons.smart_toy_outlined, Colors.greenAccent, voice.response),
                if (vision.lastAnalysis.isNotEmpty)
                  _infoCard(Icons.remove_red_eye, Colors.purpleAccent, vision.lastAnalysis),
                if (voice.state == VoiceState.idle && voice.transcript.isEmpty && vision.lastAnalysis.isEmpty)
                  Center(
                    child: Text('Скажи "Jarvis" или нажми на сферу',
                        style: const TextStyle(color: Colors.white38, fontSize: 13)),
                  ),
              ],

              const Spacer(),

              // Ошибка
              if (state.errorMessage != null)
                _errorBanner(state),

              // CONNECT кнопка
              ElevatedButton(
                onPressed: state.isLoading ? null : () => state.toggleConnection(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: state.isConnected ? const Color(0xFF1A3A2A) : const Color(0xFF2E3A4D),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                ),
                child: state.isLoading
                    ? const SizedBox(height: 22, width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(state.isConnected ? 'DISCONNECT' : 'CONNECT',
                        style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1.5,
                          color: state.isConnected ? Colors.greenAccent : Colors.white)),
              ),

              const SizedBox(height: 12),

              // Feature кнопки
              Row(
                children: [
                  Expanded(
                    child: _featureButton(
                      icon: Icons.remove_red_eye_outlined,
                      label: vision.state == VisionState.idle ? 'Live Vision' : 'Vision ON',
                      color: vision.state != VisionState.idle ? Colors.purpleAccent : Colors.white54,
                      onTap: state.isConnected
                          ? () {
                              if (vision.state == VisionState.idle) {
                                vision.startVision();
                              } else {
                                vision.stopVision();
                              }
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _featureButton(
                      icon: Icons.accessibility_new,
                      label: 'Accessibility',
                      color: Colors.white54,
                      onTap: null, // следующий шаг
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _sphereLabel(AppState s, VoiceService v, ScreenVisionService vis) {
    if (!s.isConnected) return s.statusLabel;
    if (v.state == VoiceState.listening) return 'LISTENING';
    if (v.state == VoiceState.processing) return 'THINKING';
    if (v.state == VoiceState.speaking) return 'SPEAKING';
    if (vis.state == VisionState.analyzing) return 'ANALYZING';
    return 'ACTIVE';
  }

  Widget _pulseRing(Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: 1.35),
      duration: const Duration(milliseconds: 700),
      builder: (_, v, child) => Transform.scale(scale: v, child: child),
      child: Container(
        width: 150, height: 150,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.12)),
      ),
    );
  }

  Widget _infoCard(IconData icon, Color color, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111924),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 13))),
      ]),
    );
  }

  Widget _errorBanner(AppState state) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: const Color(0xFF2A0E0E), borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(state.errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
        GestureDetector(onTap: state.clearError, child: const Icon(Icons.close, color: Colors.redAccent, size: 16)),
      ]),
    );
  }

  Widget _featureButton({required IconData icon, required String label, required Color color, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF111924),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
