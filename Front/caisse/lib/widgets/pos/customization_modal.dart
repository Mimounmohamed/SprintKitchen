import 'package:flutter/material.dart';
import '../../models/pos_models.dart';
import '../../theme/app_colors.dart';

/// The "PERSONNALISATION — {item}" dialog. Returns a fully-built
/// [TicketLine] via Navigator.pop when the user validates, or null
/// if they cancel/dismiss.
class CustomizationModal extends StatefulWidget {
  const CustomizationModal({super.key, required this.item});
  final MenuItem item;

  @override
  State<CustomizationModal> createState() => _CustomizationModalState();
}

class _CustomizationModalState extends State<CustomizationModal> {
  final Map<String, List<CustomizationOption>> _selections = {};
  final Set<String> _removedIngredients = {};
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    for (final group in widget.item.customizationGroups) {
      _selections[group.name] =
          group.options.where((o) => o.isDefault).toList();
    }
  }

  double get _extrasTotal {
    double sum = 0;
    for (final options in _selections.values) {
      for (final o in options) {
        sum += o.priceModifier;
      }
    }
    return sum;
  }

  double get _lineTotal => (widget.item.price + _extrasTotal) * _quantity;

  bool get _isValid {
    for (final group in widget.item.customizationGroups) {
      final selected = _selections[group.name] ?? [];
      if (group.isRequired && selected.isEmpty) return false;
      if (group.minChoices > 0 && selected.length < group.minChoices) {
        return false;
      }
    }
    return true;
  }

  void _toggleOption(CustomizationGroup group, CustomizationOption option) {
    if (!option.isAvailable) return;
    setState(() {
      final current =
          List<CustomizationOption>.from(_selections[group.name] ?? []);
      final alreadySelected = current.any((o) => o.label == option.label);

      if (group.isSingle) {
        _selections[group.name] = alreadySelected ? [] : [option];
        return;
      }

      if (alreadySelected) {
        current.removeWhere((o) => o.label == option.label);
      } else {
        final max = group.maxChoices > 0 ? group.maxChoices : 999;
        if (current.length >= max) return;
        current.add(option);
      }
      _selections[group.name] = current;
    });
  }

  void _toggleIngredient(String ingredient) {
    setState(() {
      if (_removedIngredients.contains(ingredient)) {
        _removedIngredients.remove(ingredient);
      } else {
        _removedIngredients.add(ingredient);
      }
    });
  }

  void _validate() {
    if (!_isValid) return;

    final customizations = widget.item.customizationGroups
        .where((g) => (_selections[g.name] ?? []).isNotEmpty)
        .map((g) => AppliedCustomization(
              groupName: g.name,
              selectedOptions: (_selections[g.name] ?? [])
                  .map((o) => SelectedOption(
                      label: o.label, priceModifier: o.priceModifier))
                  .toList(),
            ))
        .toList();

    final subtitleParts = <String>[
      ...customizations.expand((c) => c.selectedOptions.map((o) => o.label)),
      ..._removedIngredients.map((i) => 'Sans $i'),
    ];

    Navigator.of(context).pop(
      TicketLine(
        name: widget.item.name,
        subtitle: subtitleParts.isEmpty ? null : subtitleParts.join(', '),
        unitPrice: widget.item.price,
        extrasTotal: _extrasTotal,
        quantity: _quantity,
        productId: widget.item.id,
        customizations: customizations,
        removedIngredients: _removedIngredients.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(item),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final group in item.customizationGroups) ...[
                        _buildGroup(group),
                        const SizedBox(height: 18),
                      ],
                      if (item.ingredients.isNotEmpty)
                        _buildIngredientsSection(item),
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

  Widget _buildHeader(MenuItem item) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      color: AppColors.brandDark,
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              children: [
                Text(
                  'PERSONNALISATION — ${item.name.toUpperCase()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${item.price.toStringAsFixed(2).replaceAll('.', ',')} €',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: AppColors.brandDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildGroup(CustomizationGroup group) {
    final selected = _selections[group.name] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                group.name.toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (group.isRequired)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text(
                  'OBLIGATOIRE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.danger,
                  ),
                ),
              ),
            if (!group.isSingle)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  '${selected.length} sélectionnée${selected.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: group.options.map((option) {
            final isSelected = selected.any((o) => o.label == option.label);
            return _optionChip(group, option, isSelected);
          }).toList(),
        ),
      ],
    );
  }

  Widget _optionChip(
      CustomizationGroup group, CustomizationOption option, bool isSelected) {
    final disabled = !option.isAvailable;
    return InkWell(
      onTap: disabled ? null : () => _toggleOption(group, option),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minWidth: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: disabled
              ? AppColors.menuTileDisabled
              : isSelected
                  ? AppColors.brandDark
                  : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.gold : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    option.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: disabled
                          ? AppColors.textMuted
                          : isSelected
                              ? Colors.white
                              : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.check_circle, size: 14, color: AppColors.gold),
                ],
              ],
            ),
            if (option.priceModifier != 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${option.priceModifier > 0 ? '+' : ''}${option.priceModifier.toStringAsFixed(2).replaceAll('.', ',')} €',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? AppColors.gold : AppColors.textSecondary,
                  ),
                ),
              )
            else if (option.isDefault)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text(
                  'Inclus',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientsSection(MenuItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'INGRÉDIENTS À RETIRER',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: item.ingredients.map((ingredient) {
            final removed = _removedIngredients.contains(ingredient);
            return InkWell(
              onTap: () => _toggleIngredient(ingredient),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: removed
                      ? AppColors.danger.withValues(alpha: 0.1)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: removed ? AppColors.danger : AppColors.border,
                  ),
                ),
                child: Text(
                  'Sans $ingredient',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: removed ? AppColors.danger : AppColors.textPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _qtyButton(Icons.remove, () {
                if (_quantity > 1) setState(() => _quantity--);
              }),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '$_quantity',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              _qtyButton(Icons.add, () => setState(() => _quantity++)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_lineTotal.toStringAsFixed(2).replaceAll('.', ',')} €',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (_extrasTotal != 0)
                      Text(
                        '(+${_extrasTotal.toStringAsFixed(2).replaceAll('.', ',')} € suppléments)',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isValid ? _validate : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text(
                    'VALIDER & AJOUTER AU TICKET',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }
}