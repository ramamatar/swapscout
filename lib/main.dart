import 'package:flutter/material.dart';
import 'pages/welcome.dart';

void main() {
  runApp(const HomeSwapApp());
}

class HomeSwapApp extends StatelessWidget {
  const HomeSwapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SwapScout',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFFF28C64),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF28C64),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F7F7),
        useMaterial3: true,
      ),
      home: const WelcomePage(),
    );
  }
}
