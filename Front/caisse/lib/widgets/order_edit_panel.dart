import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/order_models.dart';
import '../../models/pos_models.dart';
import '../../services/api_client.dart';
import '../../services/menu_service.dart';
import '../../services/order_service.dart';
import '../../theme/app_colors.dart';
import 'pos/customization_modal.dart';
import 'pos/menu_picker_modal.dart';
import 'pos/order_details_modal.dart';

class _ModeStyle {
  const _ModeStyle(this.label, this.bg, this.fg, this.dot);
  final String label;
  final Color bg;
  final Color fg;
  final Color dot;
}

/// Slide-in panel allowing the cashier to modify an ongoing order directly:
/// - Modify individual items in-place (sauces, options, removed ingredients)
/// - Remove items
/// - Adjust item quantities
/// - Add new items via the product catalog
/// - Modify table number and kitchen notes
/// - Save modifications to the backend, which flags the kitchen ticket as MODIFIÉ
class OrderEditPanel extends StatefulWidget {
  const OrderEditPanel({
    super.key,
    required this.order,
    required this.onClose,
    this.onOrderUpdated,
    this.posteLabel = 'Caisse Principale',
  });

  final HistoryOrder order;
  final VoidCallback onClose;
  final VoidCallback? onOrderUpdated;
  final String posteLabel;

  static const double preferredWidth = 560;

  @override
  State<OrderEditPanel> createState() => _OrderEditPanelState();
}

class _OrderEditPanelState extends State<OrderEditPanel> {
  final MenuService _menuService = MenuService();
  final OrderService _orderService = OrderService();

  late List<TicketLine> _lines;
  late OrderType _orderType;
  late String? _tableNumber;
  late String? _clientName;
  late String? _deliveryAddress;
  late String? _deliveryPhone;
  late String? _notes;

  List<MenuCategory> _categories = [];
  bool _loadingMenu = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _lines = widget.order.lines.asMap().entries.map((entry) {
      final line = entry.value.toTicketLine();
      final lineId = entry.value.id ?? 'line_${entry.key}';
      return line.copyWith(id: lineId);
    }).toList();
    _orderType = _orderTypeFromApi(widget.order.orderType);
    _tableNumber = widget.order.tableNumber ?? widget.order.buzzerNumber;
    _clientName = widget.order.clientName ?? widget.order.deliveryName;
    _deliveryAddress = widget.order.deliveryAddress;
    _deliveryPhone = widget.order.deliveryPhone;
    _notes = widget.order.notes;

    _loadMenu();
  }

  Future<void> _loadMenu() async {
    try {
      final categories = await _menuService.fetchMenu();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _loadingMenu = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadingMenu = false);
      }
    }
  }

  OrderType _orderTypeFromApi(String raw) {
    switch (raw) {
      case 'a_emporter':
        return OrderType.takeaway;
      case 'livraison':
        return OrderType.delivery;
      default:
        return OrderType.dineIn;
    }
  }

  String _two(int n) => n.toString().padLeft(2, '0');
  String _fmtDate(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';
  String _fmtTime(DateTime d) =>
      '${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}';
  String _euro(num v) => '${v.toStringAsFixed(2).replaceAll('.', ',')} DA';

  _ModeStyle _modeStyle(String type) {
    switch (type) {
      case 'a_emporter':
        return const _ModeStyle('À emporter', Color(0xFFDBEAFE),
            Color(0xFF1E40AF), Color(0xFF2563EB));
      case 'livraison':
        return const _ModeStyle('Livraison', Color(0xFFCCFBF1),
            Color(0xFF115E59), Color(0xFF0D9488));
      default:
        return const _ModeStyle('Sur place', Color(0xFFFFE4E6),
            Color(0xFF9F1239), Color(0xFFE11D48));
    }
  }

  double get _totalTTC => _lines.fold(0.0, (sum, l) => sum + l.total);

  // ────────────────────────── In-place customization ──────────────────────────

  MenuItem? _findMenuItemForLine(TicketLine line) {
    if (line.productId != null && line.productId!.isNotEmpty) {
      for (final cat in _categories) {
        for (final it in cat.items) {
          if (it.id == line.productId) return it;
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
          CustomizationOption(label: 'Blanche', priceModifier: 0),
          CustomizationOption(label: 'Andalouse', priceModifier: 0),
          CustomizationOption(label: 'Harissa', priceModifier: 0),
        ],
      ),
    ];
  }

  Future<void> _modifyLine(int index) async {
    final line = _lines[index];
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

    if (updatedLine != null && mounted) {
      setState(() {
        _lines[index] = updatedLine;
      });
    }
  }

  void _removeLine(int index) {
    final removed = _lines[index];
    setState(() {
      _lines.removeAt(index);
    });
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        showCloseIcon: true,
        closeIconColor: Colors.white,
        content: Text('${removed.name} supprimé'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'ANNULER',
          textColor: AppColors.gold,
          onPressed: () {
            if (mounted) {
              setState(() {
                _lines.insert(index, removed);
              });
            }
          },
        ),
      ),
    );
  }

  void _changeQuantity(int index, int delta) {
    final current = _lines[index];
    final newQty = current.quantity + delta;
    if (newQty <= 0) {
      _removeLine(index);
    } else {
      setState(() {
        current.quantity = newQty;
      });
    }
  }

  Future<void> _openAddProductCatalog() async {
    final newLine = await showDialog<TicketLine>(
      context: context,
      builder: (_) => MenuPickerModal(categories: _categories),
    );

    if (newLine != null && mounted) {
      final lineWithId = newLine.copyWith(
        id: 'new_${DateTime.now().microsecondsSinceEpoch}_${_lines.length}',
      );
      setState(() {
        _lines.add(lineWithId);
      });
    }
  }

  // ────────────────────────── Edit Order Details ──────────────────────────

  String _orderTypeToApi(OrderType t) {
    switch (t) {
      case OrderType.dineIn:
        return 'sur_place';
      case OrderType.takeaway:
        return 'a_emporter';
      case OrderType.delivery:
        return 'livraison';
    }
  }

  Future<void> _openOrderDetailsDialog([OrderType? targetType]) async {
    final details = await showDialog<OrderDetailsResult>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (_) => OrderDetailsModal(
        orderType: targetType ?? _orderType,
        ticketNumber: widget.order.ticketNumber,
        posteLabel: widget.posteLabel,
        initialNotes: _notes,
        initialTable: _tableNumber,
        initialClient: _clientName,
        initialAddress: _deliveryAddress,
        initialPhone: _deliveryPhone,
        currentTicketNumber: widget.order.ticketNumber,
        submitLabel: 'ENREGISTRER LES INFORMATIONS',
      ),
    );

    if (details != null && mounted) {
      setState(() {
        if (details.orderType != null) {
          _orderType = details.orderType!;
        }
        if (details.tableNumber != null && details.tableNumber!.isNotEmpty) {
          _tableNumber = details.tableNumber;
        }
        if (details.clientName != null) {
          _clientName = details.clientName;
        }
        if (details.deliveryPhone != null) {
          _deliveryPhone = details.deliveryPhone;
        }
        if (details.deliveryAddress != null) {
          _deliveryAddress = details.deliveryAddress;
        }
        if (details.notes != null) {
          _notes = details.notes!.isEmpty ? null : details.notes;
        }
      });
    }
  }

  Future<void> _editClientDialog() async {
    final controller = TextEditingController(text: _clientName ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.person_outline, color: AppColors.brandDark),
            SizedBox(width: 8),
            Text('Nom du Client', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Indiquez le nom du client :',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Ex: Karim / Thomas B.',
                prefixIcon: const Icon(Icons.person, size: 20),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _clientName = result.isEmpty ? null : result;
      });
    }
  }

  Future<void> _editPhoneDialog() async {
    final controller = TextEditingController(text: _deliveryPhone ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.phone_outlined, color: AppColors.brandDark),
            SizedBox(width: 8),
            Text('Numéro de Téléphone', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Indiquez le numéro de téléphone :',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Ex: 06 12 34 56 78 / 0555 12 34 56',
                prefixIcon: const Icon(Icons.phone, size: 20),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _deliveryPhone = result.isEmpty ? null : result;
      });
    }
  }

  Future<void> _editAddressDialog() async {
    final controller = TextEditingController(text: _deliveryAddress ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.location_on_outlined, color: AppColors.brandDark),
            SizedBox(width: 8),
            Text('Adresse', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Indiquez l\'adresse pour cette commande :',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Rue, bâtiment, étage...',
                prefixIcon: const Icon(Icons.location_on, size: 20),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _deliveryAddress = result.isEmpty ? null : result;
      });
    }
  }

  Future<void> _editTableDialog() async {
    final controller = TextEditingController(text: _tableNumber ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.table_restaurant_outlined, color: AppColors.brandDark),
            SizedBox(width: 8),
            Text('Numéro de Table', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Indiquez le numéro de table pour cette commande :',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.text,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Ex: 12, T4, B3...',
                prefixIcon: const Icon(Icons.tag, size: 20),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _tableNumber = result.isEmpty ? null : result;
      });
    }
  }

  Future<void> _editNotesDialog() async {
    final controller = TextEditingController(text: _notes ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.chat_bubble_outline, color: Color(0xFFB45309)),
            SizedBox(width: 8),
            Text('Note Cuisine', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cette note sera imprimée sur le bon et affichée sur l\'écran cuisine :',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              maxLines: 3,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Ex: Sans sel, bien cuit, allergie arachides...',
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (_notes != null && _notes!.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(''),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Effacer la note'),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _notes = result.isEmpty ? null : result;
      });
    }
  }

  String _formatHistoryOptions(HistoryOrderLine it) {
    final parts = <String>[];
    if (it.options.isNotEmpty) parts.addAll(it.options);
    for (final r in it.removed) {
      final clean = r.replaceFirst(RegExp(r'^sans\s+', caseSensitive: false), '').trim();
      if (clean.isNotEmpty) parts.add('Sans $clean');
    }
    if (it.notes != null && it.notes!.trim().isNotEmpty) parts.add(it.notes!.trim());
    return parts.join(' • ');
  }

  String _formatTicketLineOptions(TicketLine l) {
    final parts = <String>[];
    for (final c in l.customizations) {
      for (final o in c.selectedOptions) {
        parts.add(o.label);
      }
    }
    for (final r in l.removedIngredients) {
      final clean = r.replaceFirst(RegExp(r'^sans\s+', caseSensitive: false), '').trim();
      if (clean.isNotEmpty) parts.add('Sans $clean');
    }
    if (l.notes != null && l.notes!.trim().isNotEmpty) parts.add(l.notes!.trim());
    return parts.join(' • ');
  }

  void _checkItemDifferences(
    HistoryOrderLine oldIt,
    TicketLine newIt,
    List<Map<String, dynamic>> changes,
  ) {
    final oldSumm = _formatHistoryOptions(oldIt);
    final newSumm = _formatTicketLineOptions(newIt);
    final detailsList = <String>[];

    if (oldIt.quantity != newIt.quantity) {
      detailsList.add('Quantité : ${oldIt.quantity}× ➔ ${newIt.quantity}×');
    }
    if (oldSumm != newSumm) {
      detailsList.add('Nouvelles options : ${newSumm.isNotEmpty ? newSumm : "Aucune"}');
    }

    if (detailsList.isNotEmpty) {
      changes.add({
        'action': 'modified',
        'text': 'Modifié : ${oldIt.name}',
        'details': detailsList.join(' • '),
      });
    }
  }

  List<Map<String, dynamic>> _computeChanges() {
    final changes = <Map<String, dynamic>>[];
    final initialLines = widget.order.lines;

    final matchedInitialIndices = <int>{};
    final matchedCurrentIndices = <int>{};

    // 1. First, match lines that have the exact same non-empty ID
    for (var i = 0; i < initialLines.length; i++) {
      final oldIt = initialLines[i];
      final oldId = oldIt.id;
      if (oldId == null || oldId.isEmpty) continue;

      for (var j = 0; j < _lines.length; j++) {
        if (matchedCurrentIndices.contains(j)) continue;
        final newIt = _lines[j];
        if (newIt.id != null && newIt.id == oldId) {
          matchedInitialIndices.add(i);
          matchedCurrentIndices.add(j);
          _checkItemDifferences(oldIt, newIt, changes);
          break;
        }
      }
    }

    // 2. Exact match fallback for remaining lines (same name and identical options)
    for (var i = 0; i < initialLines.length; i++) {
      if (matchedInitialIndices.contains(i)) continue;
      final oldIt = initialLines[i];
      final oldSumm = _formatHistoryOptions(oldIt);

      for (var j = 0; j < _lines.length; j++) {
        if (matchedCurrentIndices.contains(j)) continue;
        final newIt = _lines[j];
        final newSumm = _formatTicketLineOptions(newIt);

        if (oldIt.name.trim().toLowerCase() == newIt.name.trim().toLowerCase() && oldSumm == newSumm) {
          matchedInitialIndices.add(i);
          matchedCurrentIndices.add(j);
          if (oldIt.quantity != newIt.quantity) {
            changes.add({
              'action': 'modified',
              'text': '${oldIt.name} : Quantité modifiée (${oldIt.quantity}× ➔ ${newIt.quantity}×)',
              if (oldSumm.isNotEmpty) 'details': oldSumm,
            });
          }
          break;
        }
      }
    }

    // 3. Fallback matching remaining lines by product name
    for (var i = 0; i < initialLines.length; i++) {
      if (matchedInitialIndices.contains(i)) continue;
      final oldIt = initialLines[i];

      for (var j = 0; j < _lines.length; j++) {
        if (matchedCurrentIndices.contains(j)) continue;
        final newIt = _lines[j];

        if (oldIt.name.trim().toLowerCase() == newIt.name.trim().toLowerCase()) {
          matchedInitialIndices.add(i);
          matchedCurrentIndices.add(j);
          _checkItemDifferences(oldIt, newIt, changes);
          break;
        }
      }
    }

    // 4. Any initial items not matched were DELETED
    for (var i = 0; i < initialLines.length; i++) {
      if (!matchedInitialIndices.contains(i)) {
        final it = initialLines[i];
        final summ = _formatHistoryOptions(it);
        changes.add({
          'action': 'deleted',
          'text': 'Supprimé : ${it.quantity}× ${it.name}',
          if (summ.isNotEmpty) 'details': summ,
        });
      }
    }

    // 5. Any current items not matched were ADDED
    for (var j = 0; j < _lines.length; j++) {
      if (!matchedCurrentIndices.contains(j)) {
        final it = _lines[j];
        final summ = _formatTicketLineOptions(it);
        changes.add({
          'action': 'added',
          'text': 'Ajouté : ${it.quantity}× ${it.name}',
          if (summ.isNotEmpty) 'details': summ,
        });
      }
    }

    // 6. Table check
    final oldTable = widget.order.tableNumber ?? widget.order.buzzerNumber;
    final currentTable = _tableNumber;
    if (currentTable != null && currentTable.trim() != (oldTable ?? '').trim()) {
      changes.add({
        'action': 'table',
        'text': 'Table : ${oldTable != null && oldTable.trim().isNotEmpty ? oldTable.trim() : "Non assignée"} ➔ ${currentTable.trim()}',
      });
    }

    // 7. Mode check
    final oldTypeApi = widget.order.orderType;
    final newTypeApi = _orderTypeToApi(_orderType);
    if (newTypeApi != oldTypeApi) {
      final oldLabel = _modeStyle(oldTypeApi).label;
      final newLabel = _modeStyle(newTypeApi).label;
      changes.add({
        'action': 'general',
        'text': 'Mode : $oldLabel ➔ $newLabel',
      });
    }

    // 8. Client Name check
    final oldClient = (widget.order.clientName ?? widget.order.deliveryName ?? '').trim();
    final newClient = (_clientName ?? '').trim();
    if (newClient != oldClient) {
      changes.add({
        'action': 'general',
        'text': 'Client : ${oldClient.isNotEmpty ? oldClient : "Non assigné"} ➔ ${newClient.isNotEmpty ? newClient : "Non assigné"}',
      });
    }

    // 9. Phone check
    final oldPhone = (widget.order.deliveryPhone ?? '').trim();
    final newPhone = (_deliveryPhone ?? '').trim();
    if (newPhone != oldPhone) {
      changes.add({
        'action': 'general',
        'text': 'Téléphone : ${oldPhone.isNotEmpty ? oldPhone : "Non renseigné"} ➔ ${newPhone.isNotEmpty ? newPhone : "Non renseigné"}',
      });
    }

    // 10. Address check
    final oldAddr = (widget.order.deliveryAddress ?? '').trim();
    final newAddr = (_deliveryAddress ?? '').trim();
    if (newAddr != oldAddr) {
      changes.add({
        'action': 'general',
        'text': 'Adresse : ${oldAddr.isNotEmpty ? oldAddr : "Non renseignée"} ➔ ${newAddr.isNotEmpty ? newAddr : "Non renseignée"}',
      });
    }

    // 11. Notes check
    final oldNote = (widget.order.notes ?? '').trim();
    final newNote = (_notes ?? '').trim();
    if (newNote != oldNote) {
      changes.add({
        'action': 'note',
        'text': newNote.isNotEmpty ? 'Note cuisine : "$newNote"' : 'Note cuisine supprimée',
      });
    }

    return changes;
  }

  List<Map<String, dynamic>> _mergeModifications(
    List<OrderModification> existing,
    List<Map<String, dynamic>> newChanges,
  ) {
    if (newChanges.isEmpty) {
      return existing
          .map((e) => <String, dynamic>{
                'action': e.action,
                'text': e.text,
                if (e.details != null && e.details!.isNotEmpty)
                  'details': e.details,
              })
          .toList();
    }

    final result = existing
        .map((e) => <String, dynamic>{
              'action': e.action,
              'text': e.text,
              if (e.details != null && e.details!.isNotEmpty)
                'details': e.details,
            })
        .toList();

    String cleanItemName(String text) {
      return text
          .replaceFirst(
              RegExp(r'^(?:Modifié|Supprimé|Ajouté)\s*:\s*',
                  caseSensitive: false),
              '')
          .replaceFirst(RegExp(r'^\d+×\s*'), '')
          .replaceFirst(
              RegExp(r'\s*:\s*Quantité modifiée.*$', caseSensitive: false), '')
          .trim()
          .toLowerCase();
    }

    for (final inc in newChanges) {
      final incText = inc['text']?.toString() ?? '';
      final incAction = inc['action']?.toString() ?? 'modified';
      final incDetails = inc['details']?.toString();

      if (incText.isEmpty) continue;

      // Duplicate check
      final isDup = result.any((e) =>
          e['action'] == incAction &&
          e['text'] == incText &&
          (e['details'] ?? '') == (incDetails ?? ''));
      if (isDup) continue;

      // General action: update existing general change with same prefix if present
      if (incAction == 'general') {
        final prefix = incText.split(' : ')[0];
        final genIdx = result.indexWhere((e) =>
            e['action'] == 'general' &&
            (e['text']?.toString() ?? '').startsWith('$prefix : '));
        if (genIdx != -1) {
          result[genIdx] = inc;
        } else {
          result.add(inc);
        }
        continue;
      }

      // Table action: replace existing table change with new one
      if (incAction == 'table') {
        final tableIdx = result.indexWhere((e) => e['action'] == 'table');
        if (tableIdx != -1) {
          final oldMatch = RegExp(r'Table\s*:\s*([^➔]+)➔', caseSensitive: false)
              .firstMatch(result[tableIdx]['text']?.toString() ?? '');
          final newMatch = RegExp(r'➔\s*(.+)$').firstMatch(incText);
          if (oldMatch != null && newMatch != null) {
            result[tableIdx] = {
              'action': 'table',
              'text':
                  'Table : ${oldMatch.group(1)!.trim()} ➔ ${newMatch.group(1)!.trim()}',
            };
          } else {
            result[tableIdx] = inc;
          }
        } else {
          result.add(inc);
        }
        continue;
      }

      // Note action: replace existing note change with new one
      if (incAction == 'note') {
        final noteIdx = result.indexWhere((e) => e['action'] == 'note');
        if (noteIdx != -1) {
          result[noteIdx] = inc;
        } else {
          result.add(inc);
        }
        continue;
      }

      // Item actions: check by product name
      final incProd = cleanItemName(incText);
      if (incProd.isNotEmpty) {
        // If deleted, check if this item was previously marked as added
        final addedIdx = result.indexWhere((e) =>
            e['action'] == 'added' &&
            cleanItemName(e['text']?.toString() ?? '') == incProd);
        if (incAction == 'deleted' && addedIdx != -1) {
          result[addedIdx] = {
            'action': 'deleted',
            'text': 'Supprimé : $incProd (Annulé)',
            if (incDetails != null || result[addedIdx]['details'] != null)
              'details': incDetails ?? result[addedIdx]['details'],
          };
          continue;
        }

        // If modified, check if this item was already modified
        final modIdx = result.indexWhere((e) =>
            e['action'] == 'modified' &&
            cleanItemName(e['text']?.toString() ?? '') == incProd);
        if (incAction == 'modified' && modIdx != -1) {
          result[modIdx] = inc;
          continue;
        }

        // If deleted, check if this item was previously modified
        if (incAction == 'deleted' && modIdx != -1) {
          result.removeAt(modIdx);
          result.add(inc);
          continue;
        }
      }

      result.add(inc);
    }

    return result;
  }

  Future<void> _saveModifications() async {
    if (_saving) return;

    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La commande doit contenir au moins un article.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    // Verify essential attributes before saving modifications
    final bool hasEssential;
    switch (_orderType) {
      case OrderType.dineIn:
        hasEssential = _tableNumber != null && _tableNumber!.trim().isNotEmpty;
        break;
      case OrderType.takeaway:
        hasEssential = _clientName != null && _clientName!.trim().isNotEmpty &&
                       _deliveryPhone != null && _deliveryPhone!.trim().isNotEmpty;
        break;
      case OrderType.delivery:
        hasEssential = _clientName != null && _clientName!.trim().isNotEmpty &&
                       _deliveryPhone != null && _deliveryPhone!.trim().isNotEmpty &&
                       _deliveryAddress != null && _deliveryAddress!.trim().isNotEmpty;
        break;
    }

    if (!hasEssential) {
      await _openOrderDetailsDialog();
      if (!mounted) return;
      final bool stillMissing;
      switch (_orderType) {
        case OrderType.dineIn:
          stillMissing = _tableNumber == null || _tableNumber!.trim().isEmpty;
          break;
        case OrderType.takeaway:
          stillMissing = _clientName == null || _clientName!.trim().isEmpty ||
                         _deliveryPhone == null || _deliveryPhone!.trim().isEmpty;
          break;
        case OrderType.delivery:
          stillMissing = _clientName == null || _clientName!.trim().isEmpty ||
                         _deliveryPhone == null || _deliveryPhone!.trim().isEmpty ||
                         _deliveryAddress == null || _deliveryAddress!.trim().isEmpty;
          break;
      }
      if (stillMissing) return;
    }

    setState(() => _saving = true);

    try {
      final sessionDiff = _computeChanges();
      final mergedSummary = _mergeModifications(
        widget.order.modificationSummary,
        sessionDiff,
      );

      await _orderService.updateOrder(
        orderId: widget.order.id,
        lines: _lines,
        orderType: _orderType,
        expectedTotal: _totalTTC,
        tableNumber: _tableNumber,
        clientName: _clientName,
        deliveryAddress: _deliveryAddress,
        deliveryPhone: _deliveryPhone,
        notes: _notes,
        modificationSummary: mergedSummary,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          showCloseIcon: true,
          closeIconColor: Colors.white,
          content: Text(
            'Commande #${widget.order.ticketNumber} mise à jour avec succès.',
          ),
          backgroundColor: const Color(0xFF059669),
        ),
      );

      widget.onOrderUpdated?.call();
      widget.onClose();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'Erreur lors de la mise à jour : $e',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  // ────────────────────────── Build ──────────────────────────

  @override
  Widget build(BuildContext context) {
    final mode = _modeStyle(widget.order.orderType);

    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoCard(mode),
                const SizedBox(height: 16),
                _buildKitchenNotesCard(),
                const SizedBox(height: 16),
                _buildItemsCard(),
              ],
            ),
          ),
        ),
        _buildFooter(),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    Text(
                      'MODIFIER COMMANDE #${widget.order.ticketNumber}',
                      style: GoogleFonts.bebasNeue(
                        color: AppColors.brandDark,
                        fontSize: 24,
                        fontWeight: FontWeight.w400,
                        height: 32 / 24,
                        letterSpacing: 0.6,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF59E0B)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit, size: 12, color: Color(0xFF92400E)),
                          SizedBox(width: 4),
                          Text(
                            'MODIFICATION',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close, size: 16, color: Color(0xFF6B7280)),
                label: const Text(
                  'Fermer',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'SprintKitchen POS • Modifications appliquées en temps réel',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab(
    OrderType type,
    String label,
    Color color,
    IconData icon,
  ) {
    final bool isSelected = _orderType == type;
    return Expanded(
      child: InkWell(
        onTap: () {
          if (isSelected) {
            _openOrderDetailsDialog();
          } else {
            _openOrderDetailsDialog(type);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? color : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE5E7EB),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected ? Colors.white : const Color(0xFF4B5563),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF374151),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────── Info Card ──────────────────────────

  Widget _buildInfoCard(_ModeStyle mode) {
    final clientDisplay = (_clientName != null && _clientName!.trim().isNotEmpty)
        ? _clientName!
        : 'Cliquer pour renseigner';

    String tableDisplay = 'Cliquer pour assigner';
    if (_tableNumber != null && _tableNumber!.trim().isNotEmpty) {
      final cleaned = _tableNumber!
          .replaceAll(RegExp(r'^(buzzer\s*#?|table\s*)', caseSensitive: false), '')
          .trim();
      tableDisplay = cleaned.isNotEmpty ? 'Table $cleaned' : 'Table';
    }

    final bool showDeliveryOrContact = _orderType == OrderType.delivery ||
        _orderType == OrderType.takeaway ||
        (_deliveryPhone != null && _deliveryPhone!.isNotEmpty) ||
        (_deliveryAddress != null && _deliveryAddress!.isNotEmpty);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _infoCell(
                  Icons.schedule,
                  'DATE & HEURE',
                  '${_fmtDate(widget.order.createdAt)} à ${_fmtTime(widget.order.createdAt)}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MODE (CLIQUER POUR CHANGER)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF9CA3AF),
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildModeTab(OrderType.dineIn, 'Sur place', const Color(0xFFE11D48), Icons.restaurant_rounded),
                        const SizedBox(width: 4),
                        _buildModeTab(OrderType.takeaway, 'Emporter', const Color(0xFF2563EB), Icons.shopping_bag_outlined),
                        const SizedBox(width: 4),
                        _buildModeTab(OrderType.delivery, 'Livraison', const Color(0xFF0D9488), Icons.moped_rounded),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFF3F4F6)),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  onTap: _editClientDialog,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _infoCell(
                            Icons.person_outline,
                            'NOM DU CLIENT (MODIFIABLE)',
                            clientDisplay,
                          ),
                        ),
                        const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF2563EB)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: _editTableDialog,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _infoCell(
                            Icons.table_restaurant_outlined,
                            'TABLE (MODIFIABLE)',
                            tableDisplay,
                          ),
                        ),
                        const Icon(Icons.edit_outlined, size: 15, color: Color(0xFFD97706)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (showDeliveryOrContact) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0xFFF3F4F6)),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _editPhoneDialog,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _infoCell(
                              Icons.phone_outlined,
                              'TÉLÉPHONE (MODIFIABLE)',
                              (_deliveryPhone != null && _deliveryPhone!.isNotEmpty)
                                  ? _deliveryPhone!
                                  : 'Cliquer pour renseigner',
                            ),
                          ),
                          const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF2563EB)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _editAddressDialog,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _infoCell(
                              Icons.location_on_outlined,
                              'ADRESSE (MODIFIABLE)',
                              (_deliveryAddress != null && _deliveryAddress!.isNotEmpty)
                                  ? _deliveryAddress!
                                  : 'Cliquer pour renseigner',
                            ),
                          ),
                          const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF2563EB)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _openOrderDetailsDialog(),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.tune, size: 14, color: Color(0xFF2563EB)),
                  SizedBox(width: 6),
                  Text(
                    'Modifier tous les attributs / type de commande',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E40AF),
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

  Widget _buildKitchenNotesCard() {
    final hasNote = _notes != null && _notes!.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.chat_bubble_outline, size: 20, color: Color(0xFFB45309)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NOTE CUISINE / COMMENTAIRE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Color(0xFFB45309),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasNote ? _notes! : 'Aucune note cuisine pour le moment.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: hasNote ? const Color(0xFF78350F) : const Color(0xFF92400E).withValues(alpha: 0.7),
                    fontStyle: hasNote ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _editNotesDialog,
            icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFFB45309)),
            tooltip: 'Modifier la note cuisine',
          ),
        ],
      ),
    );
  }

  Widget _infoCell(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF9CA3AF),
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(icon, size: 13, color: const Color(0xFF9CA3AF)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }



  // ────────────────────────── Items Card ──────────────────────────

  Widget _buildItemsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7E5E4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ARTICLES DE LA COMMANDE (${_lines.length})',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF57534E),
              letterSpacing: 0.5,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFE5E7EB)),
          ),
          if (_lines.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.remove_shopping_cart_outlined,
                      size: 36, color: Color(0xFF9CA3AF)),
                  const SizedBox(height: 8),
                  const Text(
                    'Aucun article dans cette commande.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _openAddProductCatalog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandDark,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Choisir un article'),
                  ),
                ],
              ),
            )
          else
            for (var i = 0; i < _lines.length; i++) ...[
              _editableLineItem(i, _lines[i]),
              if (i != _lines.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: Color(0xFFF3F4F6)),
                ),
            ],
          const SizedBox(height: 14),
          // Prominent Add Item button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _loadingMenu ? null : _openAddProductCatalog,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.brandDark,
                side: const BorderSide(color: Color(0xFFD6D3D1), width: 1.5),
                backgroundColor: const Color(0xFFFAFAF9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add_circle_outline, size: 18, color: AppColors.brandDark),
              label: const Text(
                'AJOUTER UN ARTICLE AU TICKET',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: Color(0xFFE5E7EB)),
          ),
          _totalRow('NOUVEAU TOTAL', _euro(_totalTTC), bold: true),
          if ((_totalTTC - widget.order.totalTTC).abs() > 0.01) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: (_totalTTC > widget.order.totalTTC)
                    ? const Color(0xFFFEF3C7)
                    : const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ancien total : ${_euro(widget.order.totalTTC)}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563)),
                  ),
                  Text(
                    'Écart : ${(_totalTTC - widget.order.totalTTC) > 0 ? "+" : ""}${_euro(_totalTTC - widget.order.totalTTC)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: (_totalTTC > widget.order.totalTTC)
                          ? const Color(0xFFB45309)
                          : const Color(0xFF047857),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _editableLineItem(int index, TicketLine l) {
    final subLines = <Widget>[];

    for (final c in l.customizations) {
      for (final opt in c.selectedOptions) {
        subLines.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              '• ${opt.label}${opt.priceModifier > 0 ? " (+${_euro(opt.priceModifier)})" : ""}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
            ),
          ),
        );
      }
    }

    for (final rem in l.removedIngredients) {
      final clean = rem.replaceFirst(RegExp(r'^sans\s+', caseSensitive: false), '').trim();
      subLines.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text(
            '• Sans $clean',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFFB45309),
            ),
          ),
        ),
      );
    }

    if (l.notes != null && l.notes!.isNotEmpty) {
      subLines.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text(
            l.notes!,
            style: const TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quantity Stepper
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => _changeQuantity(index, -1),
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.remove, size: 14, color: Color(0xFF374151)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '${l.quantity}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              InkWell(
                onTap: () => _changeQuantity(index, 1),
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.add, size: 14, color: Color(0xFF374151)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // Item Name & Customizations
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.name,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              if (subLines.isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.only(left: 8),
                  decoration: const BoxDecoration(
                    border: Border(
                      left: BorderSide(color: AppColors.gold, width: 3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: subLines,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Action Buttons: Edit sauces & Remove item
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => _modifyLine(index),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Tooltip(
                  message: 'Modifier sauces & options',
                  child: Icon(Icons.edit_outlined, size: 16, color: Color(0xFFB45309)),
                ),
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: () => _removeLine(index),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: const Tooltip(
                  message: 'Supprimer l\'article',
                  child: Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        // Line Price
        SizedBox(
          width: 65,
          child: Text(
            _euro(l.total),
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _totalRow(String label, String value, {bool bold = false}) {
    final style = TextStyle(
      fontSize: bold ? 20 : 13,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      color: bold ? AppColors.brandDark : const Color(0xFF111827),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: style), Text(value, style: style)],
    );
  }

  // ────────────────────────── Footer ──────────────────────────

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _saving || _lines.isEmpty ? null : _saveModifications,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF059669).withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline, size: 20),
              label: Text(
                _saving ? 'ENREGISTREMENT...' : 'ENREGISTRER LA MODIFICATION',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton(
              onPressed: _saving ? null : widget.onClose,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4B5563),
                side: const BorderSide(color: Color(0xFFD1D5DB)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Annuler les modifications', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper function to open [OrderEditPanel] sliding in from the right edge.
void showOrderEditPanel(
  BuildContext context,
  HistoryOrder order, {
  VoidCallback? onOrderUpdated,
  String posteLabel = 'Caisse Principale',
}) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fermer',
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, anim, secondaryAnim) {
      final panelWidth = math.min(
        OrderEditPanel.preferredWidth,
        MediaQuery.sizeOf(ctx).width,
      );
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Colors.white,
          elevation: 24,
          child: SizedBox(
            width: panelWidth,
            height: double.infinity,
            child: OrderEditPanel(
              order: order,
              onClose: () => Navigator.of(ctx).pop(),
              onOrderUpdated: onOrderUpdated,
              posteLabel: posteLabel,
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim, secondaryAnim, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(curved),
        child: child,
      );
    },
  );
}
