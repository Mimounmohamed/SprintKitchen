import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/pos_models.dart';
import '../theme/app_colors.dart';
import '../widgets/pos/category_sidebar_item.dart';
import '../widgets/pos/menu_item_tile.dart';
import '../widgets/pos/ticket_line_tile.dart';
import '../widgets/pos/customization_modal.dart';
import '../services/api_client.dart' show ApiException;
import '../services/menu_service.dart';
import '../services/order_service.dart';
import '../widgets/pos/encaissement_modal.dart';
import '../widgets/pos/order_details_modal.dart';
import '../models/order_models.dart' show HistoryOrder;
import '../services/receipt_printer_service.dart';
import '../widgets/receipt_preview_dialog.dart';
import 'history_screen.dart';

/// The POS / register screen ("SprintKitchen POS - Caisse Principale").
///
/// Drop into lib/screens/pos_screen.dart and navigate to it from the
/// Hub screen's "New Order / Register" card.
class PosScreen extends StatefulWidget {
  const PosScreen({
    super.key,
    this.ticketNumber = '000001',
    this.posteLabel = 'Caisse 01',
    this.editingOrder,
  });

  final String ticketNumber;
  final String posteLabel;
  final HistoryOrder? editingOrder;

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
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

  /// Current ticket number (starts from the widget value, then follows the
  /// number returned by the server after each paid order).
  late String _ticketNumber;

  /// True while an order/payment request is in flight (blocks double taps).
  bool _submitting = false;

  /// Order created on the server but not yet paid (kept so a retry after a
  /// payment failure does not create a duplicate order).
  CreatedOrder? _pendingOrder;

  /// Table number / client name / delivery info the cashier entered for the
  /// order currently in flight. Cleared together with [_pendingOrder]: once
  /// an order exists server-side its details are already saved, so a retry
  /// after a payment failure skips straight to the payment modal instead of
  /// asking again.
  OrderDetailsResult? _orderDetails;

  /// Optional kitchen note / comment for the current order.
  String? _orderNotes;

  /// Order currently being modified from HistoryScreen (if any).
  HistoryOrder? _editingOrder;
  bool get _isEditing => _editingOrder != null;

  @override
  void initState() {
    super.initState();
    _ticketNumber = widget.ticketNumber;
    if (widget.editingOrder != null) {
      _loadOrderForEditing(widget.editingOrder!);
    }
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

    // No hardcoded fallback: sauces only come from the "Sauces" category.
    return const [];
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
      _pendingOrder = null;
      _orderDetails = null;
      _orderNotes = null;
    });
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        showCloseIcon: true,
        closeIconColor: Colors.white,
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

  // ───────────────────────── Encaissement flow ─────────────────────────

  Future<void> _openEncaissement() async {
    if (_submitting) return;

    // Check if essential attributes for the current order type are already set
    if (_pendingOrder == null) {
      final bool hasEssential;
      switch (_orderType) {
        case OrderType.dineIn:
          hasEssential = _orderDetails?.tableNumber != null && _orderDetails!.tableNumber!.isNotEmpty;
          break;
        case OrderType.takeaway:
          hasEssential = _orderDetails?.clientName != null && _orderDetails!.clientName!.isNotEmpty &&
                         _orderDetails?.deliveryPhone != null && _orderDetails!.deliveryPhone!.isNotEmpty;
          break;
        case OrderType.delivery:
          hasEssential = _orderDetails?.clientName != null && _orderDetails!.clientName!.isNotEmpty &&
                         _orderDetails?.deliveryPhone != null && _orderDetails!.deliveryPhone!.isNotEmpty &&
                         _orderDetails?.deliveryAddress != null && _orderDetails!.deliveryAddress!.isNotEmpty;
          break;
      }

      if (!hasEssential) {
        final details = await showDialog<OrderDetailsResult>(
          context: context,
          barrierColor: Colors.transparent,
          builder: (_) => OrderDetailsModal(
            orderType: _orderType,
            ticketNumber: _ticketNumber,
            posteLabel: widget.posteLabel,
            initialNotes: _orderNotes,
            initialTable: _orderDetails?.tableNumber ?? _editingOrder?.tableNumber,
            initialClient: _orderDetails?.clientName ?? _editingOrder?.clientName,
            initialAddress: _orderDetails?.deliveryAddress ?? _editingOrder?.deliveryAddress,
            initialPhone: _orderDetails?.deliveryPhone ?? _editingOrder?.deliveryPhone,
            submitLabel: 'CONTINUER VERS LE PAIEMENT',
          ),
        );
        if (details == null || !mounted) return;
        setState(() {
          _orderType = details.orderType ?? _orderType;
          _orderDetails = details;
          if (details.notes != null) {
            _orderNotes = details.notes!.isEmpty ? null : details.notes;
          }
        });
      }
    }

    final result = await showDialog<EncaissementResult>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (_) => EncaissementModal(
        total: _total,
        ticketNumber: _ticketNumber,
        posteLabel: widget.posteLabel,
      ),
    );
    if (result == null || !mounted) return;
    await _submitOrder(result);
  }

  /// Runs order → payment, retrying on demand. The ticket is only cleared
  /// after BOTH calls succeed.
  Future<void> _submitOrder(EncaissementResult result) async {
    setState(() => _submitting = true);
    try {
      while (true) {
        final failure = await _attempt(result);
        if (failure == null) return; // success handled in _attempt
        if (!mounted) return;
        if (failure.message.contains('occupée') || failure.message.contains('déjà liée')) {
          _pendingOrder = null;
          _orderDetails = null;
          await _showTableOccupiedError(failure);
          return;
        }
        final retry = await _showPaymentError(failure);
        if (!retry) {
          // Cashier backed out: forget the pending order (and its details)
          // so an edited ticket gets a fresh order instead of reusing a
          // stale one.
          _pendingOrder = null;
          _orderDetails = null;
          return;
        }
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// One full attempt. Returns null on success, or the failure.
  Future<ApiException?> _attempt(EncaissementResult result) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    ApiException? failure;
    CreatedOrder? paid;
    try {
      // Reuse the order if a previous attempt created it but payment failed.
      _pendingOrder ??= await _orderService.createOrder(
        lines: _ticketLines,
        orderType: _orderType,
        expectedTotal: _total,
        tableNumber: _orderDetails?.tableNumber,
        clientName: _orderDetails?.clientName,
        deliveryAddress: _orderDetails?.deliveryAddress,
        deliveryPhone: _orderDetails?.deliveryPhone,
        notes: _orderNotes,
      );
      await _orderService.createPayment(
        orderId: _pendingOrder!.id,
        method: result.method,
        amountReceived: result.amountReceived,
        printReceipt: result.printReceipt,
      );
      paid = _pendingOrder;
    } on ApiException catch (e) {
      failure = e;
    } catch (e) {
      failure = ApiException(e.toString());
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop(); // loader
    }

    if (failure != null || !mounted) return failure;

    // Build printable receipt data before clearing form state
    final receiptTicketNumber = paid?.ticketNumber ?? _ticketNumber;
    final receiptTableNumber = _orderDetails?.tableNumber;
    final receiptClientName = _orderDetails?.clientName;
    final receiptDeliveryAddress = _orderDetails?.deliveryAddress;
    final receiptDeliveryPhone = _orderDetails?.deliveryPhone;
    final receiptNotes = _orderNotes;
    final receiptLines = List<TicketLine>.from(_ticketLines);
    final receiptOrderType = _orderType;

    _pendingOrder = null;
    _orderDetails = null;

    final receiptData = PrintableReceiptData.fromPosTicket(
      ticketNumber: receiptTicketNumber,
      lines: receiptLines,
      orderType: receiptOrderType,
      tableNumber: receiptTableNumber,
      clientName: receiptClientName,
      deliveryAddress: receiptDeliveryAddress,
      deliveryPhone: receiptDeliveryPhone,
      notes: receiptNotes,
      paymentMethod: result.method == PaymentMethod.especes ? 'Espèces' : 'Carte Bancaire',
      amountReceived: result.amountReceived,
      change: result.change,
      serverName: widget.posteLabel,
    );

    // Direct / Silent printing to the connected printer
    if (result.printReceipt) {
      ReceiptPrinterService.printClientReceiptDirect(receiptData);
    }
    if (result.printKitchenReceipt) {
      ReceiptPrinterService.printKitchenReceiptDirect(receiptData);
    }

    setState(() {
      _ticketLines.clear();
      _selectedLineIndex = null;
      _orderNotes = null;
      _ticketNumber = _nextTicketNumber(paid!.ticketNumber);
    });

    final printNotice = result.printReceipt && result.printKitchenReceipt
        ? ' (Tickets client et cuisine envoyés)'
        : result.printReceipt
            ? ' (Ticket client envoyé)'
            : result.printKitchenReceipt
                ? ' (Bon cuisine envoyé)'
                : '';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        showCloseIcon: true,
        closeIconColor: Colors.white,
        content: Text(
          (result.method == PaymentMethod.especes
              ? 'Paiement espèces enregistré — rendu ${result.change.toStringAsFixed(2).replaceAll('.', ',')} DA'
              : 'Paiement carte enregistré') + printNotice,
        ),
        backgroundColor: const Color(0xFF059669),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'VOIR TICKET',
          textColor: Colors.white,
          onPressed: () {
            ReceiptPreviewDialog.show(context, receiptData);
          },
        ),
      ),
    );
    return null;
  }

  Future<bool> _showPaymentError(ApiException e) async {
    final orderNote = _pendingOrder != null
        ? '\n\nLa commande est créée : seul le paiement reste à enregistrer.'
        : '';
    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Encaissement non enregistré'),
        content: Text('${e.message}\n\nLe ticket est conservé.$orderNote'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
    return retry ?? false;
  }

  Future<void> _showTableOccupiedError(ApiException e) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.table_restaurant_outlined, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Table indisponible'),
          ],
        ),
        content: Text(
          '${e.message}\n\nVeuillez choisir une autre table avant de procéder au paiement.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandDark,
              foregroundColor: Colors.white,
            ),
            child: const Text('Changer de table'),
          ),
        ],
      ),
    );
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

  void _loadOrderForEditing(HistoryOrder order) {
    setState(() {
      _editingOrder = order;
      _ticketNumber = order.ticketNumber;
      _orderType = _orderTypeFromApi(order.orderType);
      _orderNotes = order.notes;
      _orderDetails = OrderDetailsResult(
        orderType: _orderType,
        tableNumber: order.tableNumber ?? order.buzzerNumber,
        clientName: order.clientName ?? order.deliveryName,
        deliveryAddress: order.deliveryAddress,
        deliveryPhone: order.deliveryPhone,
        notes: order.notes,
      );
      _ticketLines.clear();
      for (final line in order.lines) {
        _ticketLines.add(line.toTicketLine());
      }
      _selectedLineIndex = _ticketLines.isNotEmpty ? 0 : null;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingOrder = null;
      _ticketLines.clear();
      _selectedLineIndex = null;
      _orderNotes = null;
      _orderDetails = null;
      _ticketNumber = widget.ticketNumber;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mode modification quitté.')),
    );
  }

  Future<void> _openEditOrderDetails() async {
    final details = await showDialog<OrderDetailsResult>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (_) => OrderDetailsModal(
        orderType: _orderType,
        ticketNumber: _ticketNumber,
        posteLabel: widget.posteLabel,
        initialNotes: _orderNotes,
        initialTable: _orderDetails?.tableNumber ?? _editingOrder?.tableNumber,
        initialClient: _orderDetails?.clientName ?? _editingOrder?.clientName,
        initialAddress: _orderDetails?.deliveryAddress ?? _editingOrder?.deliveryAddress,
        initialPhone: _orderDetails?.deliveryPhone ?? _editingOrder?.deliveryPhone,
        currentTicketNumber: _editingOrder?.ticketNumber,
        submitLabel: _isEditing ? 'ENREGISTRER LES MODIFICATIONS' : 'VALIDER LES INFORMATIONS',
      ),
    );
    if (details == null || !mounted) return;
    setState(() {
      _orderType = details.orderType ?? _orderType;
      _orderDetails = details;
      if (details.notes != null) {
        _orderNotes = details.notes!.isEmpty ? null : details.notes;
      }
    });
  }

  Future<void> _handleOrderTypeSelection(OrderType type) async {
    // If tapping the currently selected type, open the modal to view/edit its details
    if (_orderType == type) {
      await _openEditOrderDetails();
      return;
    }

    // Changing type: prompt for essential attributes for the new type
    final details = await showDialog<OrderDetailsResult>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (_) => OrderDetailsModal(
        orderType: type,
        ticketNumber: _ticketNumber,
        posteLabel: widget.posteLabel,
        initialNotes: _orderNotes,
        initialTable: _orderDetails?.tableNumber ?? _editingOrder?.tableNumber,
        initialClient: _orderDetails?.clientName ?? _editingOrder?.clientName,
        initialAddress: _orderDetails?.deliveryAddress ?? _editingOrder?.deliveryAddress,
        initialPhone: _orderDetails?.deliveryPhone ?? _editingOrder?.deliveryPhone,
        currentTicketNumber: _editingOrder?.ticketNumber,
        submitLabel: 'APPLIQUER LE TYPE & VALIDER',
      ),
    );

    if (details != null && mounted) {
      setState(() {
        _orderType = details.orderType ?? type;
        _orderDetails = details;
        if (details.notes != null) {
          _orderNotes = details.notes!.isEmpty ? null : details.notes;
        }
      });
    }
  }

  Color _orderTypeColor(OrderType type) {
    switch (type) {
      case OrderType.dineIn:
        return const Color(0xFFE11D48);
      case OrderType.takeaway:
        return const Color(0xFF2563EB);
      case OrderType.delivery:
        return const Color(0xFF0D9488);
    }
  }

  String _formatCurrentOrderSummary() {
    switch (_orderType) {
      case OrderType.dineIn:
        final tbl = _orderDetails?.tableNumber;
        final name = _orderDetails?.clientName;
        if (tbl != null && tbl.isNotEmpty) {
          return name != null && name.isNotEmpty ? 'Table $tbl ($name)' : 'Table $tbl';
        }
        return name != null && name.isNotEmpty ? 'Sur place ($name)' : 'Table non assignée (cliquer pour définir)';
      case OrderType.takeaway:
        final name = _orderDetails?.clientName;
        final phone = _orderDetails?.deliveryPhone;
        if (name != null && name.isNotEmpty) {
          return phone != null && phone.isNotEmpty ? '$name ($phone)' : name;
        }
        return 'Client à emporter (cliquer pour renseigner)';
      case OrderType.delivery:
        final name = _orderDetails?.clientName;
        final phone = _orderDetails?.deliveryPhone;
        final addr = _orderDetails?.deliveryAddress;
        if (addr != null && addr.isNotEmpty) {
          final parts = [if (name != null && name.isNotEmpty) name, if (phone != null && phone.isNotEmpty) phone, addr];
          return parts.join(' • ');
        }
        return 'Infos livraison requises (cliquer pour renseigner)';
    }
  }

  Future<void> _saveOrderModifications() async {
    if (_submitting || _editingOrder == null) return;
    if (_ticketLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le ticket ne peut pas être vide.')),
      );
      return;
    }

    // Verify essential attributes before saving modifications
    final bool hasEssential;
    switch (_orderType) {
      case OrderType.dineIn:
        hasEssential = _orderDetails?.tableNumber != null && _orderDetails!.tableNumber!.isNotEmpty;
        break;
      case OrderType.takeaway:
        hasEssential = _orderDetails?.clientName != null && _orderDetails!.clientName!.isNotEmpty &&
                       _orderDetails?.deliveryPhone != null && _orderDetails!.deliveryPhone!.isNotEmpty;
        break;
      case OrderType.delivery:
        hasEssential = _orderDetails?.clientName != null && _orderDetails!.clientName!.isNotEmpty &&
                       _orderDetails?.deliveryPhone != null && _orderDetails!.deliveryPhone!.isNotEmpty &&
                       _orderDetails?.deliveryAddress != null && _orderDetails!.deliveryAddress!.isNotEmpty;
        break;
    }

    if (!hasEssential) {
      await _openEditOrderDetails();
      if (!mounted) return;
      final bool stillMissing;
      switch (_orderType) {
        case OrderType.dineIn:
          stillMissing = _orderDetails?.tableNumber == null || _orderDetails!.tableNumber!.isEmpty;
          break;
        case OrderType.takeaway:
          stillMissing = _orderDetails?.clientName == null || _orderDetails!.clientName!.isEmpty ||
                         _orderDetails?.deliveryPhone == null || _orderDetails!.deliveryPhone!.isEmpty;
          break;
        case OrderType.delivery:
          stillMissing = _orderDetails?.clientName == null || _orderDetails!.clientName!.isEmpty ||
                         _orderDetails?.deliveryPhone == null || _orderDetails!.deliveryPhone!.isEmpty ||
                         _orderDetails?.deliveryAddress == null || _orderDetails!.deliveryAddress!.isEmpty;
          break;
      }
      if (stillMissing) return;
    }

    setState(() => _submitting = true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    try {
      await _orderService.updateOrder(
        orderId: _editingOrder!.id,
        lines: _ticketLines,
        orderType: _orderType,
        expectedTotal: _total,
        tableNumber: _orderDetails?.tableNumber,
        clientName: _orderDetails?.clientName,
        deliveryAddress: _orderDetails?.deliveryAddress,
        deliveryPhone: _orderDetails?.deliveryPhone,
        notes: _orderNotes,
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // loader

      final updatedTicket = _editingOrder!.ticketNumber;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF059669),
          content: Text('Commande #$updatedTicket modifiée avec succès et transmise en cuisine !'),
        ),
      );

      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      } else {
        _cancelEditing();
      }
    } on ApiException catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text(e.message),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('Erreur: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// "0000123" -> "0000124". The server's counter is global, so with several
  /// registers this is only a preview; the real number comes from the server.
  String _nextTicketNumber(String served) {
    final n = int.tryParse(served);
    return n == null ? _ticketNumber : (n + 1).toString().padLeft(6, '0');
  }

  // ───────────────────────────── UI ─────────────────────────────

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
                  'Ticket N° $_ticketNumber',
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
                    color: _isEditing ? const Color(0xFFFEF3C7) : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(4),
                    border: _isEditing ? Border.all(color: const Color(0xFFF59E0B)) : null,
                  ),
                  child: Text(
                    _isEditing ? 'MODIFICATION' : 'En cours',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _isEditing ? const Color(0xFF92400E) : const Color(0xFF4B5563),
                    ),
                  ),
                ),
                if (_isEditing) ...[
                  const Spacer(),
                  InkWell(
                    onTap: _cancelEditing,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close, size: 12, color: Color(0xFFB91C1C)),
                          SizedBox(width: 4),
                          Text(
                            'Annuler',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB91C1C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: InkWell(
              onTap: _openEditOrderDetails,
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: _orderTypeColor(_orderType).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _orderType.label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: _orderTypeColor(_orderType),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _formatCurrentOrderSummary(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                  const Tooltip(
                    message: 'Modifier le mode & les infos',
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.edit_outlined, size: 15, color: Color(0xFF2563EB)),
                    ),
                  ),
                ],
              ),
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
                    '${_total.toStringAsFixed(2).replaceAll('.', ',')} DA',
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
                    : (_isEditing ? _saveOrderModifications : _openEncaissement),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isEditing ? const Color(0xFFD97706) : const Color(0xFF059669),
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
                    Icon(
                      _isEditing ? Icons.check_circle_outline : Icons.credit_card,
                      color: const Color(0xFFFBBF24),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _isEditing ? 'ENREGISTRER LA MODIFICATION' : 'ENCAISSEMENT',
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
            child: Row(
              children: [
                Expanded(
                  child: _smallActionButton(
                    label: 'History',
                    icon: Icons.inventory_2_outlined,
                    bg: const Color(0xFF27272A),
                    fg: Colors.white,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => HistoryScreen(
                            posteLabel: widget.posteLabel,
                          ),
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
        onTap: () => _handleOrderTypeSelection(type),
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