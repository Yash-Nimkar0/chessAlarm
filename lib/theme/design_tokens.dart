import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTokens {
  // Colors
  static const Color nightBg = Color(0xFF0F1229);
  static const Color dawnStart = Color(0xFF2D1B4E);
  static const Color dawnEnd = Color(0xFFFF8F5E);
  static const Color daylightBg = Color(0xFFFFF8EE);
  
  static const Color signal = Color(0xFFFFB84D);
  static const Color signalDeep = Color(0xFF6A2B45);

  // Typography
  static TextStyle get display => GoogleFonts.spaceGrotesk();
  static TextStyle get body => GoogleFonts.inter();
  
  static TextTheme textTheme(TextTheme base) {
    return GoogleFonts.interTextTheme(base).copyWith(
      displayLarge: GoogleFonts.spaceGrotesk(textStyle: base.displayLarge),
      displayMedium: GoogleFonts.spaceGrotesk(textStyle: base.displayMedium),
      displaySmall: GoogleFonts.spaceGrotesk(textStyle: base.displaySmall),
      headlineLarge: GoogleFonts.spaceGrotesk(textStyle: base.headlineLarge),
      headlineMedium: GoogleFonts.spaceGrotesk(textStyle: base.headlineMedium),
      headlineSmall: GoogleFonts.spaceGrotesk(textStyle: base.headlineSmall),
    );
  }
}
