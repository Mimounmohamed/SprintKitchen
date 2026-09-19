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
    this.ticketNumber = '0000123',
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
  final ScrollController _gridScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  @override
  void dispose() {
    _gridScrollController.dispose();
    super.dispose();
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
      barrierColor: Colors.transparent,
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
      barrierColor: Colors.transparent,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD1D5DB)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back, size: 14, color: Color(0xFF374151)),
                  SizedBox(width: 8),
                  Text(
                    "Retour à l'accueil",
                    style: TextStyle(
                      color: Color(0xFF374151),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF583926),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(Icons.restaurant_rounded,
                  color: Color(0xFFFACC15), size: 17),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'SPRINTKITCHEN',
            style: GoogleFonts.bebasNeue(
              fontWeight: FontWeight.w400,
              fontSize: 22,
              letterSpacing: 1.2,
              color: const Color(0xFF111827),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.posteLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
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
      width: 210,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                return CategorySidebarItem(
                  icon: category.icon,
                  label: category.label,
                  selected: index == _selectedCategory,
                  onTap: () {
                    setState(() => _selectedCategory = index);
                    if (_gridScrollController.hasClients) {
                      _gridScrollController.jumpTo(0);
                    }
                  },
                );
              },
            ),
          ),
          _buildFooter(),
        ],
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool hasManyItems = items.length > 15;
        final double maxExtent = hasManyItems ? 175 : 205;
        final double itemHeight = hasManyItems ? 140 : 155;

        return RawScrollbar(
          controller: _gridScrollController,
          thumbColor: const Color(0xFFFACC15),
          radius: const Radius.circular(4),
          thickness: 6,
          thumbVisibility: true,
          child: GridView.builder(
            controller: _gridScrollController,
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: maxExtent,
              mainAxisExtent: itemHeight,
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
      },
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Text(
                  'Ticket N° ${widget.ticketNumber}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'En cours',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.menu,
                  size: 22,
                  color: Color(0xFF4B5563),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              border: Border(
                top: BorderSide(color: Color(0xFFE5E7EB)),
                bottom: BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text('PRODUIT',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B7280),
                          letterSpacing: 0.5)),
                ),
                Expanded(
                  flex: 1,
                  child: Text('QTÉ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B7280),
                          letterSpacing: 0.5)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('PRIX',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B7280),
                          letterSpacing: 0.5)),
                ),
              ],
            ),
          ),
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
          const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _lineActionButton(
                  icon: Icons.add,
                  color: const Color(0xFF2563EB),
                  bg: const Color(0xFFEFF6FF),
                  onTap: () => _adjustSelectedQuantity(1),
                ),
                const SizedBox(width: 8),
                _lineActionButton(
                  icon: Icons.remove,
                  color: const Color(0xFF2563EB),
                  bg: const Color(0xFFEFF6FF),
                  onTap: () => _adjustSelectedQuantity(-1),
                ),
                const SizedBox(width: 8),
                _lineActionButton(
                  icon: Icons.settings_outlined,
                  color: const Color(0xFF059669),
                  bg: const Color(0xFFECFDF5),
                  onTap: () {},
                ),
                const SizedBox(width: 8),
                _lineActionButton(
                  icon: Icons.chat_bubble,
                  color: const Color(0xFF4B5563),
                  bg: const Color(0xFFF3F4F6),
                  onTap: () {},
                ),
                const SizedBox(width: 8),
                _lineActionButton(
                  icon: Icons.close,
                  color: const Color(0xFFDC2626),
                  bg: const Color(0xFFFEF2F2),
                  onTap: _removeSelectedLine,
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL :',
                    style: GoogleFonts.bebasNeue(
                      color: const Color(0xFF1F2937),
                      fontSize: 26,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Text(
                    '${_total.toStringAsFixed(2).replaceAll('.', ',')} €',
                    style: GoogleFonts.bebasNeue(
                      color: const Color(0xFF1F2937),
                      fontSize: 28,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                _orderTypeButton(
                  OrderType.dineIn,
                  const Color(0xFFE11D48),
                  Icons.shopping_cart_outlined,
                ),
                const SizedBox(width: 8),
                _orderTypeButton(
                  OrderType.takeaway,
                  const Color(0xFF2563EB),
                  Icons.shopping_bag_outlined,
                ),
                const SizedBox(width: 8),
                _orderTypeButton(
                  OrderType.delivery,
                  const Color(0xFF0D9488),
                  Icons.local_shipping_outlined,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _ticketLines.isEmpty ? null : _openEncaissement,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  disabledBackgroundColor:
                      const Color(0xFF059669).withValues(alpha: 0.5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  padding: EdgeInsets.zero,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.credit_card,
                        color: Color(0xFFFBBF24), size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'ENCAISSEMENT',
                      style: GoogleFonts.bebasNeue(
                        fontSize: 24,
                        letterSpacing: 2.0,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: _smallActionButton(
                    label: 'History',
                    icon: Icons.inventory_2_outlined,
                    bg: const Color(0xFF27272A),
                    fg: Colors.white,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _smallActionButton(
                    label: 'Actions',
                    icon: Icons.tune,
                    bg: const Color(0xFFF59E0B),
                    fg: const Color(0xFF1F2937),
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _smallActionButton(
                    label: 'Reprise',
                    icon: Icons.sync,
                    bg: const Color(0xFF452B1E),
                    fg: const Color(0xFFFBBF24),
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: const Row(
        children: [
          _StatusDot(),
          SizedBox(width: 8),
          Text(
            'Connecté',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF4B5563),
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
    required Color bg,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Icon(icon, size: 18, color: color),
          ),
        ),
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
          height: 38,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            border: selected
                ? Border.all(color: Colors.white, width: 2)
                : Border.all(color: Colors.transparent, width: 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: Colors.white),
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
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: outlined ? Border.all(color: const Color(0xFFE5E7EB)) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: fg,
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
        color: Color(0xFF10B981),
        shape: BoxShape.circle,
      ),
    );
  }
}