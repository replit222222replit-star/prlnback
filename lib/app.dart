import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:neo_genesis/screens/home_screen.dart';
import 'package:neo_genesis/screens/auth_screen.dart';
import 'package:neo_genesis/services/app_state.dart';
import 'package:neo_genesis/services/voice_service.dart';
import 'package:neo_genesis/services/screen_vision_service.dart';

class NeoGenesisApp extends StatelessWidget {
  const NeoGenesisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(
          create: (_) => VoiceService(groqApiKey: dotenv.env['GROQ_API_KEY'] ?? ''),
        ),
        ChangeNotifierProvider(
          create: (_) => ScreenVisionService(groqApiKey: dotenv.env['GROQ_API_KEY'] ?? ''),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'NEO-GENESIS',
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF070B10),
          canvasColor: const Color(0xFF09141E),
          textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'RobotoMono'),
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
    _init();
  }

  Future<void> _init() async {
    await [Permission.microphone, Permission.speech].request();
    if (mounted) await context.read<VoiceService>().initialize();
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = context.select<AppState, bool>((s) => s.isAuthenticated);
    final isConnected = context.select<AppState, bool>((s) => s.isConnected);

    if (isAuthenticated && isConnected) {
      context.read<VoiceService>().startWakeWordDetection();
    } else {
      context.read<VoiceService>().stopWakeWordDetection();
      context.read<ScreenVisionService>().stopVision();
    }

    return isAuthenticated ? const HomeScreen() : const AuthScreen();
  }
}
