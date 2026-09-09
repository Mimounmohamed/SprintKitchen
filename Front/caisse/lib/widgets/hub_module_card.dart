import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A single module card on the Hub screen (e.g. "New Order / Register",
/// "Order History", "Stock & Inventory").
class HubModuleCard extends StatelessWidget {
  const HubModuleCard({
    super.key,
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.buttonLabel,
    required this.onTap,
    this.badgeText,
    this.badgeColor,
    this.badgeTextColor,
    this.highlighted = false,
    this.buttonStyleFilled = true,
  });

  /// Icon shown top-left in the dark rounded square.
  final IconData icon;

  /// Small uppercase label above the title, e.g. "SAISIE & ENCAISSEMENT".
  final String eyebrow;

  /// Card title, e.g. "New Order / Register".
  final String title;

  /// Label for the call-to-action button.
  final String buttonLabel;

  final VoidCallback onTap;

  /// Optional pill badge shown top-right (e.g. "142 TICKETS AUJOURD'HUI").
  final String? badgeText;
  final Color? badgeColor;
  final Color? badgeTextColor;

  /// If true, draws the gold top border + "MODULE PRINCIPAL" style emphasis.
  final bool highlighted;

  /// If true, button is solid (dark/gold). If false, button is outlined/light.
  final bool buttonStyleFilled;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top accent bar for the highlighted / primary module.
          if (highlighted)
            Container(height: 4, color: AppColors.gold),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.brandDark,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: AppColors.gold, size: 22),
                    ),
                    if (badgeText != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor ?? AppColors.goldSoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badgeText!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: badgeTextColor ?? AppColors.textPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  eyebrow.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: buttonStyleFilled
                      ? ElevatedButton(
                          onPressed: onTap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: highlighted
                                ? AppColors.gold
                                : AppColors.brandDark,
                            foregroundColor: highlighted
                                ? AppColors.brandDark
                                : Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                buttonLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward, size: 16),
                            ],
                          ),
                        )
                      : OutlinedButton(
                          onPressed: onTap,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.border),
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                buttonLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right, size: 18),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}