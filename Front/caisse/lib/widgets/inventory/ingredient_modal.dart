import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/inventory_models.dart';
import '../../services/api_client.dart' show ApiException;
import '../../services/inventory_service.dart';
import '../../theme/app_colors.dart';

/// What happened when the modal closed.
class IngredientModalResult {
  const IngredientModalResult.saved(this.ingredient, this.isNew)
      : deletedId = null;
  const IngredientModalResult.deleted(this.deletedId)
      : ingredient = null,
        isNew = false;

  final Ingredient? ingredient;
  final bool isNew;
  final String? deletedId;
}

/// Shows the add/edit ingredient popup: a centered card on desktop, a
/// bottom sheet on mobile (matches the web admin's ModalShell behavior).
Future<IngredientModalResult?> showIngredientModal(
  BuildContext context, {
  required Ingredient? ingredient,
  required List<IngredientFamily> families,
  required String? defaultFamily,
  required bool mobile,
}) {
  final content = _IngredientModalContent(
    ingredient: ingredient,
    families: families,
    defaultFamily: defaultFamily,
  );

  if (mobile) {
    return showModalBottomSheet<IngredientModalResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => content,
    );
  }
  return showDialog<IngredientModalResult>(
    context: context,
    builder: (_) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
        child: content,
      ),
    ),
  );
}

class _IngredientModalContent extends StatefulWidget {
  const _IngredientModalContent({
    required this.ingredient,
    required this.families,
    required this.defaultFamily,
  });

  final Ingredient? ingredient;
  final List<IngredientFamily> families;
  final String? defaultFamily;

  @override
  State<_IngredientModalContent> createState() =>
      _IngredientModalContentState();
}

class _IngredientModalContentState extends State<_IngredientModalContent> {
  final _service = InventoryService();
  late final TextEditingController _nameController;
  late final TextEditingController _unitController;
  late final TextEditingController _notesController;
  late String _family;

  bool _saving = false;
  bool _deleting = false;
  String? _error;

  bool get _isEdit => widget.ingredient != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.ingredient?.name ?? '');
    _unitController = TextEditingController(text: widget.ingredient?.unit ?? '');
    _notesController = TextEditingController(text: widget.ingredient?.notes ?? '');
    _family = widget.ingredient?.family ??
        widget.defaultFamily ??
        (widget.families.isNotEmpty ? widget.families.first.slug : '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'Le nom est requis.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_isEdit) {
        final updated = await _service.updateIngredient(
          widget.ingredient!.id,
          name: _nameController.text.trim(),
          family: _family,
          unit: _unitController.text.trim(),
          notes: _notesController.text.trim(),
        );
        if (mounted) {
          Navigator.of(context)
              .pop(IngredientModalResult.saved(updated, false));
        }
      } else {
        final created = await _service.createIngredient(
          name: _nameController.text.trim(),
          family: _family,
          unit: _unitController.text.trim(),
          notes: _notesController.text.trim(),
        );
        if (mounted) {
          Navigator.of(context).pop(IngredientModalResult.saved(created, true));
        }
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Une erreur est survenue.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ingredient = widget.ingredient!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text('Supprimer "${ingredient.name}" ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _deleting = true);
    try {
      await _service.deleteIngredient(ingredient.id);
      if (mounted) {
        Navigator.of(context).pop(IngredientModalResult.deleted(ingredient.id));
      }
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _deleting = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur lors de la suppression.';
        _deleting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null) ...[
                      _buildErrorBanner(_error!),
                      const SizedBox(height: 16),
                    ],
                    _label('Nom'),
                    const SizedBox(height: 5),
                    _textField(_nameController, hint: 'ex. Steak Haché 180g'),
                    const SizedBox(height: 16),
                    _label('Famille'),
                    const SizedBox(height: 5),
                    _familyDropdown(),
                    const SizedBox(height: 16),
                    _label('Unité'),
                    const SizedBox(height: 5),
                    _textField(_unitController,
                        hint: 'kg, L, portion, unité…'),
                    const SizedBox(height: 16),
                    _label('Notes'),
                    const SizedBox(height: 5),
                    _textField(_notesController,
                        hint: 'Rupture fournisseur, Livraison mardi…'),
                  ],
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 12, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _isEdit ? "MODIFIER L'INGRÉDIENT" : 'AJOUTER UN INGRÉDIENT',
              style: GoogleFonts.bebasNeue(
                fontSize: 24,
                letterSpacing: 0.6,
                color: AppColors.ink,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 20, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFDEAE8),
        border: Border.all(color: const Color(0xFFF5C6C2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message,
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.red)),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: AppColors.muted,
          letterSpacing: 0.6,
        ),
      );

  Widget _textField(TextEditingController controller, {String? hint}) {
    return TextField(
      controller: controller,
      style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 13.5, color: AppColors.muted),
        filled: true,
        fillColor: AppColors.surface,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.brown, width: 2),
        ),
      ),
    );
  }

  Widget _familyDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: widget.families.any((f) => f.slug == _family)
              ? _family
              : null,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.muted),
          style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.ink),
          items: widget.families
              .map((f) => DropdownMenuItem(
                    value: f.slug,
                    child: Text('${f.emoji}  ${f.name}'),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _family = v);
          },
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: [
          if (_isEdit)
            Padding(
              padding: const EdgeInsets.only(right: 0),
              child: TextButton(
                onPressed: _deleting ? null : _delete,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.red,
                  side: const BorderSide(color: AppColors.red, width: 1.5),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(_deleting ? '…' : 'Supprimer'),
              ),
            ),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.ink,
              side: const BorderSide(color: AppColors.border, width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.brown,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              _saving ? '…' : (_isEdit ? 'Enregistrer' : 'Ajouter'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}