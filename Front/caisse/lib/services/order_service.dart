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
  Future<CreatedOrder> createOrder({
    required List<TicketLine> lines,
    required OrderType orderType,
    required double expectedTotal,
  }) async {
    final json = await _client.post('/orders', {
      'orderType': _orderTypeToApi(orderType),
      'items': lines.map(_lineToJson).toList(),
      'status': 'en_attente',
    });

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