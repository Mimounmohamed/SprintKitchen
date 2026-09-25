import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/inventory_models.dart';
import '../../services/api_client.dart' show ApiException;
import '../../services/inventory_service.dart';
import '../../theme/app_colors.dart';

class FamilyModalResult {
  const FamilyModalResult.saved(this.family, this.isNew) : deletedId = null;
  const FamilyModalResult.deleted(this.deletedId)
      : family = null,
        isNew = false;

  final IngredientFamily? family;
  final bool isNew;
  final String? deletedId;
}

Future<FamilyModalResult?> showFamilyModal(
  BuildContext context, {
  required IngredientFamily? family,
  required bool mobile,
}) {
  final content = _FamilyModalContent(family: family);

  if (mobile) {
    return showModalBottomSheet<FamilyModalResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => content,
    );
  }
  return showDialog<FamilyModalResult>(
    context: context,
    builder: (_) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: content,
      ),
    ),
  );
}

class _FamilyModalContent extends StatefulWidget {
  const _FamilyModalContent({required this.family});
  final IngredientFamily? family;

  @override
  State<_FamilyModalContent> createState() => _FamilyModalContentState();
}

class _FamilyModalContentState extends State<_FamilyModalContent> {
  final _service = InventoryService();
  late final TextEditingController _nameController;
  late final TextEditingController _emojiController;

  bool _saving = false;
  bool _deleting = false;
  String? _error;

  bool get _isEdit => widget.family != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.family?.name ?? '');
    _emojiController =
        TextEditingController(text: widget.family?.emoji ?? '📦');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emojiController.dispose();
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
      final emoji =
          _emojiController.text.trim().isEmpty ? '📦' : _emojiController.text.trim();
      if (_isEdit) {
        final updated = await _service.updateFamily(
          widget.family!.id,
          name: _nameController.text.trim(),
          emoji: emoji,
        );
        if (mounted) {
          Navigator.of(context).pop(FamilyModalResult.saved(updated, false));
        }
      } else {
        final created = await _service.createFamily(
          name: _nameController.text.trim(),
          emoji: emoji,
        );
        if (mounted) {
          Navigator.of(context).pop(FamilyModalResult.saved(created, true));
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
    final family = widget.family!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text(
          'Supprimer la famille "${family.name}" ? Les ingrédients associés ne seront pas effacés automatiquement.',
        ),
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
      await _service.deleteFamily(family.id);
      if (mounted) {
        Navigator.of(context).pop(FamilyModalResult.deleted(family.id));
      }
    } on ApiException catch (e) {
      // The server refuses with a message when ingredients still use this
      // family — surface it instead of closing the modal.
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
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null) ...[
                    _buildErrorBanner(_error!),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: 64,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Emoji'),
                            const SizedBox(height: 5),
                            TextField(
                              controller: _emojiController,
                              maxLength: 4,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 26),
                              decoration: InputDecoration(
                                counterText: '',
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 4, horizontal: 4),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide:
                                      const BorderSide(color: AppColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide:
                                      const BorderSide(color: AppColors.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: AppColors.brown, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Nom de la famille'),
                            const SizedBox(height: 5),
                            TextField(
                              controller: _nameController,
                              autofocus: true,
                              style: GoogleFonts.inter(
                                  fontSize: 13.5, color: AppColors.ink),
                              decoration: InputDecoration(
                                hintText: 'ex. Desserts & Sucreries',
                                hintStyle: GoogleFonts.inter(
                                    fontSize: 13.5, color: AppColors.muted),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide:
                                      const BorderSide(color: AppColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide:
                                      const BorderSide(color: AppColors.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: AppColors.brown, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
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
              _isEdit ? 'MODIFIER LA FAMILLE' : 'NOUVELLE FAMILLE',
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
            TextButton(
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
              _saving ? '…' : 'Enregistrer',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}