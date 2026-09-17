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
  });

  final String id;
  final String name;
  final double price;
  final String categoryId;
  final bool available;
  final String? description;

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

/// A line item currently in the active ticket.
class TicketLine {
  TicketLine({
    required this.name,
    required this.unitPrice,
    this.subtitle,
    this.quantity = 1,
  });

  final String name;
  final String? subtitle;
  final double unitPrice;
  int quantity;

  double get total => unitPrice * quantity;
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