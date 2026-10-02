import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'kds_screen.dart';

/* ─── Mode styling helper ─────────────────────────────────────────── */
class _ModeStyle {
  const _ModeStyle(this.label, this.bg, this.fg, this.dot);
  final String label;
  final Color bg;
  final Color fg;
  final Color dot;
}

/// A comprehensive order details dialog inspired directly by the POS order details panel,
/// featuring:
/// - Left side: The complete order receipt / ticket with info card, totals, and print actions.
/// - Right side: Interactive item list and technical sheet / recipe for the selected item.
class KitchenOrderDetailsDialog extends StatefulWidget {
  const KitchenOrderDetailsDialog({
    super.key,
    required this.order,
    required this.onClose,
    this.onAdvance,
    this.onPrint,
    this.onItemStatusChanged,
  });

  final KitchenOrder order;
  final VoidCallback onClose;
  final Future<void> Function(KitchenOrder)? onAdvance;
  final VoidCallback? onPrint;
  final void Function(KdsItem item, bool isReady)? onItemStatusChanged;

  @override
  State<KitchenOrderDetailsDialog> createState() =>
      _KitchenOrderDetailsDialogState();
}

class _KitchenOrderDetailsDialogState extends State<KitchenOrderDetailsDialog> {
  int _selectedIndex = 0;
  bool _advancing = false;
  bool _savingItem = false;
  final Map<int, bool> _itemsReady = {};

  @override
  void initState() {
    super.initState();
    // Initialize ready states from items
    for (int i = 0; i < widget.order.items.length; i++) {
      _itemsReady[i] = widget.order.items[i].isReady ||
          widget.order.status == OrderStatus.terminee;
    }
  }

  // ────────────────────────── Formatting helpers ──────────────────────────

  String _two(int n) => n.toString().padLeft(2, '0');
  String _fmtDate(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';
  String _fmtTime(DateTime d) =>
      '${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}';

  _ModeStyle _modeStyle(OrderMode mode) {
    switch (mode) {
      case OrderMode.emporter:
        return const _ModeStyle('À emporter', Color(0xFFDBEAFE),
            Color(0xFF1E40AF), Color(0xFF2563EB));
      case OrderMode.livraison:
        return const _ModeStyle('Livraison', Color(0xFFCCFBF1),
            Color(0xFF115E59), Color(0xFF0D9488));
      case OrderMode.surPlace:
        return const _ModeStyle('Sur place', Color(0xFFFFE4E6),
            Color(0xFF9F1239), Color(0xFFE11D48));
    }
  }

  String _statusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.attente:
        return 'En attente';
      case OrderStatus.preparation:
        return 'En préparation';
      case OrderStatus.terminee:
        return 'Terminée';
    }
  }

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.attente:
        return const Color(0xFFE08E0B);
      case OrderStatus.preparation:
        return const Color(0xFF2563EB);
      case OrderStatus.terminee:
        return const Color(0xFF22A45D);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = _modeStyle(widget.order.mode);
    final items = widget.order.items;
    final selectedIndex = _selectedIndex.clamp(0, items.isEmpty ? 0 : items.length - 1);
    final selectedItem = items.isNotEmpty ? items[selectedIndex] : null;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 1200,
        height: 750,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F2EF),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _buildTopBar(mode),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  /* ─── LEFT: ORDER RECEIPT (Ticket) ─── */
                  Expanded(
                    flex: 48,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFF9F8F6),
                        border: Border(
                          right: BorderSide(color: Color(0xFFE2DFD8), width: 1.2),
                        ),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.order.isEdited) ...[
                              _buildEditedBanner(),
                              const SizedBox(height: 14),
                            ],
                            _buildInfoCard(mode),
                            const SizedBox(height: 14),
                            if (widget.order.comment != null &&
                                widget.order.comment!.trim().isNotEmpty) ...[
                              _buildKitchenNotesCard(widget.order.comment!),
                              const SizedBox(height: 14),
                            ],
                            _buildReceiptItemsCard(),
                            const SizedBox(height: 14),
                            _buildReceiptFooterButtons(),
                          ],
                        ),
                      ),
                    ),
                  ),

                  /* ─── RIGHT: ITEM SELECTOR & TECHNICAL RECIPE ─── */
                  Expanded(
                    flex: 52,
                    child: Container(
                      color: Colors.white,
                      child: Column(
                        children: [
                          _buildRightHeader(items.length),
                          _buildItemSelectorTabs(items, selectedIndex),
                          const Divider(height: 1, color: Color(0xFFE5E7EB)),
                          Expanded(
                            child: selectedItem != null
                                ? _buildSelectedItemDetails(
                                    selectedItem, selectedIndex)
                                : const Center(
                                    child: Text(
                                      'Aucun article dans cette commande',
                                      style: TextStyle(color: Color(0xFF9CA3AF)),
                                    ),
                                  ),
                          ),
                        ],
                      ),
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

  // ───────────────────────────── TOP BAR ─────────────────────────────

  Widget _buildTopBar(_ModeStyle mode) {
    final statusColor = _statusColor(widget.order.status);
    final statusText = _statusLabel(widget.order.status);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2DFD8))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF2B705).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Color(0xFF2E1F0F),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'COMMANDE ${widget.order.ticketNumber}',
                      style: GoogleFonts.bebasNeue(
                        color: const Color(0xFF1A1714),
                        fontSize: 26,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusText,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (widget.order.tableNumber != null &&
                        widget.order.tableNumber!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Text(
                          widget.order.tableNumber!.toUpperCase().startsWith('TABLE')
                              ? widget.order.tableNumber!.toUpperCase()
                              : 'TABLE ${widget.order.tableNumber}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                    ],
                    if (widget.order.isEdited) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.edit, size: 12, color: Color(0xFFDC2626)),
                            SizedBox(width: 4),
                            Text(
                              'MODIFIÉ',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Reçue le ${_fmtDate(widget.order.createdAt)} à ${_fmtTime(widget.order.createdAt)} • Mode : ${mode.label}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close, size: 18, color: Color(0xFF4B5563)),
            label: const Text(
              'Fermer',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4B5563),
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              backgroundColor: const Color(0xFFF3F4F6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────── LEFT: RECEIPT CARDS ──────────────────────────

  Widget _buildEditedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF87171), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.edit_note_rounded, size: 22, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text(
                'DÉTAIL DES MODIFICATIONS (Caisse)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFDC2626),
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Voici les changements effectués sur cette commande après son envoi initial :',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF7F1D1D),
            ),
          ),
          if (widget.order.modificationSummary.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final m in widget.order.modificationSummary) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: m.action == 'deleted'
                        ? const Color(0xFFFECACA)
                        : (m.action == 'added'
                            ? const Color(0xFFBBF7D0)
                            : const Color(0xFFE5E7EB)),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      m.action == 'deleted'
                          ? Icons.remove_circle
                          : (m.action == 'added'
                              ? Icons.add_circle
                              : (m.action == 'table'
                                  ? Icons.table_restaurant
                                  : (m.action == 'note'
                                      ? Icons.chat_bubble
                                      : Icons.change_circle))),
                      size: 16,
                      color: m.action == 'deleted'
                          ? const Color(0xFFDC2626)
                          : (m.action == 'added'
                              ? const Color(0xFF16A34A)
                              : (m.action == 'table'
                                  ? const Color(0xFF2563EB)
                                  : (m.action == 'note'
                                      ? const Color(0xFF7C3AED)
                                      : const Color(0xFFD97706)))),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.text,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: m.action == 'deleted'
                                  ? const Color(0xFFDC2626)
                                  : (m.action == 'added'
                                      ? const Color(0xFF15803D)
                                      : const Color(0xFF1F2937)),
                              decoration: m.action == 'deleted'
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          if (m.details != null && m.details!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              m.details!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4B5563),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard(_ModeStyle mode) {
    final client = widget.order.tableNumber != null &&
            widget.order.tableNumber!.isNotEmpty
        ? (widget.order.tableNumber!.toLowerCase().startsWith('table')
            ? widget.order.tableNumber!
            : 'Table ${widget.order.tableNumber}')
        : (widget.order.clientName ?? 'Client Passant');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
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
              const SizedBox(width: 14),
              Expanded(
                child: _infoCell(
                  Icons.point_of_sale_outlined,
                  'CAISSE & OPÉRATEUR',
                  widget.order.registerName ?? 'Caisse Tactile Comptoir',
                  dotColor: const Color(0xFF22A45D),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Color(0xFFF3F4F6)),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _infoCell(
                  Icons.person_outline,
                  'CLIENT / LOCALISATION',
                  client,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MODE DE CONSOMMATION',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF9CA3AF),
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: mode.bg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                                color: mode.dot, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            mode.label,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: mode.fg,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Color(0xFFF3F4F6)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Canal de prise de commande :',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF9CA3AF)),
              ),
              Text(
                'Caisse Tactile Comptoir',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF374151),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoCell(IconData icon, String label, String value,
      {Color? dotColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF9CA3AF),
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            if (dotColor != null) ...[
              Container(
                width: 7,
                height: 7,
                decoration:
                    BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ] else ...[
              Icon(icon, size: 13, color: const Color(0xFF9CA3AF)),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
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

  Widget _buildKitchenNotesCard(String notes) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.chat_bubble_outline_rounded,
              size: 18, color: Color(0xFFB45309)),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NOTE CUISINE / COMMENTAIRE',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Color(0xFFB45309),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  notes,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF78350F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptItemsCard() {
    final totalItemsCount =
        widget.order.items.fold<int>(0, (sum, it) => sum + it.quantity);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              SizedBox(
                width: 48,
                child: Text(
                  'QTÉ',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'ARTICLE & PERSONNALISATIONS',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Color(0xFFE5E7EB)),
          ),
          for (var i = 0; i < widget.order.items.length; i++) ...[
            _buildReceiptItemRow(widget.order.items[i], i),
            if (i != widget.order.items.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: Color(0xFFF3F4F6)),
              ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Color(0xFFE5E7EB)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL ARTICLES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4B5563),
                  letterSpacing: 0.4,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$totalItemsCount article(s)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptItemRow(KdsItem item, int index) {
    final isSelected = _selectedIndex == index;
    final isItemReady = _itemsReady[index] ?? item.isReady;

    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: isSelected
              ? const Color(0xFFF2B705).withValues(alpha: 0.08)
              : Colors.transparent,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 44,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isItemReady
                      ? const Color(0xFFDCFCE7)
                      : (isSelected
                          ? const Color(0xFFF2B705)
                          : const Color(0xFFF3F4F6)),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  item.qty,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isItemReady
                        ? const Color(0xFF15803D)
                        : (isSelected
                            ? const Color(0xFF2E1F0F)
                            : const Color(0xFF111827)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isItemReady
                                ? const Color(0xFF15803D)
                                : (isSelected
                                    ? const Color(0xFF92400E)
                                    : const Color(0xFF111827)),
                            decoration: isItemReady ? TextDecoration.lineThrough : null,
                            decorationColor: const Color(0xFF15803D),
                          ),
                        ),
                      ),
                      if (isItemReady)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PRÊT ✓',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (item.subLines.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.only(left: 8),
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(
                              color: Color(0xFFF2B705), width: 2.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final sub in item.subLines)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                '• $sub',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: sub.toLowerCase().startsWith('sans')
                                      ? const Color(0xFFB45309)
                                      : const Color(0xFF6B7280),
                                  fontWeight:
                                      sub.toLowerCase().startsWith('sans')
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptFooterButtons() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Réimpression du bon cuisine envoyée'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF374151),
                side: const BorderSide(color: Color(0xFFD1D5DB), width: 1.2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.restaurant_menu, size: 17),
              label: const Text(
                'Réimprimer Bon Cuisine',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: (_advancing ||
                      widget.order.status == OrderStatus.terminee)
                  ? null
                  : () async {
                      setState(() => _advancing = true);
                      if (widget.onAdvance != null) {
                        await widget.onAdvance!(widget.order);
                      }
                      if (mounted) setState(() => _advancing = false);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.order.status == OrderStatus.attente
                    ? const Color(0xFFF2B705)
                    : const Color(0xFF22A45D),
                foregroundColor: widget.order.status == OrderStatus.attente
                    ? const Color(0xFF2E1F0F)
                    : Colors.white,
                disabledBackgroundColor: const Color(0xFFEBE8E1),
                disabledForegroundColor: const Color(0xFF9A948A),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: Icon(
                widget.order.status == OrderStatus.attente
                    ? Icons.play_arrow_rounded
                    : Icons.check_circle_outline_rounded,
                size: 18,
              ),
              label: Text(
                widget.order.status == OrderStatus.attente
                    ? 'Commencer'
                    : (widget.order.status == OrderStatus.preparation
                        ? 'Terminer ✓'
                        : 'Terminée'),
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ──────────────────────── RIGHT: ITEMS & RECIPE ────────────────────────

  Widget _buildRightHeader(int count) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.restaurant_outlined,
                  size: 18, color: Color(0xFFB45309)),
              const SizedBox(width: 8),
              Text(
                'ARTICLES DE LA COMMANDE ($count)',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2937),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const Text(
            'Sélectionnez un article pour voir ses détails & options',
            style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }

  Widget _buildItemSelectorTabs(List<KdsItem> items, int selectedIndex) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      color: const Color(0xFFF9FAFB),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final it = items[i];
          final isSelected = i == selectedIndex;
          final isReady = _itemsReady[i] ?? false;

          return InkWell(
            onTap: () => setState(() => _selectedIndex = i),
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFFFBEB) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFFE5E7EB),
                  width: isSelected ? 1.8 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFF2B705)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      it.qty,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? const Color(0xFF2E1F0F)
                            : const Color(0xFF374151),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        it.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? const Color(0xFF92400E)
                              : const Color(0xFF111827),
                        ),
                      ),
                      Text(
                        it.station != null && it.station!.isNotEmpty
                            ? 'Poste : ${it.station!.toUpperCase()}'
                            : 'Standard',
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected
                              ? const Color(0xFFB45309)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  if (isReady) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.check_circle,
                        size: 14, color: Color(0xFF22A45D)),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectedItemDetails(KdsItem item, int index) {
    final isReady = _itemsReady[index] ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /* Item title card */
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFBEB), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFCD34D), width: 1.2),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2B705),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      item.qty,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2E1F0F),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0E7FF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.station != null && item.station!.isNotEmpty
                              ? 'POSTE : ${item.station!.toUpperCase()}'
                              : 'POSTE : CUISINE CHAUDE',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF3730A3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _savingItem
                      ? null
                      : () async {
                          final targetReady = !isReady;
                          final targetStatus =
                              targetReady ? 'ready' : 'pending';
                          setState(() {
                            _savingItem = true;
                            _itemsReady[index] = targetReady;
                            item.kdsStatus = targetStatus;
                          });
                          if (widget.onItemStatusChanged != null) {
                            widget.onItemStatusChanged!(item, targetReady);
                          }
                          try {
                            await KdsApi.updateItemStatus(
                              order: widget.order,
                              itemIndex: index,
                              newStatus: targetStatus,
                            );
                            if (mounted) {
                              setState(() => _savingItem = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(targetReady
                                      ? '${item.name} enregistré comme PRÊT ✓'
                                      : '${item.name} remis en préparation'),
                                  duration: const Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: targetReady
                                      ? const Color(0xFF15803D)
                                      : const Color(0xFF374151),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              setState(() {
                                _savingItem = false;
                                _itemsReady[index] = isReady;
                                item.kdsStatus = isReady ? 'ready' : 'pending';
                              });
                              if (widget.onItemStatusChanged != null) {
                                widget.onItemStatusChanged!(item, isReady);
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Erreur d\'enregistrement : $e'),
                                  backgroundColor: const Color(0xFFDC2626),
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isReady
                        ? const Color(0xFF22A45D)
                        : const Color(0xFFF3F4F6),
                    foregroundColor:
                        isReady ? Colors.white : const Color(0xFF374151),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isReady
                            ? const Color(0xFF22A45D)
                            : const Color(0xFFD1D5DB),
                      ),
                    ),
                  ),
                  icon: _savingItem
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isReady ? Colors.white : const Color(0xFF374151),
                            ),
                          ),
                        )
                      : Icon(
                          isReady
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked,
                          size: 16,
                        ),
                  label: Text(
                    isReady ? 'Article Prêt ✓' : 'Marquer Prêt',
                    style: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          /* Customizations and Extras */
          if (item.customizations.isNotEmpty) ...[
            _sectionTitle('OPTIONS & PERSONNALISATIONS DU CLIENT',
                Icons.tune_rounded, const Color(0xFFB45309)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF2B705).withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.only(left: 12),
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(
                        color: Color(0xFFF2B705), width: 3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < item.customizations.length; i++) ...[
                      Padding(
                        padding: EdgeInsets.only(
                            bottom: i < item.customizations.length - 1 ? 6 : 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '• ',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF78350F),
                              ),
                            ),
                            Text(
                              '${item.customizations[i].groupName}: ',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                item.customizations[i].selectedOptions.join(', '),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          /* Removed Ingredients (Sans...) */
          if (item.removedIngredients.isNotEmpty) ...[
            _sectionTitle('INGRÉDIENTS À RETIRER (SANS...)',
                Icons.remove_circle_outline_rounded, const Color(0xFFDC2626)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA), width: 1.2),
              ),
              child: Container(
                padding: const EdgeInsets.only(left: 12),
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(
                        color: Color(0xFFDC2626), width: 3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '⚠️ À RETIRER DE LA PRÉPARATION :',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFB91C1C),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final rem in item.removedIngredients)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '• ',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                rem.toLowerCase().startsWith('sans')
                                    ? rem
                                    : 'Sans $rem',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          /* Item notes */
          if (item.notes != null && item.notes!.trim().isNotEmpty) ...[
            _sectionTitle('REMARQUE ARTICLE', Icons.edit_note_rounded,
                const Color(0xFFD97706)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCD34D), width: 1.2),
              ),
              child: Container(
                padding: const EdgeInsets.only(left: 12),
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(
                        color: Color(0xFFD97706), width: 3),
                  ),
                ),
                child: Text(
                  item.notes!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF78350F),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          /* Standard item indication when no specific customizations or exclusions exist */
          if (item.customizations.isEmpty &&
              item.removedIngredients.isEmpty &&
              (item.notes == null || item.notes!.trim().isEmpty))
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.check_circle_outline_rounded,
                      size: 20, color: Color(0xFF10B981)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Préparation standard (aucune personnalisation ni ingrédient retiré pour cet article).',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF4B5563),
                        fontWeight: FontWeight.w500,
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

  Widget _sectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 7),
        Text(
          title,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}
