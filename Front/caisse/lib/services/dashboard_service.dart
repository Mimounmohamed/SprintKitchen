import 'api_client.dart';

class RuptureItem {
  final String id;
  final String name;
  final String? family;
  final String? availability;

  const RuptureItem({
    required this.id,
    required this.name,
    this.family,
    this.availability,
  });

  factory RuptureItem.fromJson(Map<String, dynamic> json) {
    return RuptureItem(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      family: json['family']?.toString(),
      availability: json['availability']?.toString(),
    );
  }
}

class DashboardKpis {
  final double revenueToday;
  final int? vsLastYear;
  final int ticketsToday;
  final int ruptureCount;
  final List<RuptureItem> ruptureItems;

  const DashboardKpis({
    required this.revenueToday,
    this.vsLastYear,
    required this.ticketsToday,
    required this.ruptureCount,
    this.ruptureItems = const [],
  });

  factory DashboardKpis.fromJson(Map<String, dynamic> json) {
    final revenue = json['revenue'] as Map<String, dynamic>? ?? {};
    final tickets = json['tickets'] as Map<String, dynamic>? ?? {};
    final rupture = json['rupture'] as Map<String, dynamic>? ?? {};

    final rawItems = rupture['items'] as List<dynamic>? ?? [];
    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map((e) => RuptureItem.fromJson(e))
        .toList();

    return DashboardKpis(
      revenueToday: (revenue['today'] as num?)?.toDouble() ?? 0.0,
      vsLastYear: (revenue['vsLastYear'] as num?)?.toInt(),
      ticketsToday: (tickets['today'] as num?)?.toInt() ?? 0,
      ruptureCount: (rupture['count'] as num?)?.toInt() ?? items.length,
      ruptureItems: items,
    );
  }
}

class DashboardService {
  DashboardService({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Future<DashboardKpis> fetchKpis() async {
    final json = await _client.get('/dashboard');
    final data = (json is Map && json['data'] != null) ? json['data'] : json;
    return DashboardKpis.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
