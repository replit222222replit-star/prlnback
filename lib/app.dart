import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:neo_genesis/screens/home_screen.dart';
import 'package:neo_genesis/screens/auth_screen.dart';
import 'package:neo_genesis/services/app_state.dart';

class NeoGenesisApp extends StatelessWidget {
  const NeoGenesisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
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

/// Роутер: если авторизован — HomeScreen, иначе — AuthScreen
class _RootScreen extends StatelessWidget {
  const _RootScreen();

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = context.select<AppState, bool>(
      (s) => s.isAuthenticated,
    );
    return isAuthenticated ? const HomeScreen() : const AuthScreen();
  }
}
