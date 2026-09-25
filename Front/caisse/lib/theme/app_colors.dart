import 'package:flutter/material.dart';

/// Central color palette for the SprintKitchen Hub screen.
/// Matches the Figma design swatches (Tailwind Stone + Yellow-400,
/// plus one custom brand brown).
class AppColors {
  AppColors._();

  // --- Exact Admin Palette (SprintKitchen Admin Hub) ---
  static const Color background = Color(0xFFF5F4F0); // C.bg
  static const Color surface = Colors.white;         // C.cardBg
  static const Color border = Color(0xFFE7E4DD);     // C.border
  static const Color ink = Color(0xFF1C1917);        // C.ink
  static const Color brown = Color(0xFF583926);      // C.brown (lighter menu brown)
  static const Color gold = Color(0xFFF2B705);       // C.yellow
  static const Color muted = Color(0xFF8B8378);      // C.muted
  static const Color green = Color(0xFF2FAE5C);      // C.green
  static const Color red = Color(0xFFE0533D);        // C.red
  static const Color redBg = Color(0xFFFBEAE7);      // C.redBg
  static const Color yellowBg = Color(0xFFFCEFCB);   // C.yellowBg
  static const Color blueBg = Color(0xFFEDEBFB);     // C.blueBg
  static const Color blue = Color(0xFF6C63D6);       // C.blue
  static const Color ctaDark = Color(0xFF583926);    // C.ctaDark
  static const Color orange = Color(0xFFD9720C);
  static const Color orangeBg = Color(0xFFFEF3E2);

  // --- Backwards-compatible aliases ---
  static const Color textPrimary = ink;
  static const Color textSecondary = brown;
  static const Color textMuted = muted;

  static const Color brandDark = brown;
  static const Color brandDarkHover = Color(0xFF452B1E);

  static const Color goldLight = Color(0xFFFDE047);
  static const Color goldSoft = yellowBg;

  static const Color success = green;
  static const Color successSoft = Color(0xFFECFDF5);
  static const Color danger = red;
  static const Color dangerSoft = redBg;

  // --- POS / Caisse screen ---
  static const Color menuTile = Color(0xFF583926);
  static const Color menuTileDisabled = Color(0xFFD6D3D1);
  static const Color menuTilePrice = gold;

  static const Color sidebarActiveBg = yellowBg;
  static const Color sidebarActiveText = ink;

  static const Color ticketHighlight = Color(0xFFFCF3D9);

  static const Color dineIn = Color(0xFFE24C4C);
  static const Color takeaway = Color(0xFF3E7BFA);
  static const Color delivery = Color(0xFF17A2A2);

  static const Color actionOrange = gold;
}