import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/hub_module_card.dart';

/// SprintKitchen "Hub" landing screen — Windows/desktop layout.
///
/// Drop this into lib/screens/hub_screen.dart inside the `caisse` project
/// and route to it (e.g. as the home screen, or after login).
class HubScreen extends StatelessWidget {
  const HubScreen({
    super.key,
    this.posteLabel = 'Poste Caisse #01',
    this.userLabel = 'Admin — Caisse 01',
    this.ticketsToday = 142,
    this.lowStockCount = 3,
    this.lowStockRef = '86',
    this.appVersion = 'SprintKitchen OS v2.4.0-PROD',
    this.isConnected = true,
  });

  final String posteLabel;
  final String userLabel;
  final int ticketsToday;
  final int lowStockCount;
  final String lowStockRef;
  final String appVersion;
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 48,
                vertical: 40,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeSection(),
                    const SizedBox(height: 32),
                    _buildModuleCards(context),
                  ],
                ),
              ),
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.brandDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.menu_book_rounded,
                color: AppColors.gold, size: 18),
          ),
          const SizedBox(width: 10),
          const Text(
            'SPRINTKITCHEN',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              letterSpacing: 0.4,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'HUB',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.brandDark,
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  userLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 8),
              decoration: const BoxDecoration(
                color: AppColors.gold,
                shape: BoxShape.circle,
              ),
            ),
            Text(
              'PORTAIL OPÉRATIONNEL EN DIRECT',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Bienvenue sur SprintKitchen',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                posteLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Sélectionnez le module d\'activité pour lancer l\'encaissement, '
          'auditer les ventes ou vérifier les stocks.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        Container(height: 1, color: AppColors.border),
      ],
    );
  }

  Widget _buildModuleCards(BuildContext context) {
    final cards = [
      HubModuleCard(
        icon: Icons.point_of_sale_rounded,
        eyebrow: 'Saisie & encaissement',
        title: 'New Order / Register',
        buttonLabel: 'OUVRIR LA CAISSE POS',
        highlighted: true,
        badgeText: 'MODULE PRINCIPAL',
        badgeColor: AppColors.goldSoft,
        badgeTextColor: AppColors.textPrimary,
        onTap: () => _navigateTo(context, 'pos'),
      ),
      HubModuleCard(
        icon: Icons.access_time_rounded,
        eyebrow: "Audit, rappels & ventes",
        title: 'Order History',
        buttonLabel: "CONSULTER L'HISTORIQUE",
        buttonStyleFilled: true,
        badgeText: '$ticketsToday TICKETS AUJOURD\'HUI',
        badgeColor: AppColors.background,
        badgeTextColor: AppColors.textSecondary,
        onTap: () => _navigateTo(context, 'history'),
      ),
      HubModuleCard(
        icon: Icons.inventory_2_outlined,
        eyebrow: 'Réserve, KDS & liste $lowStockRef',
        title: 'Stock & Inventory',
        buttonLabel: 'GÉRER LES STOCKS & $lowStockRef LIST',
        buttonStyleFilled: false,
        badgeText: '$lowStockCount EN RUPTURE ($lowStockRef)',
        badgeColor: AppColors.dangerSoft,
        badgeTextColor: AppColors.danger,
        onTap: () => _navigateTo(context, 'stock'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 820;
        if (isNarrow) {
          return Column(
            children: [
              for (final c in cards) ...[
                c,
                const SizedBox(height: 20),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i != cards.length - 1) const SizedBox(width: 20),
            ],
          ],
        );
      },
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
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
                decoration: BoxDecoration(
                  color: isConnected ? AppColors.success : AppColors.danger,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isConnected ? 'Connecté' : 'Hors ligne',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Text(
            appVersion,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateTo(BuildContext context, String moduleKey) {
    // TODO: wire these up to your existing routes/screens, e.g.:
    // Navigator.pushNamed(context, '/pos');
    // Navigator.pushNamed(context, '/orders/history');
    // Navigator.pushNamed(context, '/stock');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Navigate to: $moduleKey')),
    );
  }
}