import '../models/pos_models.dart';
import 'api_client.dart';

class MenuService {
  MenuService({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  /// Fetches categories + all active products and groups them into the
  /// [MenuCategory] list the POS screen renders.
  Future<List<MenuCategory>> fetchMenu() async {
    final categories = await _fetchCategories();
    final products = await _fetchAllProducts();

    final byCategory = <String, List<MenuItem>>{};
    for (final product in products) {
      byCategory.putIfAbsent(product.categoryId, () => []).add(product);
    }

    return categories
        .where((c) => c.isActive && c.showOnPOS)
        .map((c) => MenuCategory(
              id: c.id,
              label: c.name,
              icon: categoryIcon(c.name),
              items: byCategory[c.id] ?? const [],
            ))
        .toList();
  }

  Future<List<Category>> _fetchCategories() async {
    final json = await _client.get('/categories');
    final list = (json is Map && json['data'] != null) ? json['data'] : json;
    final categories =
        (list as List).map((e) => Category.fromJson(e)).toList();
    categories.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return categories;
  }

  /// Products are paginated server-side (max 100/page) — walk every page
  /// so the caisse sees the full active catalog, not just the first 20.
  Future<List<MenuItem>> _fetchAllProducts() async {
    final all = <MenuItem>[];
    int page = 1;
    while (true) {
      final json = await _client.get('/products', query: {
        'page': '$page',
        'limit': '100',
      });
      final data =
          (json['data'] as List).map((e) => MenuItem.fromJson(e)).toList();
      all.addAll(data);
      final totalPages = (json['totalPages'] as num?)?.toInt() ?? 1;
      if (page >= totalPages) break;
      page++;
    }
    return all;
  }
}