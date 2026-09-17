import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
///
/// Self-blurring: builds its own full-screen backdrop, so call it with
/// `barrierColor: Colors.transparent` when using showDialog, e.g.:
///
/// ```dart
/// showDialog<EncaissementResult>(
///   context: context,
///   barrierColor: Colors.transparent,
///   builder: (_) => EncaissementModal(...),
/// );
/// ```
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
  static const double _narrowBreakpoint = 640;
  static const double _maxDialogWidth = 1040;
  static const double _maxDialogHeight = 720;

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
    final size = MediaQuery.sizeOf(context);
    final dialogWidth =
        (size.width - 32) < _maxDialogWidth ? size.width - 32 : _maxDialogWidth;
    final dialogHeight = (size.height - 48) < _maxDialogHeight
        ? size.height - 48
        : _maxDialogHeight;
    final isNarrow = dialogWidth < _narrowBreakpoint;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Blurred + tinted backdrop over whatever is behind the dialog.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(color: Colors.black.withValues(alpha: 0.35)),
            ),
          ),
        ),
        Center(
          child: GestureDetector(
            // Absorb taps so they don't bubble to the barrier behind it.
            onTap: () {},
            behavior: HitTestBehavior.opaque,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: dialogWidth,
                maxHeight: dialogHeight,
              ),
              child: Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                elevation: 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(isNarrow),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(isNarrow ? 14 : 20),
                        child: isNarrow
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildPaymentMethods(),
                                  const SizedBox(height: 20),
                                  _buildAmountPanel(isNarrow),
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 300),
                                    child: _buildPaymentMethods(),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                      child: _buildAmountPanel(isNarrow)),
                                ],
                              ),
                      ),
                    ),
                    _buildFooter(isNarrow),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(bool isNarrow) {
    return Container(
      padding: EdgeInsets.fromLTRB(isNarrow ? 14 : 20, 16, 12, 16),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: isNarrow ? 13 : 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.posteLabel} — ${widget.sessionLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (!isNarrow) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.38),
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
                      fontSize: 19,
                      color: AppColors.gold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
          ],
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
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
          color: selected ? AppColors.brandDark : AppColors.surface,
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

  Widget _buildAmountPanel(bool isNarrow) {
    final insufficient = _method == PaymentMethod.especes && !_isValid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        isNarrow
            ? Column(
                children: [
                  _amountBox('MONTANT DÛ', _fmt(_dueCents), AppColors.textPrimary),
                  const SizedBox(height: 8),
                  _amountBox(
                    'MONTANT REÇU',
                    _fmt(_receivedCents),
                    insufficient ? AppColors.danger : AppColors.textPrimary,
                    highlighted: true,
                  ),
                  const SizedBox(height: 8),
                  _amountBox(
                    'RENDU MONNAIE',
                    _method == PaymentMethod.carte ? _fmt(0) : _fmtEuros(_change),
                    AppColors.success,
                    borderColor: AppColors.success,
                    fillColor: const Color(0xFFEAFBF1),
                  ),
                ],
              )
            : Row(
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
                      borderColor: AppColors.success,
                      fillColor: const Color(0xFFEAFBF1),
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
        _buildQuickAmounts(isNarrow),
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
            const Flexible(
              child: Text(
                'Imprimer le ticket de caisse',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAmounts(bool isNarrow) {
    final entries = _quickAmountsCents.asMap().entries.toList();

    if (isNarrow) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: entries.map((entry) {
          final isExact = entry.value == _dueCents;
          final label = isExact ? 'Exact (${_fmt(_dueCents)})' : _fmt(entry.value);
          final selected = _receivedCents == entry.value;
          return SizedBox(
            width: 108,
            child: _quickButton(label, selected, () => _setQuickAmount(entry.value)),
          );
        }).toList(),
      );
    }

    return Row(
      children: entries.map((entry) {
        final isExact = entry.value == _dueCents;
        final label = isExact ? 'Exact (${_fmt(_dueCents)})' : _fmt(entry.value);
        final selected = _receivedCents == entry.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: entry.key == entries.length - 1 ? 0 : 8),
            child: _quickButton(label, selected, () => _setQuickAmount(entry.value)),
          ),
        );
      }).toList(),
    );
  }

  Widget _amountBox(
    String label,
    String value,
    Color valueColor, {
    bool highlighted = false,
    Color? borderColor,
    Color? fillColor,
  }) {
    final effectiveBorderColor =
        borderColor ?? (highlighted ? AppColors.brandDark : AppColors.border);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: fillColor ?? AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: effectiveBorderColor,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: valueColor)),
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
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: disabled
              ? AppColors.menuTileDisabled
              : selected
                  ? AppColors.brandDark
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
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
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: disabled
              ? AppColors.menuTileDisabled
              : isClear
                  ? AppColors.danger.withValues(alpha: 0.1)
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
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

  Widget _buildFooter(bool isNarrow) {
    final validateButton = ElevatedButton(
      onPressed: _isValid ? _validate : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.success,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check, size: 22, color: AppColors.gold),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'VALIDER L\'ENCAISSEMENT (${_fmt(_method == PaymentMethod.carte ? _dueCents : _receivedCents)})',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.bebasNeue(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      height: 28 / 20,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_method == PaymentMethod.especes && !isNarrow) ...[
            const SizedBox(width: 12),
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Rendu : ${_fmtEuros(_change)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    final cancelButton = OutlinedButton(
      onPressed: () => Navigator.of(context).pop(),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: const Text(
        'Annuler (Retour)',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: isNarrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                validateButton,
                const SizedBox(height: 10),
                cancelButton,
              ],
            )
          : Row(
              children: [
                cancelButton,
                const SizedBox(width: 12),
                Expanded(child: validateButton),
              ],
            ),
    );
  }
}