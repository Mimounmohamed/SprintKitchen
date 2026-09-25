import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/pos_models.dart';
import '../../theme/app_colors.dart';

/// What the cashier entered before going to payment. Only the fields that
/// apply to the order's type are ever filled in.
class OrderDetailsResult {
  const OrderDetailsResult({
    this.tableNumber,
    this.clientName,
    this.deliveryAddress,
    this.deliveryPhone,
  });

  /// Sur place — becomes `Table 5` on the order's `buzzerNumber`.
  final String? tableNumber;

  /// À emporter — optional, goes on `clientName`.
  final String? clientName;

  /// Livraison — required, go on `delivery.address` / `delivery.phone`.
  final String? deliveryAddress;
  final String? deliveryPhone;
}

/// "Informations de la commande" popup shown right before payment, so the
/// cashier fills in what the order type needs:
/// - Sur place: table number (required)
/// - Livraison: address + phone (both required)
/// - À emporter: client name (optional)
///
/// Self-blurring, same as EncaissementModal — call with
/// `barrierColor: Colors.transparent`.
class OrderDetailsModal extends StatefulWidget {
  const OrderDetailsModal({
    super.key,
    required this.orderType,
    required this.ticketNumber,
    required this.posteLabel,
  });

  final OrderType orderType;
  final String ticketNumber;
  final String posteLabel;

  @override
  State<OrderDetailsModal> createState() => _OrderDetailsModalState();
}

class _OrderDetailsModalState extends State<OrderDetailsModal> {
  final _formKey = GlobalKey<FormState>();
  final _tableController = TextEditingController();
  final _clientController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _tableController.dispose();
    _clientController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  ({IconData icon, Color color, String label}) get _typeMeta {
    switch (widget.orderType) {
      case OrderType.dineIn:
        return (
          icon: Icons.shopping_cart_outlined,
          color: const Color(0xFFE11D48),
          label: 'Sur Place',
        );
      case OrderType.takeaway:
        return (
          icon: Icons.shopping_bag_outlined,
          color: const Color(0xFF2563EB),
          label: 'À Emporter',
        );
      case OrderType.delivery:
        return (
          icon: Icons.local_shipping_outlined,
          color: const Color(0xFF0D9488),
          label: 'Livraison',
        );
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      OrderDetailsResult(
        tableNumber: widget.orderType == OrderType.dineIn
            ? _tableController.text.trim()
            : null,
        clientName: widget.orderType == OrderType.takeaway
            ? _clientController.text.trim()
            : null,
        deliveryAddress: widget.orderType == OrderType.delivery
            ? _addressController.text.trim()
            : null,
        deliveryPhone: widget.orderType == OrderType.delivery
            ? _phoneController.text.trim()
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dialogWidth = (size.width - 32) < 460 ? size.width - 32 : 460.0;
    final meta = _typeMeta;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.black.withValues(alpha: 0.55)),
            ),
          ),
        ),
        Center(
          child: GestureDetector(
            onTap: () {},
            behavior: HitTestBehavior.opaque,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: dialogWidth),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.hardEdge,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 40,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildHeader(meta),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: _buildFields(meta),
                          ),
                          _buildFooter(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(({IconData icon, Color color, String label}) meta) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: const BoxDecoration(
        color: AppColors.brandDark,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(meta.icon, size: 16, color: AppColors.brandDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INFORMATIONS — TICKET N° ${widget.ticketNumber}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.posteLabel} — ${meta.label}',
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
          Container(
            decoration: BoxDecoration(
              color: AppColors.brandDarkHover,
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

  Widget _buildFields(({IconData icon, Color color, String label}) meta) {
    switch (widget.orderType) {
      case OrderType.dineIn:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('NUMÉRO DE TABLE'),
            const SizedBox(height: 8),
            _field(
              controller: _tableController,
              hint: 'ex. 5',
              icon: Icons.table_restaurant_outlined,
              keyboardType: TextInputType.text,
              autofocus: true,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Le numéro de table est requis'
                  : null,
            ),
          ],
        );
      case OrderType.takeaway:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('NOM DU CLIENT (OPTIONNEL)'),
            const SizedBox(height: 8),
            _field(
              controller: _clientController,
              hint: 'ex. Thomas B.',
              icon: Icons.person_outline,
              autofocus: true,
            ),
          ],
        );
      case OrderType.delivery:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('ADRESSE DE LIVRAISON'),
            const SizedBox(height: 8),
            _field(
              controller: _addressController,
              hint: 'Rue, bâtiment, étage...',
              icon: Icons.location_on_outlined,
              autofocus: true,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? "L'adresse est requise"
                  : null,
            ),
            const SizedBox(height: 16),
            _sectionLabel('TÉLÉPHONE'),
            const SizedBox(height: 8),
            _field(
              controller: _phoneController,
              hint: 'ex. 06 12 34 56 78',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Le téléphone est requis'
                  : null,
            ),
          ],
        );
    }
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: GoogleFonts.openSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: AppColors.textMuted,
        ),
      );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool autofocus = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.openSans(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.openSans(fontSize: 14, color: AppColors.textMuted),
        prefixIcon: Icon(icon, size: 18, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surface,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.brandDark, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.danger, width: 2),
        ),
      ),
      onFieldSubmitted: (_) => _submit(),
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
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'Annuler',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text(
                'CONTINUER VERS LE PAIEMENT',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.brandDark,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}