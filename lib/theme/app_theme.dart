import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFFFFB300);
  static const Color primaryDark = Color(0xFFFF8F00);
  static const Color danger = Color(0xFFFF4757);
  static const Color success = Color(0xFF2ED573);

  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        primaryColor: primary,
        scaffoldBackgroundColor: const Color(0xFF0F0F23),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(
                horizontal: 48, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
}