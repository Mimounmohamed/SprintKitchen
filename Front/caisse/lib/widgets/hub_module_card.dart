import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

enum CtaStyle { primary, secondary, outline }

/// Single bullet in a module checklist.
/// Shows a green checkmark or a red warning triangle if [warn] is true.
class ChecklistItem extends StatelessWidget {
  const ChecklistItem({
    super.key,
    required this.text,
    this.warn = false,
  });

  final String text;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2, right: 8),
          child: Icon(
            warn ? Icons.warning_amber_rounded : Icons.check_rounded,
            size: 14,
            color: warn ? AppColors.red : AppColors.green,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: warn ? FontWeight.w600 : FontWeight.w400,
              color: warn ? const Color(0xFFB23A26) : AppColors.ink,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

/// Pill badge with optional colored status dot (e.g. "MODULE PRINCIPAL", "STOCK").
class HubPill extends StatelessWidget {
  const HubPill({
    super.key,
    required this.text,
    this.dot = false,
    this.dotColor,
    required this.bg,
    required this.color,
    this.small = false,
  });

  final String text;
  final bool dot;
  final Color? dotColor;
  final Color bg;
  final Color color;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 9 : 13,
        vertical: small ? 3 : 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: small ? 5 : 6,
              height: small ? 5 : 6,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: dotColor ?? color,
                shape: BoxShape.circle,
              ),
            ),
          ],
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: small ? 10.5 : 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Desktop KPI card shown on the top-right of the hub header.
class HubKpiCard extends StatelessWidget {
  const HubKpiCard({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    required this.sub,
    this.subColor,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final String sub;
  final Color? subColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AppColors.muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: valueColor ?? AppColors.ink,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: subColor != null ? FontWeight.w700 : FontWeight.w400,
              color: subColor ?? AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact KPI card for mobile 3-column strip.
class HubMobileKpiCard extends StatelessWidget {
  const HubMobileKpiCard({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    required this.sub,
    this.subColor,
    this.icon,
    this.borderColor,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final String sub;
  final Color? subColor;
  final Widget? icon;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor ?? AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppColors.muted,
                ),
              ),
              ?icon,
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: GoogleFonts.bebasNeue(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: valueColor ?? AppColors.ink,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            sub,
            style: GoogleFonts.inter(
              fontSize: 9.5,
              fontWeight: subColor != null ? FontWeight.w700 : FontWeight.w400,
              color: subColor ?? AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Main module card matching SprintKitchen Admin Hub design:
/// - Rounded card (16px), 1px border (#E7E4DD)
/// - Gold top border (3px) + golden glow shadow if [highlight] is true
/// - Squircle icon (42px mobile / 52px desktop) with custom bg & color
/// - Pill badge top-right
/// - Uppercase eyebrow, bold title (20-22px), muted description
/// - Checklist items with green checkmarks or red warning triangles
/// - Bottom CTA button (primary, secondary, or outline)
class HubModuleCard extends StatefulWidget {
  const HubModuleCard({
    super.key,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.pill,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.checklist,
    this.highlight = false,
    required this.cta,
    this.ctaIcon,
    this.ctaStyle = CtaStyle.secondary,
    required this.onClick,
    this.mobile = false,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Widget pill;
  final String eyebrow;
  final String title;
  final String description;
  final List<Widget> checklist;
  final bool highlight;
  final String cta;
  final Widget? ctaIcon;
  final CtaStyle ctaStyle;
  final VoidCallback onClick;
  final bool mobile;

  @override
  State<HubModuleCard> createState() => _HubModuleCardState();
}

class _HubModuleCardState extends State<HubModuleCard> {
  bool _btnHovered = false;

  @override
  Widget build(BuildContext context) {
    final ctaBg = widget.ctaStyle == CtaStyle.primary
        ? AppColors.gold
        : widget.ctaStyle == CtaStyle.outline
            ? AppColors.surface
            : AppColors.ctaDark;

    final ctaColor = widget.ctaStyle == CtaStyle.primary
        ? AppColors.brown
        : widget.ctaStyle == CtaStyle.outline
            ? AppColors.ink
            : const Color(0xFFF5F0E6);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: widget.highlight
            ? const [
                BoxShadow(
                  color: Color(0x1FF2B705), // rgba(242,183,5,0.12)
                  blurRadius: 28,
                  offset: Offset(0, 6),
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x0A1C1917), // rgba(28,25,23,0.04)
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Gold top border for highlighted card
          if (widget.highlight)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 3,
                color: AppColors.gold,
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              widget.mobile ? 18 : 26,
              (widget.mobile ? 20 : 28) + (widget.highlight ? 2 : 0),
              widget.mobile ? 18 : 26,
              widget.mobile ? 18 : 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top row: Icon + Pill badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: widget.mobile ? 42 : 52,
                      height: widget.mobile ? 42 : 52,
                      decoration: BoxDecoration(
                        color: widget.iconBg,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        widget.icon,
                        size: widget.mobile ? 20 : 24,
                        color: widget.iconColor,
                      ),
                    ),
                    widget.pill,
                  ],
                ),
                SizedBox(height: widget.mobile ? 14 : 18),

                // Text block: Eyebrow, Title, Description
                Text(
                  widget.eyebrow.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.title,
                  style: GoogleFonts.inter(
                    fontSize: widget.mobile ? 20 : 22,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.description,
                  style: GoogleFonts.inter(
                    fontSize: widget.mobile ? 13 : 13.5,
                    color: AppColors.muted,
                    height: 1.6,
                  ),
                ),
                SizedBox(height: widget.mobile ? 14 : 18),

                // Checklist
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < widget.checklist.length; i++) ...[
                      widget.checklist[i],
                      if (i < widget.checklist.length - 1)
                        SizedBox(height: widget.mobile ? 6 : 8),
                    ],
                  ],
                ),
                SizedBox(height: widget.mobile ? 16 : 24),

                // Action button at bottom
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _btnHovered = true),
                  onExit: (_) => setState(() => _btnHovered = false),
                  child: GestureDetector(
                    onTap: widget.onClick,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: _btnHovered ? 0.88 : 1.0,
                      child: Container(
                        width: double.infinity,
                        padding: widget.ctaStyle == CtaStyle.primary
                            ? const EdgeInsets.fromLTRB(18, 10, 12, 10)
                            : const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                        decoration: BoxDecoration(
                          color: ctaBg,
                          borderRadius: BorderRadius.circular(11),
                          border: widget.ctaStyle == CtaStyle.outline
                              ? Border.all(color: AppColors.border)
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              widget.cta,
                              style: GoogleFonts.inter(
                                fontSize: widget.mobile ? 12 : 12.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: ctaColor,
                              ),
                            ),
                            if (widget.ctaStyle == CtaStyle.primary)
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: AppColors.ctaDark,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 16,
                                  color: Color(0xFFF5F0E6),
                                ),
                              )
                            else if (widget.ctaIcon != null)
                              widget.ctaIcon!
                            else
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: ctaColor,
                              ),
                          ],
                        ),
                      ),
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