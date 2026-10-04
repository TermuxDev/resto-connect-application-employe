/// Couleurs et styles : les mêmes que le front Gérant (SERVEUR/static/commun/style.css).
library;

import 'package:flutter/material.dart';

abstract final class Couleurs {
  static const fond = Color(0xFFF5F6F7);
  static const carte = Colors.white;
  static const texte = Color(0xFF14181F);
  static const discret = Color(0xFF8A919C);
  static const bordure = Color(0xFFE6E8EB);
  static const vertFonce = Color(0xFF0F3D27);
  static const vert = Color(0xFF1D6B45);
  static const vertMoyen = Color(0xFF2F8F5B);
  static const vertClair = Color(0xFF7FD1A3);
  static const vertPale = Color(0xFFE7F5EC);
  static const alerte = Color(0xFFB7791F);
  static const alertePale = Color(0xFFFFF4DF);
  static const danger = Color(0xFFC53030);
  static const dangerFonce = Color(0xFF8E1F1F);

  static const degrade = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2A8456), vertFonce],
  );
}

ThemeData themeResto() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Couleurs.vert,
      primary: Couleurs.vert,
      surface: Couleurs.fond,
    ),
    scaffoldBackgroundColor: Couleurs.fond,
  );
  const pilule = StadiumBorder();
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: Couleurs.texte,
      displayColor: Couleurs.texte,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Couleurs.vert,
        minimumSize: const Size.fromHeight(56),
        shape: pilule,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Couleurs.vertFonce,
        minimumSize: const Size.fromHeight(56),
        shape: pilule,
        side: const BorderSide(color: Couleurs.vertFonce),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Couleurs.carte,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Couleurs.bordure),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Couleurs.bordure),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Couleurs.vert, width: 2),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Couleurs.vertFonce,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
