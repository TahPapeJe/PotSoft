import 'package:flutter/material.dart';

final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.teal,
    brightness: Brightness.dark,
  ).copyWith(surface: const Color(0xFF1E1E1E), onSurface: Colors.white),
  scaffoldBackgroundColor: const Color(0xFF121212),
  fontFamily: 'Roboto',
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1E1E1E),
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
  ),
  chipTheme: ChipThemeData(
    labelStyle: const TextStyle(fontFamily: 'Roboto'),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
  ),
);
