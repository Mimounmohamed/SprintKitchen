import 'package:flutter/material.dart';

/// Central color palette for the SprintKitchen Hub screen.
/// Matches the Figma design swatches (Tailwind Stone + Yellow-400,
/// plus one custom brand brown).
class AppColors {
  AppColors._();

  static const Color background = Color(0xFFF5F5F4); // stone-100
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE7E5E4); // stone-200

  static const Color textPrimary = Color(0xFF292524); // stone-800
  static const Color textSecondary = Color(0xFF44403C); // stone-700
  static const Color textMuted = Color(0xFF78716C); // stone-500

  static const Color brandDark = Color(0xFF583926); // logo box / dark buttons — brand brown
  static const Color brandDarkHover = Color(0xFF6B4530); // lighter brown hover

  static const Color gold = Color(0xFFFACC15); // primary accent — yellow-400
  static const Color goldLight = Color(0xFFFDE047); // lighter selected-border glow — yellow-300
  static const Color goldSoft = Color(0xFFFCEFC9); // badge background

  static const Color success = Color(0xFF059669); // emerald-600
  static const Color successSoft = Color(0xFFECFDF5); // emerald-50 light fill
  static const Color danger = Color(0xFFD9534F);
  static const Color dangerSoft = Color(0xFFFBEAEA);

  // --- POS / Caisse screen ---
  static const Color menuTile = Color(0xFF583926); // brown product card — custom brand brown
  static const Color menuTileDisabled = Color(0xFFD6D3D1); // stone-300
  static const Color menuTilePrice = Color(0xFFFACC15); // gold price text — yellow-400

  static const Color sidebarActiveBg = Color(0xFFFCEFC9);
  static const Color sidebarActiveText = Color(0xFF292524); // stone-800

  static const Color ticketHighlight = Color(0xFFFCF3D9); // active line item

  static const Color dineIn = Color(0xFFE24C4C); // "Sur Place"
  static const Color takeaway = Color(0xFF3E7BFA); // "Emporter"
  static const Color delivery = Color(0xFF17A2A2); // "Livraison"

  static const Color actionOrange = Color(0xFFFACC15); // "Actions" button — yellow-400
}