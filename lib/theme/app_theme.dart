import 'package:flutter/material.dart';

const Color kPrimaryColor = Color(0xFF0d7c66);

final ThemeData appTheme = ThemeData.dark(useMaterial3: true).copyWith(
  scaffoldBackgroundColor: const Color(0xFF0b1e1a), // خلفية عامة داكنة
  primaryColor: kPrimaryColor,
  appBarTheme: const AppBarTheme(
    backgroundColor: kPrimaryColor,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kPrimaryColor,
      foregroundColor: Colors.white,
      textStyle: const TextStyle(fontWeight: FontWeight.bold),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white.withOpacity(0.06),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: kPrimaryColor.withOpacity(.6), width: 1.2),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: kPrimaryColor.withOpacity(.4)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: kPrimaryColor, width: 1.5),
    ),
    labelStyle: const TextStyle(color: Colors.white70),
    hintStyle: const TextStyle(color: Colors.white54),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: MaterialStateProperty.all(kPrimaryColor),
    trackColor: MaterialStateProperty.all(kPrimaryColor.withOpacity(.4)),
  ),
);
