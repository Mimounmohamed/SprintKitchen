import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

enum PaymentMethod { especes, carte }

/// Result returned when the cashier validates payment.
class EncaissementResult {
  const EncaissementResult({
    required this.method,
    required this.amountReceived,
    required this.change,
    required this.printReceipt,
  });

  final PaymentMethod method;
  final double amountReceived;
  final double change;
  final bool printReceipt;
}

/// The "ENCAISSEMENT — TICKET N° ..." payment dialog.
class EncaissementModal extends StatefulWidget {
  const EncaissementModal({
    super.key,
    required this.total,
    required this.ticketNumber,
    required this.posteLabel,
    this.sessionLabel = 'Session #4920',
  });

  final double total;
  final String ticketNumber;
  final String posteLabel;
  final String sessionLabel;

  @override
  State<EncaissementModal> createState() => _EncaissementModalState();
}

class _EncaissementModalState extends State<EncaissementModal> {
  PaymentMethod _method = PaymentMethod.especes;
  int _receivedCents = 0;
  bool _printReceipt = true;

  int get _dueCents => (widget.total * 100).round();

  double get _received => _receivedCents / 100;

  double get _change =>
      _receivedCents > _dueCents ? (_receivedCents - _dueCents) / 100 : 0;

  bool get _isValid {
    if (_method == PaymentMethod.carte) return true;
    return _receivedCents >= _dueCents;
  }

  @override
  void initState() {
    super.initState();
    _receivedCents = _dueCents; // default to exact amount
  }

  void _selectMethod(PaymentMethod method) {
    setState(() {
      _method = method;
      if (method == PaymentMethod.carte) {
        _receivedCents = _dueCents; // card always charges exact amount
      }
    });
  }

  void _appendDigit(String digits) {
    if (_method != PaymentMethod.especes) return;
    setState(() {
      for (final ch in digits.split('')) {
        final digit = int.parse(ch);
        // Cap so it can't grow unbounded.
        if (_receivedCents > 99999999) return;
        _receivedCents = _receivedCents * 10 + digit;
      }
    });
  }

  void _clear() {
    if (_method != PaymentMethod.especes) return;
    setState(() => _receivedCents = 0);
  }

  void _setQuickAmount(int cents) {
    if (_method != PaymentMethod.especes) return;
    setState(() => _receivedCents = cents);
  }

  List<int> get _quickAmountsCents {
    final due = _dueCents;
    final next10 = ((due / 1000).ceil()) * 1000; // round up to next 10.00
    final plus10 = next10 + 1000;
    final next50 = ((due / 5000).ceil()) * 5000; // round up to next 50.00
    final options = <int>{due, next10, plus10, next50}.toList()..sort();
    return options;
  }

  String _fmt(num value) =>
      '${(value / 100).toStringAsFixed(2).replaceAll('.', ',')} €';

  String _fmtEuros(double value) =>
      '${value.toStringAsFixed(2).replaceAll('.', ',')} €';

  void _validate() {
    if (!_isValid) return;
    Navigator.of(context).pop(
      EncaissementResult(
        method: _method,
        amountReceived: _method == PaymentMethod.carte
            ? widget.total
            : _received,
        change: _method == PaymentMethod.carte ? 0 : _change,
        printReceipt: _printReceipt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 640),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 4, child: _buildPaymentMethods()),
                      const SizedBox(width: 24),
                      Expanded(flex: 6, child: _buildAmountPanel()),
                    ],
                  ),
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      color: AppColors.brandDark,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.credit_card, size: 16, color: AppColors.brandDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ENCAISSEMENT — TICKET N° ${widget.ticketNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.posteLabel} — ${widget.sessionLabel}',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'TOTAL À PAYER',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                Text(
                  _fmtEuros(widget.total),
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MOYENS DE PAIEMENT',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.textMuted,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 10),
        _methodCard(
          method: PaymentMethod.especes,
          icon: Icons.payments_rounded,
          title: 'Espèces (Cash)',
          subtitle: 'Tiroir automatique prêt',
        ),
        const SizedBox(height: 10),
        _methodCard(
          method: PaymentMethod.carte,
          icon: Icons.credit_card,
          title: 'Carte Bancaire (CB)',
          subtitle: 'Terminal Pinpad connecté',
          trailing: _fmtEuros(widget.total),
        ),
      ],
    );
  }

  Widget _methodCard({
    required PaymentMethod method,
    required IconData icon,
    required String title,
    required String subtitle,
    String? trailing,
  }) {
    final selected = _method == method;
    return InkWell(
      onTap: () => _selectMethod(method),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandDark : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: selected ? AppColors.gold : AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 16,
                color: selected ? AppColors.brandDark : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: selected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: selected ? AppColors.gold : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              Text(
                trailing,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              )
            else if (selected)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.gold,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountPanel() {
    final insufficient = _method == PaymentMethod.especes && !_isValid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _amountBox('MONTANT DÛ', _fmt(_dueCents), AppColors.textPrimary)),
            const SizedBox(width: 10),
            Expanded(
              child: _amountBox(
                'MONTANT REÇU',
                _fmt(_receivedCents),
                insufficient ? AppColors.danger : AppColors.textPrimary,
                highlighted: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _amountBox(
                'RENDU MONNAIE',
                _method == PaymentMethod.carte ? _fmt(0) : _fmtEuros(_change),
                AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'BILLETS & RACCOURCIS RAPIDES',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.textMuted,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: _quickAmountsCents.asMap().entries.map((entry) {
            final isExact = entry.value == _dueCents;
            final label = isExact ? 'Exact (${_fmt(_dueCents)})' : _fmt(entry.value);
            final selected = _receivedCents == entry.value;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: entry.key == _quickAmountsCents.length - 1 ? 0 : 8),
                child: _quickButton(label, selected, () => _setQuickAmount(entry.value)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        _buildKeypad(),
        const SizedBox(height: 12),
        Row(
          children: [
            Checkbox(
              value: _printReceipt,
              onChanged: (v) => setState(() => _printReceipt = v ?? true),
              activeColor: AppColors.brandDark,
            ),
            const Text(
              'Imprimer le ticket de caisse',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _amountBox(String label, String value, Color valueColor, {bool highlighted = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: highlighted ? AppColors.brandDark : AppColors.border, width: highlighted ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: valueColor)),
        ],
      ),
    );
  }

  Widget _quickButton(String label, bool selected, VoidCallback onTap) {
    final disabled = _method != PaymentMethod.especes;
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: disabled
              ? AppColors.menuTileDisabled
              : selected
                  ? AppColors.brandDark
                  : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.gold : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: disabled
                ? AppColors.textMuted
                : selected
                    ? Colors.white
                    : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    const rows = [
      ['7', '8', '9'],
      ['4', '5', '6'],
      ['1', '2', '3'],
      ['C', '0', '00'],
    ];
    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: row.asMap().entries.map((entry) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: entry.key == row.length - 1 ? 0 : 8),
                  child: _keypadButton(entry.value),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _keypadButton(String label) {
    final disabled = _method != PaymentMethod.especes;
    final isClear = label == 'C';
    return InkWell(
      onTap: disabled
          ? null
          : () => isClear ? _clear() : _appendDigit(label),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: disabled
              ? AppColors.menuTileDisabled
              : isClear
                  ? AppColors.danger.withValues(alpha: 0.1)
                  : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: disabled
                ? AppColors.textMuted
                : isClear
                    ? AppColors.danger
                    : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler (Retour)'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isValid ? _validate : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'VALIDER L\'ENCAISSEMENT (${_fmt(_method == PaymentMethod.carte ? _dueCents : _receivedCents)})',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ],
                  ),
                  if (_method == PaymentMethod.especes)
                    Text(
                      'Rendu : ${_fmtEuros(_change)}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}