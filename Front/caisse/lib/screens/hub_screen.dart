import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/dashboard_service.dart';
import '../theme/app_colors.dart';
import '../widgets/hub_module_card.dart';
import 'history_screen.dart';
import 'pos_screen.dart';

/// SprintKitchen Caisse Hub — Identical design and visual hierarchy
/// to the SprintKitchen Admin Hub (palette, live KPIs, module cards, checklists).
class HubScreen extends StatefulWidget {
  const HubScreen({
    super.key,
    this.posteLabel = 'Poste Caisse #01',
    this.userLabel = 'Admin — Caisse 01',
    this.appVersion = 'SprintKitchen OS Caisse v2.4.0-PROD',
    this.isConnected = true,
  });

  final String posteLabel;
  final String userLabel;
  final String appVersion;
  final bool isConnected;

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  DashboardKpis? _kpi;
  bool _isLoadingKpi = true;

  @override
  void initState() {
    super.initState();
    _loadKpi();
  }

  Future<void> _loadKpi() async {
    try {
      final data = await DashboardService().fetchKpis();
      if (mounted) {
        setState(() {
          _kpi = data;
          _isLoadingKpi = false;
        });
      }
    } catch (_) {
      // Silently fail to show dashes or fallback — matches web admin
      if (mounted) {
        setState(() => _isLoadingKpi = false);
      }
    }
  }

  String _formatCurrency(double val) {
    final rounded = val.round().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < rounded.length; i++) {
      if (i > 0 && (rounded.length - i) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(rounded[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 900;

        // KPI Formatted values
        final caFmt = _kpi != null
            ? '${_formatCurrency(_kpi!.revenueToday)} DA'
            : (_isLoadingKpi ? '—' : '0 DA');

        final vsPct = _kpi?.vsLastYear != null
            ? '${_kpi!.vsLastYear! >= 0 ? "+" : ""}${_kpi!.vsLastYear}% vs N-1'
            : 'vs N-1';

        final vsPctPositive = (_kpi?.vsLastYear ?? 0) >= 0;

        final ticketsFmt = _kpi != null
            ? '${_kpi!.ticketsToday}'
            : (_isLoadingKpi ? '—' : '0');

        final ruptureCount = _kpi?.ruptureCount ?? 0;
        final ruptureFmt = _kpi != null
            ? '$ruptureCount'
            : (_isLoadingKpi ? '—' : '0');
        final ruptureWarn = ruptureCount > 0;

        if (mobile) {
          return _buildMobileLayout(
            context: context,
            caFmt: caFmt,
            vsPct: vsPct,
            vsPctPositive: vsPctPositive,
            ticketsFmt: ticketsFmt,
            ruptureFmt: ruptureFmt,
            ruptureWarn: ruptureWarn,
            ruptureCount: ruptureCount,
          );
        }

        return _buildDesktopLayout(
          context: context,
          caFmt: caFmt,
          vsPct: vsPct,
          vsPctPositive: vsPctPositive,
          ticketsFmt: ticketsFmt,
          ruptureFmt: ruptureFmt,
          ruptureWarn: ruptureWarn,
          ruptureCount: ruptureCount,
          width: constraints.maxWidth,
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DESKTOP LAYOUT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDesktopLayout({
    required BuildContext context,
    required String caFmt,
    required String vsPct,
    required bool vsPctPositive,
    required String ticketsFmt,
    required String ruptureFmt,
    required bool ruptureWarn,
    required int ruptureCount,
    required double width,
  }) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Logo brand block
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.brown,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: AppColors.gold,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'SPRINTKITCHEN',
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.brown,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        'HUB',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFF5F0E6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.gold,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),

                // Top right status pill
                HubPill(
                  dot: true,
                  dotColor: AppColors.green,
                  bg: const Color(0xFFF1F0EC),
                  color: AppColors.ink,
                  text: '${widget.posteLabel} — En direct',
                ),
              ],
            ),
          ),

          // Main scrollable area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(40, 48, 40, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + Live KPIs row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left: Title block
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'PORTAIL OPÉRATIONNEL & ENCAISSEMENT',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.6,
                                    color: AppColors.muted,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('·',
                                    style: TextStyle(color: AppColors.muted)),
                                const SizedBox(width: 8),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'SPRINTKITCHEN CAISSE',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.green,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 14,
                              runSpacing: 8,
                              children: [
                                Text(
                                  'Portail Caisse & Ventes',
                                  style: GoogleFonts.inter(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F0EC),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    widget.posteLabel,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 540),
                              child: Text(
                                'Bienvenue sur le Hub de Caisse • Saisie des commandes, consultation des tickets et indicateurs d\'activité en direct.',
                                style: GoogleFonts.inter(
                                  fontSize: 14.5,
                                  color: AppColors.muted,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),

                      // Right: 3 KPI cards
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          HubKpiCard(
                            label: "Chiffre d'affaires",
                            value: caFmt,
                            valueColor: AppColors.green,
                            sub: vsPct,
                            subColor:
                                vsPctPositive ? AppColors.green : AppColors.red,
                          ),
                          HubKpiCard(
                            label: "Tickets Clôturés",
                            value: ticketsFmt,
                            sub: "Aujourd'hui",
                          ),
                          HubKpiCard(
                            label: "Articles en Rupture",
                            value: ruptureFmt,
                            valueColor:
                                ruptureWarn ? AppColors.orange : AppColors.ink,
                            sub: "Ingrédients (86 list)",
                            subColor:
                                ruptureWarn ? AppColors.orange : AppColors.muted,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Divider
                  Container(height: 1, color: AppColors.border),
                  const SizedBox(height: 28),

                  // Module cards grid
                  _buildCardsGrid(
                    context: context,
                    width: width,
                    ruptureWarn: ruptureWarn,
                    ruptureFmt: ruptureFmt,
                    ruptureCount: ruptureCount,
                    mobile: false,
                  ),
                ],
              ),
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Connecté',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('·', style: TextStyle(color: AppColors.muted)),
                  ],
                ),
                Text(
                  widget.appVersion,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MOBILE LAYOUT (< 900px)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMobileLayout({
    required BuildContext context,
    required String caFmt,
    required String vsPct,
    required bool vsPctPositive,
    required String ticketsFmt,
    required String ruptureFmt,
    required bool ruptureWarn,
    required int ruptureCount,
  }) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Mobile Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu_rounded, size: 22),
                    color: AppColors.ink,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {},
                  ),
                  Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppColors.brown,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Icon(
                          Icons.menu_book_rounded,
                          color: AppColors.gold,
                          size: 15,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'SPRINTKITCHEN',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.brown,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'HUB',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFF5F0E6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.gold,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  Stack(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE8E4DF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person,
                            size: 17, color: AppColors.muted),
                      ),
                      Positioned(
                        top: 1,
                        right: 1,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Breadcrumb
                    Row(
                      children: [
                        Text(
                          'PORTAIL ENCAISSEMENT',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('·', style: TextStyle(color: AppColors.muted)),
                        const SizedBox(width: 6),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: AppColors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'EN DIRECT',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Title row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PORTAIL CAISSE',
                              style: GoogleFonts.bebasNeue(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                                height: 1.05,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Bienvenue sur le Hub de Caisse mobile',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F0EC),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            widget.posteLabel,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // KPI strip — 3 columns
                    Row(
                      children: [
                        Expanded(
                          child: HubMobileKpiCard(
                            label: 'C.A. JOUR',
                            value: caFmt,
                            valueColor: AppColors.green,
                            sub: vsPct,
                            subColor:
                                vsPctPositive ? AppColors.green : AppColors.red,
                            icon: Icon(
                              Icons.trending_up_rounded,
                              size: 14,
                              color:
                                  vsPctPositive ? AppColors.green : AppColors.red,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: HubMobileKpiCard(
                            label: 'TICKETS',
                            value: ticketsFmt,
                            sub: 'Clôturés',
                            icon: const Text('🧾', style: TextStyle(fontSize: 11)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: HubMobileKpiCard(
                            label: 'ALERTES',
                            value: ruptureFmt,
                            valueColor:
                                ruptureWarn ? AppColors.orange : AppColors.ink,
                            sub: '86 List',
                            subColor:
                                ruptureWarn ? AppColors.orange : AppColors.muted,
                            borderColor:
                                ruptureWarn ? const Color(0xFFF5C6C2) : null,
                            icon: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: ruptureWarn
                                    ? AppColors.red
                                    : AppColors.gold,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Cards stack
                    _buildCardsGrid(
                      context: context,
                      width: 400,
                      ruptureWarn: ruptureWarn,
                      ruptureFmt: ruptureFmt,
                      ruptureCount: ruptureCount,
                      mobile: true,
                    ),
                  ],
                ),
              ),
            ),

            // Mobile Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Connecté',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MODULE CARDS (4 MODULES)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCardsGrid({
    required BuildContext context,
    required double width,
    required bool ruptureWarn,
    required String ruptureFmt,
    required int ruptureCount,
    required bool mobile,
  }) {
    final cards = [
      // 1. Caisse POS (Primary)
      HubModuleCard(
        mobile: mobile,
        icon: Icons.point_of_sale_rounded,
        iconBg: AppColors.brown,
        iconColor: AppColors.gold,
        pill: HubPill(
          small: true,
          dot: true,
          dotColor: const Color(0xFFC98A1A),
          bg: AppColors.yellowBg,
          color: const Color(0xFF946200),
          text: 'MODULE PRINCIPAL',
        ),
        eyebrow: 'Saisie & encaissement',
        title: 'Caisse Enregistreuse / POS',
        description:
            'Prenez les commandes sur place, à emporter ou livraison et procédez à l\'encaissement.',
        checklist: const [
          ChecklistItem(text: 'Prise de commande rapide & menus'),
          ChecklistItem(text: 'Paiements : Espèces, CIB, Carte'),
        ],
        highlight: true,
        cta: 'OUVRIR LA CAISSE POS',
        ctaStyle: CtaStyle.primary,
        onClick: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PosScreen()),
          );
        },
      ),

      // 2. Historique des Commandes
      HubModuleCard(
        mobile: mobile,
        icon: Icons.access_time_rounded,
        iconBg: const Color(0xFFF1F0EC),
        iconColor: AppColors.ink,
        pill: HubPill(
          small: true,
          bg: const Color(0xFFF1F0EC),
          color: AppColors.muted,
          text: 'ARCHIVES & TICKETS',
        ),
        eyebrow: 'Commandes & Reçus',
        title: 'Historique des Commandes',
        description:
            'Consultez les tickets de la journée, réimprimez les additions et suivez les règlements.',
        checklist: const [
          ChecklistItem(text: 'Recherche de tickets & réimpression'),
          ChecklistItem(text: 'Rapprochement & annulations'),
        ],
        cta: "CONSULTER L'HISTORIQUE",
        ctaStyle: CtaStyle.secondary,
        onClick: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const HistoryScreen()),
          );
        },
      ),

      // 3. Stock & 86 List
      HubModuleCard(
        mobile: mobile,
        icon: Icons.inventory_2_outlined,
        iconBg: const Color(0xFFFEF3E2),
        iconColor: const Color(0xFFD9720C),
        pill: ruptureWarn
            ? HubPill(
                small: true,
                dot: true,
                dotColor: const Color(0xFFD9720C),
                bg: const Color(0xFFFEF3E2),
                color: const Color(0xFFD9720C),
                text:
                    '$ruptureCount ALERTE${ruptureCount > 1 ? 'S' : ''} ACTIVES',
              )
            : HubPill(
                small: true,
                bg: const Color(0xFFF1F0EC),
                color: AppColors.muted,
                text: 'STOCK & 86 LIST',
              ),
        eyebrow: 'Stocks & Ingrédients',
        title: 'Stock & 86 List',
        description:
            'Contrôlez les ruptures d\'ingrédients en temps réel et signalez les produits épuisés (86).',
        checklist: [
          ChecklistItem(
            warn: ruptureWarn,
            text: ruptureWarn
                ? '$ruptureCount Alerte${ruptureCount > 1 ? "s" : ""} de stock critique (86)'
                : 'Niveaux de stock sous contrôle',
          ),
          const ChecklistItem(
            text: 'Disponibilité des ingrédients en temps réel',
          ),
        ],
        cta: 'GÉRER LES STOCKS & 86',
        ctaStyle: CtaStyle.secondary,
        onClick: () => _showStockModal(context),
      ),
    ];

    if (mobile) {
      return Column(
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            cards[i],
            if (i < cards.length - 1) const SizedBox(height: 14),
          ],
        ],
      );
    }

    // Desktop: 3 columns side by side
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          Expanded(child: cards[i]),
          if (i < cards.length - 1) const SizedBox(width: 24),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MODALS FOR STOCKS
  // ═══════════════════════════════════════════════════════════════════════════

  void _showStockModal(BuildContext context) {
    final items = _kpi?.ruptureItems ?? [];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.inventory_2_outlined,
                  color: Color(0xFFD9720C), size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              'Articles & Ingrédients Épuisés (86)',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                items.isEmpty
                    ? 'Aucun ingrédient n\'est actuellement en rupture de stock.'
                    : 'Les ingrédients suivants sont signalés en rupture (86 list) :',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              if (items.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final it = items[i];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3E2),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: const Color(0xFFF5C6C2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                size: 16, color: AppColors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                it.name,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                            if (it.family != null)
                              Text(
                                it.family!,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Fermer',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}