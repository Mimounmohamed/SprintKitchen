import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/order_models.dart' show OccupiedTableInfo;
import '../../models/pos_models.dart';
import '../../services/order_service.dart';
import '../../theme/app_colors.dart';

/// Holds the order fulfilment type and customer/table attributes.
/// Attributes from previous order types are preserved rather than erased.
class OrderDetailsResult {
  const OrderDetailsResult({
    this.orderType,
    this.tableNumber,
    this.clientName,
    this.deliveryAddress,
    this.deliveryPhone,
    this.notes,
  });

  /// Selected mode: dineIn (Sur Place), takeaway (À Emporter), or delivery (Livraison).
  final OrderType? orderType;

  /// Sur place — becomes `Table XX` on the order.
  final String? tableNumber;

  /// Client name (required for à emporter and livraison, optional for sur place).
  final String? clientName;

  /// Delivery address (required for livraison, optional for à emporter).
  final String? deliveryAddress;

  /// Contact phone (required for à emporter and livraison, optional for sur place).
  final String? deliveryPhone;

  /// Optional kitchen note / comment.
  final String? notes;
}

/// "Informations de la commande" popup shown before payment or when modifying order type / details.
///
/// Features:
/// - Switch order type seamlessly between Sur Place, À Emporter, and Livraison.
/// - Required validation for essential attributes per order type.
/// - Preserves previously entered attributes (never erases table, name, phone, etc.).
/// - Real-time occupied table validation for Sur Place.
class OrderDetailsModal extends StatefulWidget {
  const OrderDetailsModal({
    super.key,
    required this.orderType,
    required this.ticketNumber,
    required this.posteLabel,
    this.initialNotes,
    this.initialTable,
    this.initialClient,
    this.initialAddress,
    this.initialPhone,
    this.currentTicketNumber,
    this.submitLabel = 'VALIDER LES INFORMATIONS',
  });

  final OrderType orderType;
  final String ticketNumber;
  final String posteLabel;
  final String? initialNotes;
  final String? initialTable;
  final String? initialClient;
  final String? initialAddress;
  final String? initialPhone;
  final String? currentTicketNumber;
  final String submitLabel;

  @override
  State<OrderDetailsModal> createState() => _OrderDetailsModalState();
}

class _OrderDetailsModalState extends State<OrderDetailsModal> {
  final _formKey = GlobalKey<FormState>();
  final _tableController = TextEditingController();
  final _clientController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  late OrderType _activeOrderType;
  List<OccupiedTableInfo> _occupiedTables = [];
  bool _loadingOccupied = false;

  @override
  void initState() {
    super.initState();
    _activeOrderType = widget.orderType;

    if (widget.initialNotes != null) {
      _notesController.text = widget.initialNotes!;
    }
    if (widget.initialTable != null) {
      _tableController.text = widget.initialTable!
          .replaceFirst(RegExp(r'^table\s*', caseSensitive: false), '')
          .trim();
    }
    if (widget.initialClient != null) {
      _clientController.text = widget.initialClient!;
    }
    if (widget.initialAddress != null) {
      _addressController.text = widget.initialAddress!;
    }
    if (widget.initialPhone != null) {
      _phoneController.text = widget.initialPhone!;
    }

    if (_activeOrderType == OrderType.dineIn) {
      _loadOccupiedTables();
    }
  }

  Future<void> _loadOccupiedTables() async {
    setState(() => _loadingOccupied = true);
    try {
      final list = await OrderService().getOccupiedTables();
      if (mounted) {
        setState(() {
          _occupiedTables = list;
          _loadingOccupied = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingOccupied = false);
    }
  }

  @override
  void dispose() {
    _tableController.dispose();
    _clientController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  ({IconData icon, Color color, String label}) get _typeMeta {
    switch (_activeOrderType) {
      case OrderType.dineIn:
        return (
          icon: Icons.restaurant_rounded,
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
          icon: Icons.moped_rounded,
          color: const Color(0xFF0D9488),
          label: 'Livraison',
        );
    }
  }

  String _formatTableTwoDigits(String raw) {
    final clean = raw.toLowerCase().replaceFirst(RegExp(r'^table\s*'), '').trim();
    final n = int.tryParse(clean);
    if (n != null) {
      return n.toString().padLeft(2, '0');
    }
    return clean;
  }

  void _switchOrderType(OrderType type) {
    if (_activeOrderType == type) return;
    setState(() {
      _activeOrderType = type;
    });
    if (type == OrderType.dineIn && _occupiedTables.isEmpty && !_loadingOccupied) {
      _loadOccupiedTables();
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    // Preserve all attributes: if user entered text, use it; otherwise retain previous value without erasing!
    final enteredTable = _tableController.text.trim();
    final table = enteredTable.isNotEmpty
        ? _formatTableTwoDigits(enteredTable)
        : (widget.initialTable != null && widget.initialTable!.trim().isNotEmpty
            ? _formatTableTwoDigits(widget.initialTable!)
            : null);

    final enteredClient = _clientController.text.trim();
    final client = enteredClient.isNotEmpty
        ? enteredClient
        : widget.initialClient;

    final enteredPhone = _phoneController.text.trim();
    final phone = enteredPhone.isNotEmpty
        ? enteredPhone
        : widget.initialPhone;

    final enteredAddress = _addressController.text.trim();
    final address = enteredAddress.isNotEmpty
        ? enteredAddress
        : widget.initialAddress;

    final enteredNotes = _notesController.text.trim();
    final notes = enteredNotes.isNotEmpty
        ? enteredNotes
        : widget.initialNotes;

    Navigator.of(context).pop(
      OrderDetailsResult(
        orderType: _activeOrderType,
        tableNumber: table,
        clientName: client,
        deliveryAddress: address,
        deliveryPhone: phone,
        notes: notes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dialogWidth = (size.width - 32) < 480 ? size.width - 32 : 480.0;
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
                          _buildTypeSelector(),
                          Flexible(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                              child: _buildFields(meta),
                            ),
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
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(meta.icon, size: 18, color: AppColors.brandDark),
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
                  style: GoogleFonts.bebasNeue(
                    color: Colors.white,
                    fontSize: 20,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  '${widget.posteLabel} • Mode actuel : ${meta.label}',
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

  Widget _buildTypeSelector() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TYPE DE COMMANDE',
                style: GoogleFonts.openSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: AppColors.textMuted,
                ),
              ),
              const Text(
                'Les attributs sont conservés lors du changement',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF9CA3AF),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildTypeTab(
                OrderType.dineIn,
                'Sur Place',
                Icons.restaurant_rounded,
                const Color(0xFFE11D48),
              ),
              const SizedBox(width: 8),
              _buildTypeTab(
                OrderType.takeaway,
                'À Emporter',
                Icons.shopping_bag_outlined,
                const Color(0xFF2563EB),
              ),
              const SizedBox(width: 8),
              _buildTypeTab(
                OrderType.delivery,
                'Livraison',
                Icons.moped_rounded,
                const Color(0xFF0D9488),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTab(
    OrderType type,
    String label,
    IconData icon,
    Color activeColor,
  ) {
    final bool isSelected = _activeOrderType == type;
    return Expanded(
      child: InkWell(
        onTap: () => _switchOrderType(type),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? activeColor : const Color(0xFFD1D5DB),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? Colors.white : const Color(0xFF4B5563),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
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

  Widget _buildFields(({IconData icon, Color color, String label}) meta) {
    switch (_activeOrderType) {
      case OrderType.dineIn:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('NUMÉRO DE TABLE (OBLIGATOIRE)'),
            const SizedBox(height: 6),
            _field(
              controller: _tableController,
              hint: 'ex. 05',
              icon: Icons.table_restaurant_outlined,
              keyboardType: TextInputType.number,
              autofocus: true,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              maxLength: 2,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Le numéro de table est requis pour Sur Place';
                }
                final clean = v.trim();
                final cleanNum = int.tryParse(clean);
                final occupied = _occupiedTables.cast<OccupiedTableInfo?>().firstWhere(
                  (t) {
                    if (t == null) return false;
                    if (widget.currentTicketNumber != null &&
                        (t.ticketNumber == widget.currentTicketNumber ||
                         t.ticketNumber == widget.ticketNumber ||
                         '#${t.ticketNumber}' == widget.ticketNumber)) {
                      return false;
                    }
                    final tClean = t.tableNumber
                        .toLowerCase()
                        .replaceFirst(RegExp(r'^table\s*'), '')
                        .trim();
                    final tNum = int.tryParse(tClean);
                    if (cleanNum != null && tNum != null) {
                      return cleanNum == tNum;
                    }
                    return tClean == clean.toLowerCase();
                  },
                  orElse: () => null,
                );
                if (occupied != null) {
                  return 'Table $clean déjà occupée (#${occupied.ticketNumber})';
                }
                return null;
              },
            ),
            if (_loadingOccupied) ...[
              const SizedBox(height: 6),
              const Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Vérification des tables en cours...',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ] else if (_occupiedTables.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildOccupiedTablesBanner(),
            ],
            const SizedBox(height: 14),
            _sectionLabel('NOM DU CLIENT (OPTIONNEL)'),
            const SizedBox(height: 6),
            _field(
              controller: _clientController,
              hint: 'ex. Thomas B.',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 14),
            _sectionLabel('NUMÉRO DE TÉLÉPHONE (OPTIONNEL)'),
            const SizedBox(height: 6),
            _field(
              controller: _phoneController,
              hint: 'ex. 06 12 34 56 78',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),
            _sectionLabel('NOTE CUISINE / COMMENTAIRE (OPTIONNEL)'),
            const SizedBox(height: 6),
            _field(
              controller: _notesController,
              hint: 'ex. Sans sel sur les frites, prêt à 12h30...',
              icon: Icons.chat_bubble_outline_rounded,
            ),
          ],
        );

      case OrderType.takeaway:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('NOM DU CLIENT (OBLIGATOIRE)'),
            const SizedBox(height: 6),
            _field(
              controller: _clientController,
              hint: 'ex. Karim / Thomas B.',
              icon: Icons.person_outline,
              autofocus: true,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Le nom du client est requis pour À emporter'
                  : null,
            ),
            const SizedBox(height: 14),
            _sectionLabel('NUMÉRO DE TÉLÉPHONE (OBLIGATOIRE)'),
            const SizedBox(height: 6),
            _field(
              controller: _phoneController,
              hint: 'ex. 06 12 34 56 78 / 0555 12 34 56',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Le numéro de téléphone est requis'
                  : null,
            ),
            const SizedBox(height: 14),
            _sectionLabel('ADRESSE (OPTIONNELLE)'),
            const SizedBox(height: 6),
            _field(
              controller: _addressController,
              hint: 'ex. Quartier ou adresse de contact',
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 14),
            _sectionLabel('NOTE CUISINE / COMMENTAIRE (OPTIONNEL)'),
            const SizedBox(height: 6),
            _field(
              controller: _notesController,
              hint: 'ex. Sans sel sur les frites, prêt à 12h30...',
              icon: Icons.chat_bubble_outline_rounded,
            ),
          ],
        );

      case OrderType.delivery:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('NOM DU CLIENT (OBLIGATOIRE)'),
            const SizedBox(height: 6),
            _field(
              controller: _clientController,
              hint: 'ex. Sarah / Thomas B.',
              icon: Icons.person_outline,
              autofocus: true,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Le nom du client est requis pour la livraison'
                  : null,
            ),
            const SizedBox(height: 14),
            _sectionLabel('NUMÉRO DE TÉLÉPHONE (OBLIGATOIRE)'),
            const SizedBox(height: 6),
            _field(
              controller: _phoneController,
              hint: 'ex. 06 12 34 56 78',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Le téléphone est requis pour la livraison'
                  : null,
            ),
            const SizedBox(height: 14),
            _sectionLabel('ADRESSE DE LIVRAISON (OBLIGATOIRE)'),
            const SizedBox(height: 6),
            _field(
              controller: _addressController,
              hint: 'Rue, bâtiment, étage, digicode...',
              icon: Icons.location_on_outlined,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? "L'adresse de livraison est requise"
                  : null,
            ),
            const SizedBox(height: 14),
            _sectionLabel('NOTE CUISINE / COMMENTAIRE (OPTIONNEL)'),
            const SizedBox(height: 6),
            _field(
              controller: _notesController,
              hint: 'ex. Sonner interphone #4, sauce supplémentaire...',
              icon: Icons.chat_bubble_outline_rounded,
            ),
          ],
        );
    }
  }

  Widget _buildOccupiedTablesBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: AppColors.danger),
              SizedBox(width: 6),
              Text(
                'Tables actuellement occupées :',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: () {
              final sorted = List<OccupiedTableInfo>.from(_occupiedTables)
                ..sort((a, b) {
                  final cleanA = a.tableNumber.replaceAll(RegExp(r'[^0-9]'), '');
                  final cleanB = b.tableNumber.replaceAll(RegExp(r'[^0-9]'), '');
                  final numA = int.tryParse(cleanA) ?? 0;
                  final numB = int.tryParse(cleanB) ?? 0;
                  return numA.compareTo(numB);
                });
              return sorted.map((t) {
                final twoDigits = _formatTableTwoDigits(t.tableNumber);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Text(
                    twoDigits,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFB91C1C),
                    ),
                  ),
                );
              }).toList();
            }(),
          ),
        ],
      ),
    );
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
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      buildCounter: maxLength != null
          ? (context, {required currentLength, required isFocused, maxLength}) => null
          : null,
      validator: validator,
      style: GoogleFonts.openSans(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.openSans(fontSize: 13, color: AppColors.textMuted),
        prefixIcon: Icon(icon, size: 18, color: AppColors.textSecondary),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                  borderRadius: BorderRadius.circular(10),
                ),
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
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: Text(
                widget.submitLabel,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.brandDark,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}