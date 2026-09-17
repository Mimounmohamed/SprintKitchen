import 'package:flutter/material.dart';

/// Mirrors Back/models/Category.js
class Category {
  const Category({
    required this.id,
    required this.name,
    this.slug = '',
    this.displayOrder = 0,
    this.isActive = true,
    this.showOnPOS = true,
  });

  final String id;
  final String name;
  final String slug;
  final int displayOrder;
  final bool isActive;
  final bool showOnPOS;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['_id'] as String,
        name: json['name'] as String? ?? '',
        slug: json['slug'] as String? ?? '',
        displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
        isActive: json['isActive'] as bool? ?? true,
        showOnPOS: json['showOnPOS'] as bool? ?? true,
      );
}

/// Mirrors the embedded OptionSchema inside Product.customizationGroups.
class CustomizationOption {
  const CustomizationOption({
    required this.label,
    this.priceModifier = 0,
    this.isDefault = false,
    this.isAvailable = true,
    this.displayOrder = 0,
  });

  final String label;
  final double priceModifier;
  final bool isDefault;
  final bool isAvailable;
  final int displayOrder;

  factory CustomizationOption.fromJson(Map<String, dynamic> json) {
    return CustomizationOption(
      label: json['label'] as String? ?? '',
      priceModifier: (json['priceModifier'] as num?)?.toDouble() ?? 0,
      isDefault: json['isDefault'] as bool? ?? false,
      isAvailable: json['isAvailable'] as bool? ?? true,
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Mirrors Product.customizationGroups (CustomizationGroupSchema).
class CustomizationGroup {
  const CustomizationGroup({
    required this.name,
    required this.type,
    this.isRequired = false,
    this.minChoices = 0,
    this.maxChoices = 1,
    this.stepNumber,
    this.options = const [],
  });

  final String name;
  final String type; // 'single' | 'multi'
  final bool isRequired;
  final int minChoices;
  final int maxChoices;
  final int? stepNumber;
  final List<CustomizationOption> options;

  bool get isSingle => type == 'single';

  factory CustomizationGroup.fromJson(Map<String, dynamic> json) {
    final options = (json['options'] as List<dynamic>? ?? [])
        .map((e) => CustomizationOption.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    return CustomizationGroup(
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'single',
      isRequired: json['isRequired'] as bool? ?? false,
      minChoices: (json['minChoices'] as num?)?.toInt() ?? 0,
      maxChoices: (json['maxChoices'] as num?)?.toInt() ?? 1,
      stepNumber: (json['stepNumber'] as num?)?.toInt(),
      options: options,
    );
  }
}

/// A single sellable item shown as a tile in the POS grid.
/// Mirrors Back/models/Product.js
class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.categoryId,
    this.available = true,
    this.description,
    this.customizationGroups = const [],
    this.ingredients = const [],
  });

  final String id;
  final String name;
  final double price;
  final String categoryId;
  final bool available;
  final String? description;
  final List<CustomizationGroup> customizationGroups;
  final List<String> ingredients;

  /// Whether tapping this tile should open the personnalisation modal
  /// instead of adding straight to the ticket.
  bool get needsCustomization =>
      customizationGroups.isNotEmpty || ingredients.isNotEmpty;

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    // categoryId comes back populated ({_id, name, slug, color}) from
    // getProducts, but keep this defensive in case a raw id string shows up.
    final rawCategory = json['categoryId'];
    final categoryId = rawCategory is Map
        ? rawCategory['_id'] as String
        : (rawCategory as String? ?? '');

    return MenuItem(
      id: json['_id'] as String,
      name: json['name'] as String? ?? '',
      price: (json['basePrice'] as num?)?.toDouble() ?? 0,
      categoryId: categoryId,
      available:
          (json['availability'] as String? ?? 'available') == 'available',
      description: json['description'] as String?,
      customizationGroups: (json['customizationGroups'] as List<dynamic>? ?? [])
          .map((e) => CustomizationGroup.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => (a.stepNumber ?? 0).compareTo(b.stepNumber ?? 0)),
      ingredients: (json['ingredients'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

/// A category in the left sidebar (e.g. "Menus B", "Nos Burgers").
class MenuCategory {
  const MenuCategory({
    this.id,
    required this.label,
    required this.icon,
    required this.items,
  });

  final String? id;
  final String label;
  final IconData icon;
  final List<MenuItem> items;
}

/// The backend stores `Category.icon` as free text, so the actual Flutter
/// icon choice lives here, keyed by the category's exact `name`. Add an
/// entry whenever a new category is created in the admin; unmapped
/// categories fall back to a generic icon instead of breaking.
IconData categoryIcon(String name) {
  const icons = <String, IconData>{
    'Menus B': Icons.grid_view_rounded,
    'Menus L': Icons.grid_view_rounded,
    'Menu Simple': Icons.lunch_dining_rounded,
    'Nos Starters': Icons.star_border_rounded,
    'Nos Burgers': Icons.lunch_dining_rounded,
    'Nos Sandwichs': Icons.tapas_rounded,
    'Menu Enfant': Icons.child_care_rounded,
    'Nos Desserts': Icons.icecream_rounded,
    'Boissons & Cafés': Icons.local_cafe_rounded,
  };
  return icons[name] ?? Icons.restaurant_menu_rounded;
}

/// A selected option, kept simple (label + its price) so it can be sent
/// straight to Back/models/Order.js's AppliedCustomizationSchema.
class SelectedOption {
  const SelectedOption({required this.label, this.priceModifier = 0});
  final String label;
  final double priceModifier;
}

/// A finalized customization group choice on a ticket line.
/// Mirrors Order.items[].customizations (AppliedCustomizationSchema).
class AppliedCustomization {
  const AppliedCustomization({
    required this.groupName,
    required this.selectedOptions,
  });
  final String groupName;
  final List<SelectedOption> selectedOptions;
}

/// A line item currently in the active ticket.
class TicketLine {
  TicketLine({
    required this.name,
    required this.unitPrice,
    this.subtitle,
    this.quantity = 1,
    this.productId,
    this.extrasTotal = 0,
    this.customizations = const [],
    this.removedIngredients = const [],
    this.notes,
  });

  final String name;
  final String? subtitle;
  final double unitPrice;
  int quantity;
  final String? productId;
  final double extrasTotal;
  final List<AppliedCustomization> customizations;
  final List<String> removedIngredients;
  final String? notes;

  /// (base price + selected extras) * quantity — matches how
  /// Order.items[].lineTotal is computed server-side.
  double get total => (unitPrice + extrasTotal) * quantity;
}

/// Fulfilment type for the current order.
enum OrderType { dineIn, takeaway, delivery }

extension OrderTypeLabel on OrderType {
  String get label {
    switch (this) {
      case OrderType.dineIn:
        return 'Sur Place';
      case OrderType.takeaway:
        return 'Emporter';
      case OrderType.delivery:
        return 'Livraison';
    }
  }
}