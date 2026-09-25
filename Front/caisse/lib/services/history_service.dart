import '../models/order_models.dart';
import 'api_client.dart';

class HistoryService {
  HistoryService({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  /// GET /api/orders — one page of orders for a status and date range.
  /// [from] / [to] are LOCAL times; they are sent as UTC ISO timestamps so
  /// "today" means today on the cashier's PC, not on the server.
  Future<OrdersPage> fetchOrders({
    required String status,
    required DateTime from,
    required DateTime to,
    String? search,
    int page = 1,
    int limit = 9,
  }) async {
    final term = (search ?? '').replaceAll('#', '').trim();
    final json = await _client.get('/orders', query: {
      'status': status,
      'from': from.toUtc().toIso8601String(),
      'to': to.toUtc().toIso8601String(),
      'page': '$page',
      'limit': '$limit',
      if (term.isNotEmpty) 'search': term,
    });
    return OrdersPage.fromJson(json as Map<String, dynamic>);
  }

  /// GET /api/orders/summary — tab counters + "Total session".
  Future<OrdersSummary> fetchSummary({
    required DateTime from,
    required DateTime to,
  }) async {
    final json = await _client.get('/orders/summary', query: {
      'from': from.toUtc().toIso8601String(),
      'to': to.toUtc().toIso8601String(),
    });
    return OrdersSummary.fromJson(json as Map<String, dynamic>);
  }

  /// PATCH /api/orders/:id/status — update order status (e.g. 'terminee')
  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    await _client.patch('/orders/$orderId/status', {
      'status': status,
    });
  }
}