import '../models/order_models.dart' show OccupiedTableInfo;
import '../models/pos_models.dart';
import '../widgets/pos/encaissement_modal.dart' show PaymentMethod;
import 'api_client.dart';

class CreatedOrder {
  const CreatedOrder({
    required this.id,
    required this.ticketNumber,
    required this.totalTTC,
  });
  final String id;
  final String ticketNumber;
  final double totalTTC;
}

class OrderService {
  OrderService({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  /// POST /api/orders
  /// The server picks the store automatically and computes totalTTC / TVA
  /// from the line totals we send.
  ///
  /// [tableNumber] (sur place), [clientName] (à emporter, optional) and
  /// [deliveryAddress] / [deliveryPhone] (livraison) are only sent when set,
  /// so an order carries just the fields its type actually needs.
  Future<CreatedOrder> createOrder({
    required List<TicketLine> lines,
    required OrderType orderType,
    required double expectedTotal,
    String? tableNumber,
    String? clientName,
    String? deliveryAddress,
    String? deliveryPhone,
    String? notes,
  }) async {
    // Validate table availability for dine-in orders before creating
    if (orderType == OrderType.dineIn && tableNumber != null && tableNumber.trim().isNotEmpty) {
      final clean = tableNumber.trim().toLowerCase().replaceFirst(RegExp(r'^table\s*'), '').trim();
      final occupiedList = await getOccupiedTables();
      final conflict = occupiedList.cast<OccupiedTableInfo?>().firstWhere(
        (t) {
          if (t == null) return false;
          final tClean = t.tableNumber.toLowerCase().replaceFirst(RegExp(r'^table\s*'), '').trim();
          return tClean == clean;
        },
        orElse: () => null,
      );
      if (conflict != null) {
        throw ApiException(
          'La table ${tableNumber.trim()} est déjà liée à la commande active #${conflict.ticketNumber}. '
          'Elle ne peut pas être réutilisée tant que cette commande n\'est pas marquée terminée.',
        );
      }
    }

    final body = <String, dynamic>{
      'orderType': _orderTypeToApi(orderType),
      'items': lines.map(_lineToJson).toList(),
      'status': 'en_attente',
    };

    if (notes != null && notes.trim().isNotEmpty) {
      body['notes'] = notes.trim();
    }
    if (tableNumber != null && tableNumber.trim().isNotEmpty) {
      body['tableNumber'] = tableNumber.trim();
      body['buzzerNumber'] = 'Table ${tableNumber.trim()}';
    }
    if (clientName != null && clientName.trim().isNotEmpty) {
      body['clientName'] = clientName.trim();
    }
    final hasAddress = deliveryAddress != null && deliveryAddress.trim().isNotEmpty;
    final hasPhone = deliveryPhone != null && deliveryPhone.trim().isNotEmpty;
    if (hasAddress || hasPhone) {
      body['delivery'] = {
        if (hasAddress) 'address': deliveryAddress.trim(),
        if (hasPhone) 'phone': deliveryPhone.trim(),
      };
    }

    final json = await _client.post('/orders', body);

    final data = json['data'] as Map<String, dynamic>;
    final created = CreatedOrder(
      id: data['_id'] as String,
      ticketNumber: data['ticketNumber'] as String? ?? '',
      totalTTC: (data['totalTTC'] as num).toDouble(),
    );

    // Safety net: never charge an amount the server computed differently.
    if ((created.totalTTC - expectedTotal).abs() > 0.01) {
      throw ApiException(
        'Écart de total (caisse ${expectedTotal.toStringAsFixed(2)} € / '
        'serveur ${created.totalTTC.toStringAsFixed(2)} €).',
      );
    }
    return created;
  }

  /// PUT /api/orders/:id
  /// Modifies an existing order (items, tableNumber, notes, orderType, clientName, delivery).
  Future<CreatedOrder> updateOrder({
    required String orderId,
    required List<TicketLine> lines,
    required OrderType orderType,
    required double expectedTotal,
    String? tableNumber,
    String? clientName,
    String? deliveryAddress,
    String? deliveryPhone,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'orderType': _orderTypeToApi(orderType),
      'items': lines.map(_lineToJson).toList(),
    };

    if (notes != null) {
      body['notes'] = notes.trim();
    }
    if (tableNumber != null && tableNumber.trim().isNotEmpty) {
      body['tableNumber'] = tableNumber.trim();
      body['buzzerNumber'] = 'Table ${tableNumber.trim()}';
    }
    if (clientName != null) {
      body['clientName'] = clientName.trim();
    }
    final hasAddress = deliveryAddress != null && deliveryAddress.trim().isNotEmpty;
    final hasPhone = deliveryPhone != null && deliveryPhone.trim().isNotEmpty;
    if (hasAddress || hasPhone) {
      body['delivery'] = {
        if (hasAddress) 'address': deliveryAddress.trim(),
        if (hasPhone) 'phone': deliveryPhone.trim(),
      };
    }

    final json = await _client.put('/orders/$orderId', body);
    final data = json['data'] as Map<String, dynamic>;
    return CreatedOrder(
      id: data['_id'] as String,
      ticketNumber: data['ticketNumber'] as String? ?? '',
      totalTTC: (data['totalTTC'] as num).toDouble(),
    );
  }

  /// GET /api/orders/occupied-tables
  /// Retrieves tables currently occupied by active (not yet terminee) orders.
  /// Includes fallback to GET /orders?limit=100 for backwards compatibility
  /// with backend versions before the dedicated endpoint.
  Future<List<OccupiedTableInfo>> getOccupiedTables() async {
    // 1. Try dedicated endpoint first
    try {
      final json = await _client.get('/orders/occupied-tables');
      final list = json['data'] as List<dynamic>? ?? [];
      if (list.isNotEmpty) {
        return list
            .map((e) => OccupiedTableInfo.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Endpoint not available on current backend deploy; fallback below
    }

    // 2. Resilient fallback: fetch recent orders and extract active tables
    try {
      final json = await _client.get('/orders?limit=100');
      final list = json['data'] as List<dynamic>? ?? [];
      final occupied = <OccupiedTableInfo>[];
      final seen = <String>{};

      for (final item in list) {
        if (item is! Map<String, dynamic>) continue;
        final status = item['status']?.toString().toLowerCase().trim() ?? '';
        final kdsStatus = item['kdsStatus']?.toString().toLowerCase().trim() ?? '';

        // If completed or cancelled, the table is free
        if (status == 'terminee' || status == 'annulee' || kdsStatus == 'served') {
          continue;
        }

        // Extract table identifier
        String? table = item['tableNumber']?.toString().trim();
        if (table == null || table.isEmpty) {
          final buzzer = item['buzzerNumber']?.toString().trim() ?? '';
          final match = RegExp(r'^Table\s*(.+)$', caseSensitive: false).firstMatch(buzzer);
          if (match != null) {
            table = match.group(1)?.trim();
          } else if (buzzer.isNotEmpty && !buzzer.toLowerCase().startsWith('buzzer')) {
            table = buzzer;
          }
        }

        if (table != null && table.isNotEmpty) {
          final clean = table.toLowerCase().replaceFirst(RegExp(r'^table\s*'), '').trim();
          if (clean.isNotEmpty && !seen.contains(clean)) {
            seen.add(clean);
            occupied.add(
              OccupiedTableInfo(
                tableNumber: clean,
                ticketNumber: item['ticketNumber']?.toString() ?? '',
                orderId: item['_id']?.toString(),
              ),
            );
          }
        }
      }
      return occupied;
    } catch (_) {
      return [];
    }
  }

  /// POST /api/payments (also flips the order to `terminee` server-side).
  Future<void> createPayment({
    required String orderId,
    required PaymentMethod method,
    required double amountReceived,
    required bool printReceipt,
  }) async {
    try {
      await _client.post('/payments', {
        'orderId': orderId,
        'method': _methodToApi(method),
        'amountReceived': amountReceived,
        'receiptPrinted': printReceipt,
      });
    } on ApiException catch (e) {
      // A retry after a timed-out response can hit "already paid" because the
      // first attempt actually succeeded. Confirm, and treat it as success.
      if (e.statusCode == 400 && e.message == 'Order already paid') {
        await _client.get('/payments/order/$orderId'); // throws if missing
        return;
      }
      rethrow;
    }
  }

  // ── mapping helpers ────────────────────────────────────────────────────
  String _orderTypeToApi(OrderType t) {
    switch (t) {
      case OrderType.dineIn:
        return 'sur_place';
      case OrderType.takeaway:
        return 'a_emporter';
      case OrderType.delivery:
        return 'livraison';
    }
  }

  String _methodToApi(PaymentMethod m) =>
      m == PaymentMethod.especes ? 'especes' : 'carte_bancaire';

  Map<String, dynamic> _lineToJson(TicketLine l) => {
        if (l.productId != null && l.productId!.trim().isNotEmpty)
          'productId': l.productId!.trim(),
        'productName': l.name,
        'unitPrice': l.unitPrice,
        'quantity': l.quantity,
        'customizations': l.customizations
            .map((c) => {
                  'groupName': c.groupName,
                  'selectedOptions': c.selectedOptions
                      .map((o) => {
                            'label': o.label,
                            'priceModifier': o.priceModifier,
                          })
                      .toList(),
                })
            .toList(),
        'removedIngredients': l.removedIngredients,
        // Required by the schema; the server does NOT compute it.
        'lineTotal': double.parse(l.total.toStringAsFixed(2)),
        if (l.notes != null && l.notes!.isNotEmpty) 'notes': l.notes,
      };
}