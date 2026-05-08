import 'package:flutter/material.dart';
import 'pages/welcome.dart';

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'utils/global_messenger.dart';

void main() {
  runApp(const HomeSwapApp());
}

class HomeSwapApp extends StatefulWidget {
  const HomeSwapApp({super.key});

  @override
  State<HomeSwapApp> createState() => _HomeSwapAppState();
}

class _HomeSwapAppState extends State<HomeSwapApp> {
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.contains(ConnectivityResult.none)) {
        if (!_isOffline) {
          _isOffline = true;
          GlobalMessenger.showError("You are currently offline. Check your connection.");
        }
      } else {
        if (_isOffline) {
          _isOffline = false;
          GlobalMessenger.showSuccess("You are back online!");
        }
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SwapScout',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: GlobalMessenger.scaffoldMessengerKey,
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
