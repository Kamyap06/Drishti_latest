import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Pro Color Palette
  static const Color darkBackground = Color(0xFF121212);
  static const Color cardColor = Color(0xFF1E1E1E);
  static const Color primaryAccent = Color(0xFF00E5FF); // Cyan
  static const Color secondaryAccent = Color(0xFFD500F9); // Purple
  static const Color errorColor = Color(0xFFFF5252); // Red
  static const Color successColor = Color(0xFF00E676); // Green

  static final ThemeData pTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBackground,
    primaryColor: primaryAccent,
    visualDensity: VisualDensity.adaptivePlatformDensity,

    // Modern Google Fonts
    textTheme: TextTheme(
      headlineLarge: GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        letterSpacing: 1.0,
      ),
      headlineMedium: GoogleFonts.outfit(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: Colors.white.withOpacity(0.9),
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 18,
        color: Colors.white.withOpacity(0.9),
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 16,
        color: Colors.white.withOpacity(0.7),
      ),
      labelLarge: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
    ),

    // cardTheme: Removed to resolve type error
    // cardTheme: CardTheme(
    //   color: cardColor,
    //   elevation: 4,
    //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    // ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryAccent,
        foregroundColor: Colors.black,
        elevation: 6,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        shadowColor: primaryAccent.withOpacity(0.4),
      ),
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: darkBackground,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    ),

    iconTheme: const IconThemeData(color: primaryAccent, size: 28),
  );
}
