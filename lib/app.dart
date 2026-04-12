import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:neo_genesis/screens/home_screen.dart';
import 'package:neo_genesis/screens/auth_screen.dart';
import 'package:neo_genesis/services/app_state.dart';
import 'package:neo_genesis/services/voice_service.dart';

class NeoGenesisApp extends StatelessWidget {
  const NeoGenesisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(
          create: (_) => VoiceService(
            groqApiKey: dotenv.env['GROQ_API_KEY'] ?? '',
          ),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'NEO-GENESIS',
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF070B10),
          canvasColor: const Color(0xFF09141E),
          textTheme: ThemeData.dark().textTheme.apply(
                fontFamily: 'RobotoMono',
              ),
        ),
        home: const _RootScreen(),
      ),
    );
  }
}

class _RootScreen extends StatefulWidget {
  const _RootScreen();

  @override
  State<_RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<_RootScreen> {
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [Permission.microphone, Permission.speech].request();
    if (mounted) {
      final voice = context.read<VoiceService>();
      await voice.initialize();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = context.select<AppState, bool>(
      (s) => s.isAuthenticated,
    );

    // Запускаем wake word когда авторизован
    if (isAuthenticated) {
      final voice = context.read<VoiceService>();
      final connected = context.select<AppState, bool>((s) => s.isConnected);
      if (connected) {
        voice.startWakeWordDetection();
      } else {
        voice.stopWakeWordDetection();
      }
    }

    return isAuthenticated ? const HomeScreen() : const AuthScreen();
  }
}
