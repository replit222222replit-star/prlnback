import 'package:flutter/material.dart';
import 'package:neo_genesis/widgets/neomorphic_sphere.dart';
import 'package:neo_genesis/services/app_state.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

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

              const SizedBox(height: 28),

              // Сфера
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: NeomorphicSphere(
                      active: state.isConnected,
                      label: state.statusLabel,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Сообщение об ошибке
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

              // Кнопка CONNECT / DISCONNECT
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

              const SizedBox(height: 18),

              _buildFeatureCard(
                context,
                'Live Screen Vision',
                'Groq Vision анализирует экран каждые 2 секунды.',
                Icons.remove_red_eye_outlined,
              ),
              const SizedBox(height: 12),
              _buildFeatureCard(
                context,
                'Deep Accessibility Control',
                'Управление UI-элементами через Accessibility Service.',
                Icons.accessibility_new,
              ),
              const SizedBox(height: 12),
              _buildFeatureCard(
                context,
                'Remote Admin Panel',
                'Firebase + Telegram: live spy и shell команды.',
                Icons.admin_panel_settings_outlined,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
      BuildContext context, String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111924),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1AFFFFFF),
              blurRadius: 24,
              offset: Offset(0, 12)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF162032),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.lightBlueAccent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 6),
                Text(subtitle,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
