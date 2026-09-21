/// One line of a past order (Order.items[]).
class HistoryOrderLine {
  const HistoryOrderLine({
    required this.name,
    required this.quantity,
    required this.lineTotal,
    this.options = const [],
    this.removed = const [],
    this.notes,
  });

  final String name;
  final int quantity;
  final double lineTotal;

  /// Flattened labels of every selected customization option.
  final List<String> options;

  /// Already prefixed by the POS, e.g. "Sans Tomate".
  final List<String> removed;
  final String? notes;

  factory HistoryOrderLine.fromJson(Map<String, dynamic> json) {
    final options = <String>[];
    for (final c in (json['customizations'] as List<dynamic>? ?? [])) {
      final selected = (c as Map<String, dynamic>)['selectedOptions'];
      for (final o in (selected as List<dynamic>? ?? [])) {
        final label = (o as Map<String, dynamic>)['label'] as String?;
        if (label != null && label.isNotEmpty) options.add(label);
      }
    }
    return HistoryOrderLine(
      name: json['productName'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      lineTotal: (json['lineTotal'] as num?)?.toDouble() ?? 0,
      options: options,
      removed: (json['removedIngredients'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      notes: json['notes'] as String?,
    );
  }
}

/// A past order as shown in the history table. Mirrors Back/models/Order.js.
class HistoryOrder {
  const HistoryOrder({
    required this.id,
    required this.ticketNumber,
    required this.createdAt,
    required this.status,
    required this.orderType,
    required this.totalTTC,
    required this.subtotalHT,
    required this.tvaAmount,
    this.registerName,
    this.clientName,
    this.buzzerNumber,
    this.deliveryName,
    this.lines = const [],
  });

  final String id;
  final String ticketNumber;
  final DateTime createdAt;
  final String status;

  /// 'sur_place' | 'a_emporter' | 'livraison'
  final String orderType;
  final double totalTTC;
  final double subtotalHT;
  final double tvaAmount;
  final String? registerName;
  final String? clientName;
  final String? buzzerNumber;
  final String? deliveryName;
  final List<HistoryOrderLine> lines;

  /// First non-empty of client name / buzzer / delivery name, else null
  /// (the table then shows "Client Passant").
  String? get displayClient {
    for (final v in [clientName, buzzerNumber, deliveryName]) {
      if (v != null && v.trim().isNotEmpty) return v;
    }
    return null;
  }

  factory HistoryOrder.fromJson(Map<String, dynamic> json) {
    final register = json['registerId'];
    final delivery = json['delivery'];
    return HistoryOrder(
      id: json['_id'] as String,
      ticketNumber: json['ticketNumber'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      status: json['status'] as String? ?? '',
      orderType: json['orderType'] as String? ?? 'sur_place',
      totalTTC: (json['totalTTC'] as num?)?.toDouble() ?? 0,
      subtotalHT: (json['subtotalHT'] as num?)?.toDouble() ?? 0,
      tvaAmount: (json['tvaAmount'] as num?)?.toDouble() ?? 0,
      // registerId is populated ({_id, name, type}) by GET /api/orders.
      registerName: register is Map ? register['name'] as String? : null,
      clientName: json['clientName'] as String?,
      buzzerNumber: json['buzzerNumber'] as String?,
      deliveryName: delivery is Map ? delivery['fullName'] as String? : null,
      lines: (json['items'] as List<dynamic>? ?? [])
          .map((e) => HistoryOrderLine.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// One page of GET /api/orders.
class OrdersPage {
  const OrdersPage({
    required this.orders,
    required this.total,
    required this.totalPages,
    required this.page,
  });

  final List<HistoryOrder> orders;
  final int total;
  final int totalPages;
  final int page;

  factory OrdersPage.fromJson(Map<String, dynamic> json) => OrdersPage(
        orders: (json['data'] as List<dynamic>? ?? [])
            .map((e) => HistoryOrder.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: (json['total'] as num?)?.toInt() ?? 0,
        totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
        page: (json['page'] as num?)?.toInt() ?? 1,
      );
}

/// GET /api/orders/summary — counts per status + revenue of paid orders.
class OrdersSummary {
  const OrdersSummary({required this.counts, required this.totalTerminee});

  final Map<String, int> counts;
  final double totalTerminee;

  int countFor(String status) => counts[status] ?? 0;

  factory OrdersSummary.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final raw = data['counts'] as Map<String, dynamic>? ?? {};
    return OrdersSummary(
      counts: raw.map((k, v) => MapEntry(k, (v as num).toInt())),
      totalTerminee: (data['totalTerminee'] as num?)?.toDouble() ?? 0,
    );
  }
}