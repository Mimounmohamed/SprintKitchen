import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/pos_models.dart';
import '../theme/app_colors.dart';
import '../widgets/pos/category_sidebar_item.dart';
import '../widgets/pos/menu_item_tile.dart';
import '../widgets/pos/ticket_line_tile.dart';
import '../widgets/pos/customization_modal.dart';
import '../services/menu_service.dart';
import '../widgets/pos/encaissement_modal.dart';

/// The POS / register screen ("SprintKitchen POS - Caisse Principale").
///
/// Drop into lib/screens/pos_screen.dart and navigate to it from the
/// Hub screen's "New Order / Register" card.
class PosScreen extends StatefulWidget {
  const PosScreen({
    super.key,
    this.ticketNumber = '00001',
    this.posteLabel = 'Caisse 01',
  });

  final String ticketNumber;
  final String posteLabel;

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  int _selectedCategory = 0;
  OrderType _orderType = OrderType.dineIn;
  int? _selectedLineIndex = 0;

  final MenuService _menuService = MenuService();
  List<MenuCategory> _categories = [];
  bool _loading = true;
  String? _error;

  final List<TicketLine> _ticketLines = [];

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final categories = await _menuService.fetchMenu();
      setState(() {
        _categories = categories;
        _selectedCategory = 0;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  double get _total =>
      _ticketLines.fold(0, (sum, line) => sum + line.total);

  void _onItemTap(MenuItem item) {
    if (!item.needsCustomization) {
      _addItemToTicket(item);
      return;
    }
    _openCustomization(item);
  }

  Future<void> _openCustomization(MenuItem item) async {
    final line = await showDialog<TicketLine>(
      context: context,
      builder: (_) => CustomizationModal(item: item),
    );
    if (line == null) return;
    setState(() {
      _ticketLines.add(line);
      _selectedLineIndex = _ticketLines.length - 1;
    });
  }

  void _addItemToTicket(MenuItem item) {
    setState(() {
      final existingIndex = _ticketLines.indexWhere((l) => l.name == item.name);
      if (existingIndex != -1) {
        _ticketLines[existingIndex].quantity += 1;
      } else {
        _ticketLines.add(TicketLine(
          name: item.name,
          unitPrice: item.price,
          productId: item.id,
        ));
      }
      _selectedLineIndex = _ticketLines.length - 1;
    });
  }

  void _adjustSelectedQuantity(int delta) {
    if (_selectedLineIndex == null) return;
    setState(() {
      final line = _ticketLines[_selectedLineIndex!];
      final newQty = line.quantity + delta;
      if (newQty <= 0) {
        _ticketLines.removeAt(_selectedLineIndex!);
        _selectedLineIndex =
            _ticketLines.isEmpty ? null : _ticketLines.length - 1;
      } else {
        line.quantity = newQty;
      }
    });
  }

  void _removeSelectedLine() {
    if (_selectedLineIndex == null) return;
    setState(() {
      _ticketLines.removeAt(_selectedLineIndex!);
      _selectedLineIndex =
          _ticketLines.isEmpty ? null : _ticketLines.length - 1;
    });
  }

  Future<void> _openEncaissement() async {
    final result = await showDialog<EncaissementResult>(
      context: context,
      builder: (_) => EncaissementModal(
        total: _total,
        ticketNumber: widget.ticketNumber,
        posteLabel: widget.posteLabel,
      ),
    );
    if (result == null) return;

    // TODO: next step — POST /api/orders with items + this payment info,
    // then POST /api/payments, then reset the ticket / bump ticketNumber.
    setState(() {
      _ticketLines.clear();
      _selectedLineIndex = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          result.method == PaymentMethod.especes
              ? 'Paiement espèces enregistré — rendu ${result.change.toStringAsFixed(2).replaceAll('.', ',')} €'
              : 'Paiement carte enregistré',
        )),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorState()
                    : Row(
                        children: [
                          _buildSidebar(),
                          Expanded(child: _buildMenuGrid()),
                          _buildTicketPanel(),
                        ],
                      ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 40, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            'Impossible de charger le menu.\n$_error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadMenu,
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back, size: 16,
                color: AppColors.textSecondary),
            label: const Text(
              "Retour à l'accueil",
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.brandDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.menu_book_rounded,
                color: AppColors.gold, size: 16),
          ),
          const SizedBox(width: 10),
          const Text(
            'SPRINTKITCHEN',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              letterSpacing: 0.4,
              color: AppColors.textPrimary,
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
                  widget.posteLabel,
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

  Widget _buildSidebar() {
    return Container(
      width: 190,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          return CategorySidebarItem(
            icon: category.icon,
            label: category.label,
            selected: index == _selectedCategory,
            onTap: () => setState(() => _selectedCategory = index),
          );
        },
      ),
    );
  }

  Widget _buildMenuGrid() {
    if (_categories.isEmpty) {
      return const Center(
        child: Text(
          'Aucune catégorie disponible.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    final items = _categories[_selectedCategory].items;

    if (items.isEmpty) {
      return const Center(
        child: Text(
          'Aucun article dans cette catégorie pour le moment.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: GridView.builder(
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 260,
          mainAxisExtent: 96,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
        ),
        itemBuilder: (context, index) {
          final item = items[index];
          return MenuItemTile(
            item: item,
            onTap: () => _onItemTap(item),
          );
        },
      ),
    );
  }

  Widget _buildTicketPanel() {
    return Container(
      width: 383,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ticket N° ${widget.ticketNumber}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.goldSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'En cours',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.receipt_long_outlined,
                    size: 18, color: AppColors.textMuted),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: const Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text('PRODUIT',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted)),
                ),
                Expanded(
                  flex: 1,
                  child: Text('QTÉ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('PRIX',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: _ticketLines.isEmpty
                ? const Center(
                    child: Text(
                      'Ticket vide',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : ListView.builder(
                    itemCount: _ticketLines.length,
                    itemBuilder: (context, index) {
                      return TicketLineTile(
                        line: _ticketLines[index],
                        selected: index == _selectedLineIndex,
                        onTap: () =>
                            setState(() => _selectedLineIndex = index),
                      );
                    },
                  ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _lineActionButton(
                  icon: Icons.add,
                  color: AppColors.takeaway,
                  onTap: () => _adjustSelectedQuantity(1),
                ),
                _lineActionButton(
                  icon: Icons.remove,
                  color: AppColors.takeaway,
                  onTap: () => _adjustSelectedQuantity(-1),
                ),
                _lineActionButton(
                  icon: Icons.tune,
                  color: AppColors.success,
                  onTap: () {},
                ),
                _lineActionButton(
                  icon: Icons.chat_bubble_outline,
                  color: AppColors.textSecondary,
                  onTap: () {},
                ),
                _lineActionButton(
                  icon: Icons.close,
                  color: AppColors.danger,
                  onTap: _removeSelectedLine,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL :',
                    style: GoogleFonts.bebasNeue(
                      color: const Color(0xFF292524),
                      fontSize: 24,
                      fontWeight: FontWeight.w400,
                      height: 32 / 24,
                      letterSpacing: 0.6,
                    ),
                  ),
                  Text(
                    '${_total.toStringAsFixed(2).replaceAll('.', ',')} €',
                    style: GoogleFonts.bebasNeue(
                      color: const Color(0xFF292524),
                      fontSize: 24,
                      fontWeight: FontWeight.w400,
                      height: 32 / 24,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _orderTypeButton(
                    OrderType.dineIn, AppColors.dineIn, Icons.storefront),
                const SizedBox(width: 8),
                _orderTypeButton(
                    OrderType.takeaway, AppColors.takeaway, Icons.shopping_bag),
                const SizedBox(width: 8),
                _orderTypeButton(
                    OrderType.delivery, AppColors.delivery, Icons.moped),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _ticketLines.isEmpty ? null : _openEncaissement,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.payment, size: 18),
                label: const Text(
                  'ENCAISSEMENT',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _smallActionButton(
                    label: 'History',
                    icon: Icons.history,
                    bg: AppColors.brandDark,
                    fg: Colors.white,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _smallActionButton(
                    label: 'Actions',
                    icon: Icons.tune,
                    bg: AppColors.actionOrange,
                    fg: AppColors.brandDark,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _smallActionButton(
                    label: 'Reprise',
                    icon: Icons.autorenew,
                    bg: AppColors.brandDark,
                    fg: AppColors.gold,
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: const [
          _StatusDot(),
          SizedBox(width: 8),
          Text(
            'Connecté',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 44,
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 17, color: color),
      ),
    );
  }

  Widget _orderTypeButton(OrderType type, Color color, IconData icon) {
    final bool selected = _orderType == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _orderType = type),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            border: selected
                ? Border.all(color: Colors.white, width: 2)
                : Border.all(color: Colors.transparent, width: 2),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: Colors.white),
              const SizedBox(width: 5),
              Text(
                type.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _smallActionButton({
    required String label,
    required IconData icon,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
    bool outlined = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: outlined ? Border.all(color: AppColors.border) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: AppColors.success,
        shape: BoxShape.circle,
      ),
    );
  }
}