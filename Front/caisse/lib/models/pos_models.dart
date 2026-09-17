import 'package:flutter/material.dart';

/// A single sellable item shown as a tile in the POS grid.
class MenuItem {
  const MenuItem({
    required this.name,
    required this.price,
    this.available = true,
  });

  final String name;
  final double price;
  final bool available;
}

/// A category in the left sidebar (e.g. "Menus B", "Nos Burgers").
class MenuCategory {
  const MenuCategory({
    required this.label,
    required this.icon,
    required this.items,
  });

  final String label;
  final IconData icon;
  final List<MenuItem> items;
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