import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

/// Entry point for the Nexus Finance Host App.
/// Loads a MaterialApp starting at the secure Login screen.
void main() {
  runApp(const NexusHostApp());
}

class NexusHostApp extends StatelessWidget {
  const NexusHostApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nexus Finance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0A2540)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0A0E17),
        cardTheme: const CardThemeData(
          color: Color(0xFF1A1F2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
