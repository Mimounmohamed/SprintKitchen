import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/pos_models.dart';
import '../theme/app_colors.dart';
import '../widgets/pos/category_sidebar_item.dart';
import '../widgets/pos/menu_item_tile.dart';
import '../widgets/pos/ticket_line_tile.dart';
import '../widgets/pos/customization_modal.dart';
import '../services/menu_service.dart';
import '../services/order_service.dart';
import 'history_screen.dart';

class ServeurPosScreen extends StatefulWidget {
  const ServeurPosScreen({
    super.key,
    this.ticketNumber = '000001',
    this.posteLabel = 'Serveur 01',
  });

  final String ticketNumber;
  final String posteLabel;

  @override
  State<ServeurPosScreen> createState() => _ServeurPosScreenState();
}

class _ServeurPosScreenState extends State<ServeurPosScreen> {
  int _selectedCategory = 0;
  OrderType _orderType = OrderType.dineIn;
  int? _selectedLineIndex = 0;

  final MenuService _menuService = MenuService();
  final OrderService _orderService = OrderService();
  List<MenuCategory> _categories = [];
  bool _loading = true;
  String? _error;

  final List<TicketLine> _ticketLines = [];
  final ScrollController _gridScrollController = ScrollController();

  late String _ticketNumber;
  bool _submitting = false;
  String? _orderNotes;
  String? _tableNumber;

  @override
  void initState() {
    super.initState();
    _ticketNumber = widget.ticketNumber;
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

  MenuItem? _findMenuItemForLine(TicketLine line) {
    if (line.productId != null && line.productId!.isNotEmpty) {
      for (final cat in _categories) {
        for (final it in cat.items) {
          if (it.id == line.productId) {
            return it;
          }
        }
      }
    }
    for (final cat in _categories) {
      for (final it in cat.items) {
        if (it.name.trim().toLowerCase() == line.name.trim().toLowerCase()) {
          return it;
        }
      }
    }
    return null;
  }

  List<CustomizationGroup> _getDefaultCustomizationGroups() {
    for (final cat in _categories) {
      for (final it in cat.items) {
        for (final g in it.customizationGroups) {
          if (g.name.toLowerCase().contains('sauce')) {
            return [g];
          }
        }
      }
    }

    return const [
      CustomizationGroup(
        name: 'Choix de la sauce',
        type: 'multi',
        isRequired: false,
        minChoices: 0,
        maxChoices: 3,
        options: [
          CustomizationOption(label: 'Algérienne', priceModifier: 0),
          CustomizationOption(label: 'Burger', priceModifier: 0, isDefault: true),
          CustomizationOption(label: 'Mayonnaise', priceModifier: 0),
          CustomizationOption(label: 'Ketchup', priceModifier: 0),
          CustomizationOption(label: 'Samourai', priceModifier: 0),
          CustomizationOption(label: 'Barbecue', priceModifier: 0),
        ],
      ),
    ];
  }

  Future<void> _editSelectedItem() async {
    if (_ticketLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le ticket est vide. Ajoutez d\'abord un article.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    int targetIndex = _selectedLineIndex ?? (_ticketLines.length - 1);
    if (targetIndex < 0 || targetIndex >= _ticketLines.length) {
      targetIndex = _ticketLines.length - 1;
    }

    setState(() => _selectedLineIndex = targetIndex);
    final line = _ticketLines[targetIndex];

    MenuItem? menuItem = _findMenuItemForLine(line);

    if (menuItem == null) {
      menuItem = MenuItem(
        id: line.productId ?? '',
        name: line.name,
        price: line.unitPrice,
        categoryId: '',
        customizationGroups: _getDefaultCustomizationGroups(),
        ingredients: const ['Oignon', 'Tomate', 'Salade', 'Cornichon'],
      );
    } else {
      final hasSauceGroup = menuItem.customizationGroups
          .any((g) => g.name.toLowerCase().contains('sauce'));

      if (!hasSauceGroup) {
        final sauceGroups = _getDefaultCustomizationGroups();
        menuItem = MenuItem(
          id: menuItem.id,
          name: menuItem.name,
          price: menuItem.price,
          categoryId: menuItem.categoryId,
          description: menuItem.description,
          available: menuItem.available,
          customizationGroups: [
            ...menuItem.customizationGroups,
            ...sauceGroups,
          ],
          ingredients: menuItem.ingredients.isNotEmpty
              ? menuItem.ingredients
              : const ['Oignon', 'Tomate', 'Salade', 'Cornichon'],
        );
      }
    }

    final updatedLine = await showDialog<TicketLine>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (_) => CustomizationModal(
        item: menuItem!,
        initialLine: line,
      ),
    );

    if (updatedLine == null) return;

    setState(() {
      _ticketLines[targetIndex] = updatedLine;
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

  void _repriseOrder() {
    if (_ticketLines.isEmpty && (_orderNotes == null || _orderNotes!.isEmpty)) return;
    final backupLines = List<TicketLine>.from(_ticketLines);
    final backupNotes = _orderNotes;
    setState(() {
      _ticketLines.clear();
      _selectedLineIndex = null;
      _orderNotes = null;
    });
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Commande réinitialisée — tous les articles ont été supprimés'),
        action: SnackBarAction(
          label: 'ANNULER',
          textColor: AppColors.gold,
          onPressed: () {
            setState(() {
              _ticketLines.addAll(backupLines);
              _orderNotes = backupNotes;
              _selectedLineIndex =
                  _ticketLines.isNotEmpty ? _ticketLines.length - 1 : null;
            });
          },
        ),
      ),
    );
  }

  Future<void> _openCommentDialog() async {
    final controller = TextEditingController(text: _orderNotes ?? '');
    final result = await showDialog<String?>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          actionsPadding: const EdgeInsets.all(16),
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.chat_bubble,
                    size: 16, color: AppColors.brandDark),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'NOTE CUISINE / COMMENTAIRE',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ce commentaire sera visible en cuisine et imprimé sur le bon de commande.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                autofocus: true,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText:
                      'Ex: Sans sel sur les frites, bien cuit, allergie...',
                  hintStyle:
                      const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.brandDark, width: 2),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFFAFAF9),
                ),
              ),
            ],
          ),
          actions: [
            if (_orderNotes != null && _orderNotes!.isNotEmpty)
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(''),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Text('Effacer',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
              child: const Text('Annuler',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Text('Enregistrer',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );

    if (result != null) {
      setState(() {
        _orderNotes = result.isEmpty ? null : result;
      });
    }
  }

  Future<void> _sendToKitchen() async {
    if (_submitting || _ticketLines.isEmpty) return;
    setState(() => _submitting = true);
    // show loader
    showDialog<void>(context: context, barrierDismissible: false, builder: (_) => const PopScope(canPop: false, child: Center(child: CircularProgressIndicator())));
    try {
      final created = await _orderService.createOrder(
        lines: _ticketLines,
        orderType: _orderType,
        expectedTotal: _total,
        tableNumber: _tableNumber,
        clientName: null,
        deliveryAddress: null,
        deliveryPhone: null,
        notes: _orderNotes,
      );
      // Dispatch to kitchen queue — moves order from en_cours → en_attente
      // which makes it visible in KDS and in the history EN ATTENTE tab.
      await _orderService.updateStatus(created.id, 'en_attente');
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // close loader
      final savedTable = _tableNumber;
      setState(() {
        _ticketLines.clear();
        _selectedLineIndex = null;
        _orderNotes = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: const Color(0xFF059669),
        content: Text('Commande${savedTable != null ? ' table $savedTable' : ''} envoyée en cuisine !'),
      ));
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Erreur : $e'),
        ));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _buildTableSelector() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Text('TABLE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.5)),
          const SizedBox(width: 10),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 10,
              separatorBuilder: (context, index) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final t = '${i + 1}';
                final selected = _tableNumber == t;
                return GestureDetector(
                  onTap: () => setState(() => _tableNumber = selected ? null : t),
                  child: Container(
                    width: 36, height: 32,
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF2E1F0F) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: selected ? const Color(0xFF2E1F0F) : const Color(0xFFE5E7EB)),
                    ),
                    child: Center(
                      child: Text('T$t', style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: selected ? const Color(0xFFFBBF24) : const Color(0xFF374151),
                      )),
                    ),
                  ),
                );
              },
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
                const Text(
                  'SERVEUR',
                  style: TextStyle(
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
      width: 180,
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
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 160,
              mainAxisExtent: 160,
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
      width: 340,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          _buildTableSelector(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Text(
                  'Ticket N° $_ticketNumber',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
          if (_orderNotes != null && _orderNotes!.isNotEmpty)
            InkWell(
              onTap: _openCommentDialog,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble, size: 14, color: Color(0xFFB45309)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Note cuisine : $_orderNotes',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.edit, size: 13, color: Color(0xFFB45309)),
                  ],
                ),
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
                        onDoubleTap: () {
                          setState(() => _selectedLineIndex = index);
                          _editSelectedItem();
                        },
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
                  icon: Icons.edit_outlined,
                  color: const Color(0xFF059669),
                  bg: const Color(0xFFECFDF5),
                  tooltip: "Modifier l'article (sauces, options...)",
                  onTap: _editSelectedItem,
                ),
                const SizedBox(width: 8),
                _lineActionButton(
                  icon: Icons.chat_bubble,
                  color: (_orderNotes != null && _orderNotes!.isNotEmpty)
                      ? AppColors.brandDark
                      : const Color(0xFF4B5563),
                  bg: (_orderNotes != null && _orderNotes!.isNotEmpty)
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFF3F4F6),
                  onTap: _openCommentDialog,
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
                onPressed: (_ticketLines.isEmpty || _submitting)
                    ? null
                    : _sendToKitchen,
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
                    const Icon(
                      Icons.send,
                      color: Color(0xFFFBBF24),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'ENVOYER EN CUISINE',
                      style: GoogleFonts.bebasNeue(
                        fontSize: 22,
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
            child: SizedBox(
              width: double.infinity,
              height: 42,
              child: Row(
                children: [
                  Expanded(
                    child: _smallActionButton(
                      label: 'Historique',
                      icon: Icons.inventory_2_outlined,
                      bg: const Color(0xFF27272A),
                      fg: Colors.white,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => HistoryScreen(posteLabel: widget.posteLabel),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _smallActionButton(
                      label: 'Reprise',
                      icon: Icons.sync,
                      bg: const Color(0xFF452B1E),
                      fg: const Color(0xFFFBBF24),
                      onTap: _repriseOrder,
                    ),
                  ),
                ],
              ),
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
    String? tooltip,
  }) {
    Widget content = InkWell(
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
    );

    if (tooltip != null) {
      content = Tooltip(message: tooltip, child: content);
    }

    return Expanded(child: content);
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
