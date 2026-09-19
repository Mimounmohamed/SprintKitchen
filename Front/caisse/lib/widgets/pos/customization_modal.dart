import 'dart:ui';
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
  static const double _narrowBreakpoint = 640;
  static const double _maxDialogWidth = 1040;
  static const double _maxDialogHeight = 720;

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
    final activeGroups = widget.item.customizationGroups.where((g) {
      final name = g.name.toLowerCase();
      return !name.contains('accompagnement') &&
          !name.contains('ingrédient') &&
          !name.contains('ingredient');
    });

    for (final group in activeGroups) {
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
        .where((g) {
          final name = g.name.toLowerCase();
          return !name.contains('accompagnement') &&
              !name.contains('ingrédient') &&
              !name.contains('ingredient');
        })
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

  String _money(num value) =>
      '${value.toStringAsFixed(2).replaceAll('.', ',')} €';

  /// Renders options evenly in a single row when they fit, or wraps them
  /// into rows scrollable from UP to DOWN when there are extra elements.
  Widget _buildVerticalOptionsGrid({
    required List<Widget> children,
    required int itemCount,
    double minItemWidth = 115,
    double itemHeight = 70,
    double maxHeight = 165,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        int columns = (availableWidth / (minItemWidth + 8)).floor();
        if (columns < 1) columns = 1;

        // If all items fit in one row, expand them evenly
        if (itemCount <= columns) {
          return Row(
            children: children.asMap().entries.map((entry) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: entry.key == itemCount - 1 ? 0 : 8,
                  ),
                  child: entry.value,
                ),
              );
            }).toList(),
          );
        }

        // When there are extra elements, wrap into rows and scroll UP to DOWN
        final cardWidth = (availableWidth - (columns - 1) * 8) / columns;

        final wrapContent = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: children.map((child) {
            return SizedBox(
              width: cardWidth,
              height: itemHeight,
              child: child,
            );
          }).toList(),
        );

        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
            },
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              physics: const BouncingScrollPhysics(),
              child: wrapContent,
            ),
          ),
        );
      },
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
            child: SizedBox(
              width: dialogWidth,
              height: dialogHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.hardEdge,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
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
                    child: Column(
                      children: [
                        _buildHeader(isNarrow),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.all(isNarrow ? 16 : 24),
                            child: _buildBody(),
                          ),
                        ),
                        _buildFooter(isNarrow),
                      ],
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

  Widget _buildHeader(bool isNarrow) {
    final item = widget.item;
    final hasCustomDesc = item.description != null &&
        item.description!.isNotEmpty &&
        item.description != item.name;

    return Container(
      padding: EdgeInsets.fromLTRB(isNarrow ? 14 : 20, 16, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.brandDark,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    Text(
                      'PERSONNALISATION — ${item.name.toUpperCase()}',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: isNarrow ? 13 : 15,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _money(item.price),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: AppColors.brandDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  hasCustomDesc
                      ? item.description!
                      : 'Sélectionnez la cuisson, la boisson, l\'accompagnement et les suppléments',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final item = widget.item;
    var sectionNumber = 0;

    // Filter out 'Accompagnement' and duplicate 'Ingrédient' groups
    final groups = item.customizationGroups.where((g) {
      final name = g.name.toLowerCase();
      return !name.contains('accompagnement') &&
          !name.contains('ingrédient') &&
          !name.contains('ingredient');
    }).toList();

    // Aggregate ingredients
    final ingredientGroup =
        item.customizationGroups.cast<CustomizationGroup?>().firstWhere(
              (g) =>
                  g != null &&
                  (g.name.toLowerCase().contains('ingrédient') ||
                      g.name.toLowerCase().contains('ingredient')),
              orElse: () => null,
            );

    final Set<String> allIngredients = {
      ...item.ingredients,
      if (ingredientGroup != null)
        ...ingredientGroup.options.map((o) =>
            o.label.replaceFirst(RegExp(r'^Sans\s+', caseSensitive: false), '')),
    };

    if (allIngredients.isEmpty) {
      allIngredients.addAll(['Oignon', 'Tomate', 'Salade', 'Cornichon']);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in groups) ...[
          _buildGroup(group, ++sectionNumber),
          const SizedBox(height: 26),
        ],
        _buildIngredientsSection(allIngredients.toList(), ++sectionNumber),
      ],
    );
  }

  Widget _buildGroup(CustomizationGroup group, int number) {
    final selected = _selections[group.name] ?? [];
    final isSupplements = group.name.toLowerCase().contains('suppl') ||
        group.name.toLowerCase().contains('extra') ||
        (!group.isRequired &&
            group.options.isNotEmpty &&
            group.options.every((o) => o.priceModifier > 0));

    final isCuisson = group.name.toLowerCase().contains('cuisson') ||
        (group.isSingle &&
            group.isRequired &&
            group.options.length <= 3 &&
            group.options.every((o) => o.priceModifier == 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGroupHeader(group, number, selected),
        const SizedBox(height: 12),
        if (isSupplements)
          _buildSupplementsRow(group, selected)
        else if (isCuisson)
          _buildCuissonRow(group, selected)
        else
          _buildSauceRow(group, selected),
      ],
    );
  }

  Widget _buildGroupHeader(CustomizationGroup group, int number,
      List<CustomizationOption> selected) {
    final selectedLabel = selected.isEmpty ? null : selected.first.label;

    Widget? badgeOrSubtitle;
    if (group.isRequired && group.isSingle) {
      badgeOrSubtitle = Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'OBLIGATOIRE (1 CHOIX)',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFFE65100),
            letterSpacing: 0.3,
          ),
        ),
      );
    } else if (!group.isSingle && group.minChoices > 0) {
      final text = group.minChoices == group.maxChoices
          ? '(${group.minChoices} choix possible${group.minChoices > 1 ? 's' : ''})'
          : '(${group.minChoices} à ${group.maxChoices} choix possibles)';
      badgeOrSubtitle = Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textMuted,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    Widget? rightWidget;
    if (group.isRequired && group.isSingle && selectedLabel != null) {
      rightWidget = Text(
        'Sélectionné : $selectedLabel',
        style: const TextStyle(
          fontSize: 12.5,
          color: AppColors.textMuted,
          fontWeight: FontWeight.w600,
        ),
      );
    } else if (!group.isSingle &&
        selected.isNotEmpty &&
        !group.name.toLowerCase().contains('suppl') &&
        !group.name.toLowerCase().contains('extra')) {
      rightWidget = Text(
        '${selected.length} sélectionnée${selected.length > 1 ? 's' : ''}',
        style: const TextStyle(
          fontSize: 12.5,
          color: AppColors.success,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return Row(
      children: [
        Container(
          width: 5,
          height: 16,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: AppColors.brandDark,
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
        Text(
          '$number. ${group.name.toUpperCase()}',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14.5,
            color: AppColors.textPrimary,
          ),
        ),
        if (badgeOrSubtitle != null) ...[
          const SizedBox(width: 8),
          badgeOrSubtitle,
        ],
        const Spacer(),
        ?rightWidget,
      ],
    );
  }

  /// 1. Cuisson Row
  Widget _buildCuissonRow(
      CustomizationGroup group, List<CustomizationOption> selected) {
    return _buildVerticalOptionsGrid(
      itemCount: group.options.length,
      minItemWidth: 140,
      itemHeight: 58,
      maxHeight: 130,
      children: group.options.map((option) {
        final isSelected = selected.any((o) => o.label == option.label);
        return _buildCuissonCard(group, option, isSelected);
      }).toList(),
    );
  }

  Widget _buildCuissonCard(
      CustomizationGroup group, CustomizationOption option, bool isSelected) {
    final disabled = !option.isAvailable;
    return InkWell(
      onTap: disabled ? null : () => _toggleOption(group, option),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: disabled
              ? AppColors.menuTileDisabled
              : isSelected
                  ? AppColors.brandDark
                  : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.gold : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              option.label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
                color: disabled
                    ? AppColors.textMuted
                    : isSelected
                        ? AppColors.gold
                        : AppColors.textPrimary,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.check,
                size: 18,
                color: AppColors.gold,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 2. Choix de la sauce (Larger container cards, scrolls up to down if extra elements)
  Widget _buildSauceRow(
      CustomizationGroup group, List<CustomizationOption> selected) {
    return _buildVerticalOptionsGrid(
      itemCount: group.options.length,
      minItemWidth: 115,
      itemHeight: 70,
      maxHeight: 165,
      children: group.options.map((option) {
        final isSelected = selected.any((o) => o.label == option.label);
        return _buildSauceCard(group, option, isSelected);
      }).toList(),
    );
  }

  Widget _buildSauceCard(
      CustomizationGroup group, CustomizationOption option, bool isSelected) {
    final disabled = !option.isAvailable;

    String? subtitle;
    try {
      final dynamic dyn = option;
      final desc = dyn.description ?? dyn.subtitle ?? dyn.sublabel;
      if (desc != null && desc.toString().trim().isNotEmpty) {
        subtitle = desc.toString().trim();
      }
    } catch (_) {}

    if (subtitle == null) {
      if (option.priceModifier != 0) {
        subtitle =
            '${option.priceModifier > 0 ? '+' : ''}${_money(option.priceModifier)}';
      } else if (option.isDefault) {
        subtitle = isSelected ? 'Coché' : 'Inclus';
      } else if (isSelected) {
        subtitle = 'Coché';
      }
    } else if (isSelected) {
      subtitle = 'Coché';
    }

    return InkWell(
      onTap: disabled ? null : () => _toggleOption(group, option),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 70,
        decoration: BoxDecoration(
          color: disabled
              ? AppColors.menuTileDisabled
              : isSelected
                  ? const Color(0xFFEBF7EE)
                  : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.success : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    option.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: disabled
                          ? AppColors.textMuted
                          : isSelected
                              ? AppColors.success
                              : AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color:
                            isSelected ? AppColors.success : AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Positioned(
                top: 7,
                right: 7,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 3. Suppléments & Extras (Larger container cards, scrolls up to down if extra elements)
  Widget _buildSupplementsRow(
      CustomizationGroup group, List<CustomizationOption> selected) {
    return _buildVerticalOptionsGrid(
      itemCount: group.options.length,
      minItemWidth: 140,
      itemHeight: 70,
      maxHeight: 165,
      children: group.options.map((option) {
        final isSelected = selected.any((o) => o.label == option.label);
        return _buildSupplementCard(group, option, isSelected);
      }).toList(),
    );
  }

  Widget _buildSupplementCard(
      CustomizationGroup group, CustomizationOption option, bool isSelected) {
    final disabled = !option.isAvailable;

    return InkWell(
      onTap: disabled ? null : () => _toggleOption(group, option),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: disabled
              ? AppColors.menuTileDisabled
              : isSelected
                  ? const Color(0xFFEBF7EE)
                  : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.success : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: disabled
                            ? AppColors.textMuted
                            : isSelected
                                ? AppColors.success
                                : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.check_circle,
                      size: 16,
                      color: AppColors.success,
                    ),
                  ],
                ],
              ),
              if (option.priceModifier != 0) ...[
                const SizedBox(height: 3),
                Text(
                  '${option.priceModifier > 0 ? '+' : ''}${_money(option.priceModifier)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? AppColors.success : AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 4. Ingrédients à retirer (Larger container cards in RED, scrolls up to down if extra elements)
  Widget _buildIngredientsSection(List<String> ingredients, int number) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 5,
              height: 16,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            Text(
              '$number. INGRÉDIENTS À RETIRER',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '(Sélectionner pour exclure)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
            const Spacer(),
            if (_removedIngredients.isNotEmpty)
              Text(
                '${_removedIngredients.length} retiré${_removedIngredients.length > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _buildVerticalOptionsGrid(
          itemCount: ingredients.length,
          minItemWidth: 140,
          itemHeight: 70,
          maxHeight: 165,
          children: ingredients.map((ingredient) {
            final removed = _removedIngredients.contains(ingredient);
            return _buildIngredientCard(ingredient, removed);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildIngredientCard(String ingredient, bool removed) {
    return InkWell(
      onTap: () => _toggleIngredient(ingredient),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: removed ? const Color(0xFFFFF5F5) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: removed ? AppColors.danger : AppColors.border,
            width: 2,
          ),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  'Sans $ingredient',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: removed ? FontWeight.w800 : FontWeight.w700,
                    fontSize: 13.5,
                    color: removed ? AppColors.danger : AppColors.textPrimary,
                  ),
                ),
              ),
              if (removed) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.check_circle,
                  size: 17,
                  color: AppColors.danger,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(bool isNarrow) {
    final validateButton = ElevatedButton.icon(
      onPressed: _isValid ? _validate : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.success,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.success.withValues(alpha: 0.5),
        disabledForegroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: const Icon(Icons.check, size: 20),
      label: const Text(
        'VALIDER & AJOUTER AU TICKET',
        style: TextStyle(
            fontWeight: FontWeight.w800, fontSize: 13.5, letterSpacing: 0.4),
      ),
    );

    final cancelButton = OutlinedButton(
      onPressed: () => Navigator.of(context).pop(),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: const Text(
        'Annuler',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _qtyButton(Icons.remove, () {
            if (_quantity > 1) setState(() => _quantity--);
          }),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '$_quantity',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          _qtyButton(Icons.add, () => setState(() => _quantity++)),
          const SizedBox(width: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'PRIX UNITAIRE CALCULÉ',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    _money(_lineTotal),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (_extrasTotal != 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      '(+${_money(_extrasTotal * _quantity)} suppléments)',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const Spacer(),
          cancelButton,
          const SizedBox(width: 14),
          validateButton,
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 18, color: AppColors.textPrimary),
      ),
    );
  }
}