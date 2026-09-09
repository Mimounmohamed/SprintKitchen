import 'package:flutter/material.dart';

/// Central color palette for the SprintKitchen Hub screen.
/// Pulled to match the reference design (dark brown / gold / cream).
class AppColors {
  AppColors._();

  static const Color background = Color(0xFFF6F5F2);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE7E4DE);

  static const Color textPrimary = Color(0xFF231A12);
  static const Color textSecondary = Color(0xFF8B8579);
  static const Color textMuted = Color(0xFFB0AB9E);

  static const Color brandDark = Color(0xFF241811); // logo box / dark buttons
  static const Color brandDarkHover = Color(0xFF32241A);

  static const Color gold = Color(0xFFEFAF1D); // primary accent
  static const Color goldSoft = Color(0xFFFCEFC9); // badge background

  static const Color success = Color(0xFF3FB56D);
  static const Color danger = Color(0xFFD9534F);
  static const Color dangerSoft = Color(0xFFFBEAEA);
}