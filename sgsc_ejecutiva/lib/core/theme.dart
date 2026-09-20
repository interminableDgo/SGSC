import 'package:flutter/material.dart';

const brand = Color(0xFFFF8300);
const salud = Color(0xFF12A5E5);
const ink = Color(0xFF1B2A33);
const paper = Color(0xFFF3F3F0);
const border = Color(0xFFE3E3DE);
const muted = Color(0xFF5B6B74);
const blueTint = Color(0xFFE7F6FD);

ThemeData executiveTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'Mulish',
  scaffoldBackgroundColor: paper,
  colorScheme: ColorScheme.fromSeed(
    seedColor: brand,
    primary: brand,
    secondary: salud,
    surface: Colors.white,
  ),
  textTheme: const TextTheme(
    headlineSmall: TextStyle(
      fontSize: 23,
      fontWeight: FontWeight.w800,
      color: ink,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      color: ink,
    ),
    titleMedium: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: ink,
    ),
    bodyMedium: TextStyle(fontSize: 14, color: ink, height: 1.5),
    bodySmall: TextStyle(fontSize: 12, color: muted, height: 1.5),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: salud, width: 2),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: brand,
      foregroundColor: ink,
      minimumSize: const Size(double.infinity, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(
        fontFamily: 'Mulish',
        fontWeight: FontWeight.w800,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: ink,
      minimumSize: const Size(double.infinity, 48),
      side: const BorderSide(color: border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
);
