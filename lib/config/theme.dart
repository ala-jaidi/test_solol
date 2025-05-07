import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      primarySwatch: Colors.blue,
      scaffoldBackgroundColor: Colors.grey[50],
      appBarTheme: const AppBarTheme(color: Colors.blueAccent),
      buttonTheme: const ButtonThemeData(buttonColor: Colors.blueAccent),
    );
  }
}
