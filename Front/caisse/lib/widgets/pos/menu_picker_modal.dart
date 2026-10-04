import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/pos_models.dart';
import '../../theme/app_colors.dart';
import 'category_sidebar_item.dart';
import 'customization_modal.dart';
import 'menu_item_tile.dart';

/// Modal dialog that presents the product catalog (categories sidebar +
/// product grid + search bar), allowing the cashier to select an item to
/// add to the order being modified.
///
/// Follows the exact POS menu catalog design pattern. If the chosen item is
/// customizable, it automatically opens [CustomizationModal] on top and
/// returns the fully-built [TicketLine].
class MenuPickerModal extends StatefulWidget {
  const MenuPickerModal({
    super.key,
    required this.categories,
  });

  final List<MenuCategory> categories;

  @override
  State<MenuPickerModal> createState() => _MenuPickerModalState();
}

class _MenuPickerModalState extends State<MenuPickerModal> {
  int _selectedCategoryIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _gridScrollController = ScrollController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final q = _searchController.text.trim().toLowerCase();
      if (q != _searchQuery) {
        setState(() => _searchQuery = q);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _gridScrollController.dispose();
    super.dispose();
  }

  List<MenuItem> get _displayedItems {
    if (_searchQuery.isNotEmpty) {
      final results = <MenuItem>[];
      for (final cat in widget.categories) {
        for (final item in cat.items) {
          if (item.name.toLowerCase().contains(_searchQuery)) {
            if (!results.any((r) => r.id == item.id && r.name == item.name)) {
              results.add(item);
            }
          }
        }
      }
      return results;
    }

    if (widget.categories.isEmpty) return const [];
    final idx = math.min(_selectedCategoryIndex, widget.categories.length - 1);
    return widget.categories[idx].items;
  }

  Future<void> _handleItemTap(MenuItem item) async {
    if (item.needsCustomization) {
      final customizedLine = await showDialog<TicketLine>(
        context: context,
        barrierColor: Colors.transparent,
        builder: (_) => CustomizationModal(item: item),
      );
      if (customizedLine != null && mounted) {
        Navigator.of(context).pop(customizedLine);
      }
    } else {
      final line = TicketLine(
        name: item.name,
        unitPrice: item.price,
        quantity: 1,
        productId: item.id,
      );
      Navigator.of(context).pop(line);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dialogWidth = math.min(1000.0, size.width * 0.92);
    final dialogHeight = math.min(700.0, size.height * 0.88);

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Row(
                children: [
                  _buildSidebar(),
                  Expanded(
                    child: Column(
                      children: [
                        _buildSearchBar(),
                        Expanded(child: _buildGrid()),
                      ],
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF583926),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(Icons.restaurant_rounded,
                  color: Color(0xFFFACC15), size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'AJOUTER UN ARTICLE AU TICKET',
            style: GoogleFonts.bebasNeue(
              fontSize: 22,
              letterSpacing: 0.8,
              color: AppColors.brandDark,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
            tooltip: 'Fermer',
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 210,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: widget.categories.isEmpty
          ? const Center(
              child: Text(
                'Aucune catégorie',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: widget.categories.length,
              itemBuilder: (context, index) {
                final cat = widget.categories[index];
                final isSelected =
                    _searchQuery.isEmpty && index == _selectedCategoryIndex;
                return CategorySidebarItem(
                  icon: cat.icon,
                  label: cat.label,
                  selected: isSelected,
                  onTap: () {
                    setState(() {
                      _selectedCategoryIndex = index;
                      _searchController.clear();
                      _searchQuery = '';
                    });
                    if (_gridScrollController.hasClients) {
                      _gridScrollController.jumpTo(0);
                    }
                  },
                );
              },
            ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Rechercher un produit (burger, boisson, dessert)...',
                  hintStyle: const TextStyle(
                      fontSize: 13, color: Color(0xFF9CA3AF)),
                  prefixIcon:
                      const Icon(Icons.search, size: 18, color: Color(0xFF9CA3AF)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.brandDark, width: 1.5),
                  ),
                ),
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(width: 12),
            Text(
              '${_displayedItems.length} résultat(s)',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGrid() {
    final items = _displayedItems;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 48, color: Color(0xFFD1D5DB)),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Aucun produit trouvé pour "$_searchQuery".'
                  : 'Aucun produit dans cette catégorie.',
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return RawScrollbar(
          controller: _gridScrollController,
          thumbColor: const Color(0xFFFACC15),
          radius: const Radius.circular(4),
          thickness: 6,
          thumbVisibility: true,
          child: GridView.builder(
            controller: _gridScrollController,
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              mainAxisExtent: 140,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return MenuItemTile(
                item: item,
                onTap: () => _handleItemTap(item),
              );
            },
          ),
        );
      },
    );
  }
}
