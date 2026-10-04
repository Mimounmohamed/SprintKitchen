import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/order_models.dart';
import '../../theme/app_colors.dart';
import '../services/receipt_printer_service.dart';
import 'receipt_preview_dialog.dart';

class _ModeStyle {
  const _ModeStyle(this.label, this.bg, this.fg, this.dot);
  final String label;
  final Color bg;
  final Color fg;
  final Color dot;
}

/// The "COMMANDE #XXXX" slide-in panel shown from the history table's
/// "Détails" button. Self-contained: pass an order, a close callback, and
/// (optionally) handlers for the three footer actions — anything left null
/// falls back to a "bientôt disponible" snackbar.
class OrderDetailsPanel extends StatelessWidget {
  const OrderDetailsPanel({
    super.key,
    required this.order,
    required this.onClose,
    this.onPrintReceipt,
    this.onReprintKitchenSlip,
    this.onRefundOrCancel,
    this.onMarkTerminee,
    this.onModifyOrder,
  });

  final HistoryOrder order;
  final VoidCallback onClose;
  final VoidCallback? onPrintReceipt;
  final VoidCallback? onReprintKitchenSlip;
  final VoidCallback? onRefundOrCancel;
  final VoidCallback? onMarkTerminee;
  final VoidCallback? onModifyOrder;

  /// Recommended panel width — pass this (capped to the viewport) as the
  /// width of whatever container hosts this widget.
  static const double preferredWidth = 500;

  void _fallback(BuildContext context, String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what : bientôt disponible.')),
    );
  }

  // ─────────────────────────── formatting ───────────────────────────

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

  String _statusLabel(String status) {
    switch (status) {
      case 'en_cours':
        return 'En cours';
      case 'en_attente':
        return 'En attente';
      case 'a_encaisser':
        return 'À encaisser';
      case 'terminee':
        return 'Terminée';
      case 'repas_employe':
        return 'Repas employé';
      case 'annulee':
        return 'Annulée';
      default:
        return status;
    }
  }

  Color _statusPillColor(String status) {
    switch (status) {
      case 'terminee':
      case 'repas_employe':
        return AppColors.success;
      case 'annulee':
        return AppColors.danger;
      default:
        return const Color(0xFF6B7280);
    }
  }

  // ───────────────────────────── build ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mode = _modeStyle(order.orderType);

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
                _buildModificationsCard(),
                _buildKitchenNotesCard(),
                _buildItemsCard(),
              ],
            ),
          ),
        ),
        _buildFooter(context),
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
                      'COMMANDE #${order.ticketNumber}',
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
                        color: _statusPillColor(order.status),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _statusLabel(order.status),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onClose,
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
            'Historique de vente • Transaction confirmée',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────── info card ─────────────────────────────

  Widget _buildInfoCard(_ModeStyle mode) {
    final clientName = order.clientName ?? order.deliveryName ?? 'Client Passant';
    String tableDisplay = '—';
    final rawTable = (order.tableNumber != null && order.tableNumber!.isNotEmpty)
        ? order.tableNumber!
        : (order.buzzerNumber != null && order.buzzerNumber!.isNotEmpty ? order.buzzerNumber! : null);

    if (rawTable != null) {
      final cleaned = rawTable
          .replaceAll(RegExp(r'^(buzzer\s*#?|table\s*)', caseSensitive: false), '')
          .trim();
      tableDisplay = cleaned.isNotEmpty ? 'Table $cleaned' : 'Table';
    }

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
                  '${_fmtDate(order.createdAt)} à ${_fmtTime(order.createdAt)}',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MODE DE CONSOMMATION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF9CA3AF),
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _modeChip(mode),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: Color(0xFFF3F4F6)),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _infoCell(
                  Icons.person_outline,
                  'NOM DU CLIENT',
                  clientName,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _infoCell(
                  Icons.table_restaurant_outlined,
                  'TABLE',
                  tableDisplay,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: Color(0xFFF3F4F6)),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _infoCell(
                  Icons.phone_outlined,
                  'TÉLÉPHONE',
                  (order.deliveryPhone != null && order.deliveryPhone!.isNotEmpty)
                      ? order.deliveryPhone!
                      : '—',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _infoCell(
                  Icons.location_on_outlined,
                  'ADRESSE DE LIVRAISON',
                  (order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty)
                      ? order.deliveryAddress!
                      : '—',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModificationsCard() {
    if (!order.isEdited || order.modificationSummary.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF87171), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.edit_note_rounded, size: 20, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text(
                'MODIFICATIONS EFFECTUÉES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFDC2626),
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final m in order.modificationSummary) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
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
                    size: 15,
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
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.text,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
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
      ),
    );
  }

  Widget _buildKitchenNotesCard() {
    if (order.notes == null || order.notes!.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
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
                  order.notes!,
                  style: const TextStyle(
                    fontSize: 13,
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

  Widget _infoCell(IconData icon, String label, String value, {Color? dotColor}) {
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
            if (dotColor != null) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
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

  Widget _modeChip(_ModeStyle m) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: m.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: m.dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            m.label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: m.fg),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────── items card ─────────────────────────────

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
          Row(
            children: [
              const Expanded(
                flex: 2,
                child: Text(
                  'QTÉ',
                  style: TextStyle(
                     fontSize: 11,
                     fontWeight: FontWeight.w700,
                     color: Color(0xFF57534E),
                     letterSpacing: 0.5,
                  ),
                ),
              ),
              const Expanded(
                flex: 6,
                child: Text(
                  'ARTICLE & SUPPLÉMENTS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF57534E),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Expanded(
                flex: 2,
                child: Text(
                  'PRIX',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF57534E),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFE5E7EB)),
          ),
          for (var i = 0; i < order.lines.length; i++) ...[
            _detailLine(order.lines[i]),
            if (i != order.lines.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: Color(0xFFF3F4F6)),
              ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: Color(0xFFE5E7EB)),
          ),
          _totalRow('TOTAL PAYÉ', _euro(order.totalTTC), bold: true),
        ],
      ),
    );
  }

  /// One item row: quantity, name, price, and — grouped under a single gold
  /// accent bar — every selected option / removed ingredient for that item.
  Widget _detailLine(HistoryOrderLine l) {
    final subLines = <Widget>[
      for (final option in l.options)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            '• $option',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ),
      for (final removed in l.removed)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            '• Sans $removed',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFFB45309),
            ),
          ),
        ),
      if (l.notes != null && l.notes!.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            l.notes!,
            style: const TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F4),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${l.quantity}×',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                if (subLines.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  // Vertical gold accent bar grouping every sub-option for
                  // this item, like a blockquote.
                  Container(
                    padding: const EdgeInsets.only(left: 10),
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
        ),
        Expanded(
          flex: 2,
          child: Text(
            _euro(l.lineTotal),
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
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

  // ───────────────────────────── footer ─────────────────────────────

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(
        children: [
          if (order.status == 'en_attente') ...[
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: onMarkTerminee,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.check_circle_outline, size: 22),
                label: const Text(
                  'MARQUER COMME TERMINÉE (PRÊTE)',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.5),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (onModifyOrder != null && order.status != 'terminee' && order.status != 'annulee') ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onModifyOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text(
                  'MODIFIER LA COMMANDE',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (onPrintReceipt != null) {
                        onPrintReceipt!();
                      } else {
                        final data = PrintableReceiptData.fromHistoryOrder(order);
                        final ok = await ReceiptPrinterService.printClientReceiptDirect(data);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok
                                  ? 'Ticket client envoyé directement à l\'imprimante.'
                                  : 'Impression lancée.'),
                              backgroundColor: const Color(0xFF059669),
                              action: SnackBarAction(
                                label: 'VOIR TICKET',
                                textColor: Colors.white,
                                onPressed: () => ReceiptPreviewDialog.show(context, data),
                              ),
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.brandDark,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.goldLight),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.print_outlined, size: 20),
                    label: const Text(
                      'IMPRIMER TICKET DE CAISSE',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Voir l\'aperçu du ticket',
                child: InkWell(
                  onTap: () {
                    final data = PrintableReceiptData.fromHistoryOrder(order);
                    ReceiptPreviewDialog.show(context, data, initialShowKitchen: false);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                    ),
                    child: const Icon(Icons.visibility_outlined, color: Color(0xFF374151), size: 22),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    if (onReprintKitchenSlip != null) {
                      onReprintKitchenSlip!();
                    } else {
                      final data = PrintableReceiptData.fromHistoryOrder(order);
                      final ok = await ReceiptPrinterService.printKitchenReceiptDirect(data);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? 'Bon cuisine envoyé directement à l\'imprimante.'
                                : 'Impression lancée.'),
                            backgroundColor: const Color(0xFF059669),
                            action: SnackBarAction(
                              label: 'VOIR BON',
                              textColor: Colors.white,
                              onPressed: () => ReceiptPreviewDialog.show(context, data, initialShowKitchen: true),
                            ),
                          ),
                        );
                      }
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF374151),
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.restaurant_menu, size: 16),
                  label: const Text(
                    'Imprimer Bon Cuisine',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Voir l\'aperçu du bon cuisine',
                child: InkWell(
                  onTap: () {
                    final data = PrintableReceiptData.fromHistoryOrder(order);
                    ReceiptPreviewDialog.show(context, data, initialShowKitchen: true);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                    ),
                    child: const Icon(Icons.visibility_outlined, size: 20, color: Color(0xFF4B5563)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRefundOrCancel ??
                      () => _fallback(context, 'Remboursement / Annulation'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.undo, size: 16),
                  label: const Text(
                    'Remboursement / Annulation',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Opens [OrderDetailsPanel] sliding in from the right edge of the screen.
void showOrderDetailsPanel(
  BuildContext context,
  HistoryOrder order, {
  VoidCallback? onMarkTerminee,
  VoidCallback? onModifyOrder,
}) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fermer',
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, anim, secondaryAnim) {
      final panelWidth = math.min(
          OrderDetailsPanel.preferredWidth, MediaQuery.sizeOf(ctx).width);
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Colors.white,
          elevation: 24,
          child: SizedBox(
            width: panelWidth,
            height: double.infinity,
            child: OrderDetailsPanel(
              order: order,
              onClose: () => Navigator.of(ctx).pop(),
              onMarkTerminee: onMarkTerminee,
              onModifyOrder: onModifyOrder,
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