import 'package:flutter/material.dart';

class GlobalMessenger {
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static void showError(String message) {
    if (scaffoldMessengerKey.currentState != null) {
      scaffoldMessengerKey.currentState!.removeCurrentSnackBar();
      scaffoldMessengerKey.currentState!.showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  static void showSuccess(String message) {
    if (scaffoldMessengerKey.currentState != null) {
      scaffoldMessengerKey.currentState!.removeCurrentSnackBar();
      scaffoldMessengerKey.currentState!.showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  static void showInfo(String message) {
    if (scaffoldMessengerKey.currentState != null) {
      scaffoldMessengerKey.currentState!.removeCurrentSnackBar();
      scaffoldMessengerKey.currentState!.showSnackBar(
        SnackBar(
          content: Text(
            message,
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
