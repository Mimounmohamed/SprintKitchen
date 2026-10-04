import '../models/pos_models.dart';
import 'api_client.dart';

class MenuService {
  MenuService({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  /// Ingredient family (slug) whose ingredients count as "viande".
  static const String _meatFamily = 'viandes';

  /// Fetches categories + all active products and groups them into the
  /// [MenuCategory] list the POS screen renders.
  ///
  /// Customization groups are made dynamic here, once, so every place that
  /// opens the personnalisation modal (add + edit) gets the same rules:
  ///  - "Cuisson" only for products containing a `viandes` ingredient.
  ///  - "Choix de la sauce" options = products of the "Sauces" category.
  ///  - "Suppléments & Extras" options = products of the "Extras" category.
  Future<List<MenuCategory>> fetchMenu() async {
    final results = await Future.wait<Object>([
      _fetchCategories(),
      _fetchAllProducts(),
      _fetchMeatIngredients(),
    ]);
    final categories = results[0] as List<Category>;
    final rawProducts = results[1] as List<MenuItem>;
    final meatIngredients = results[2] as Set<String>;

    // Sauces / Extras are looked up among ALL active categories, even if
    // they are hidden from the POS sidebar.
    final active = categories.where((c) => c.isActive).toList();
    final sauceCategoryIds =
        active.where((c) => _isSauceCategory(c.name)).map((c) => c.id).toSet();
    final extrasCategoryIds =
        active.where((c) => _isExtrasCategory(c.name)).map((c) => c.id).toSet();

    final sauceOptions = _optionsFrom(
        rawProducts.where((p) => sauceCategoryIds.contains(p.categoryId)));
    final extrasOptions = _optionsFrom(
        rawProducts.where((p) => extrasCategoryIds.contains(p.categoryId)));

    final products = rawProducts
        .map((p) => _withDynamicGroups(
              p,
              meatIngredients: meatIngredients,
              sauceOptions: sauceOptions,
              extrasOptions: extrasOptions,
            ))
        .toList();

    final byCategory = <String, List<MenuItem>>{};
    for (final product in products) {
      byCategory.putIfAbsent(product.categoryId, () => []).add(product);
    }

    return categories
        .where((c) =>
            c.isActive &&
            c.showOnPOS &&
            !_isSauceCategory(c.name) &&
            !_isExtrasCategory(c.name))
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

  /// Normalized names of every ingredient in the `viandes` family.
  /// Never throws: if the call fails, only the literal "viande" check is used.
  Future<Set<String>> _fetchMeatIngredients() async {
    try {
      final json = await _client.get('/ingredients', query: {'limit': '500'});
      final list = (json is Map && json['data'] is List)
          ? json['data'] as List
          : (json is List ? json : const []);
      return list
          .whereType<Map>()
          .where((i) => _norm(i['family']?.toString() ?? '') == _meatFamily)
          .map((i) => _norm(i['name']?.toString() ?? ''))
          .where((n) => n.isNotEmpty)
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  // ───────────────────────── dynamic groups ─────────────────────────

  MenuItem _withDynamicGroups(
    MenuItem p, {
    required Set<String> meatIngredients,
    required List<CustomizationOption> sauceOptions,
    required List<CustomizationOption> extrasOptions,
  }) {
    final hasMeat = p.ingredients.any((i) {
      final n = _norm(i);
      return meatIngredients.contains(n) || n.contains('viande');
    });

    final groups = <CustomizationGroup>[];
    var hasCuisson = false;

    for (final g in p.customizationGroups) {
      final name = _norm(g.name);
      if (name.contains('cuisson')) {
        // Cooking level only makes sense for meat.
        if (hasMeat) {
          groups.add(g);
          hasCuisson = true;
        }
      } else if (name.contains('sauce')) {
        // Product keeps its sauce step, but the choices come from "Sauces".
        if (sauceOptions.isNotEmpty) groups.add(_withOptions(g, sauceOptions));
      } else if (name.contains('suppl') || name.contains('extra')) {
        // Choices come from the "Extras" category.
        if (extrasOptions.isNotEmpty) groups.add(_withOptions(g, extrasOptions));
      } else {
        groups.add(g);
      }
    }

    // Meat product without a cuisson step configured: add the standard one.
    if (hasMeat && !hasCuisson) groups.insert(0, _defaultCuisson);

    return MenuItem(
      id: p.id,
      name: p.name,
      price: p.price,
      categoryId: p.categoryId,
      available: p.available,
      description: p.description,
      customizationGroups: groups,
      ingredients: p.ingredients,
    );
  }

  static const CustomizationGroup _defaultCuisson = CustomizationGroup(
    name: 'Cuisson de la viande',
    type: 'single',
    isRequired: true,
    minChoices: 1,
    maxChoices: 1,
    stepNumber: 0,
    options: [
      CustomizationOption(label: 'Saignant'),
      CustomizationOption(label: '\u00c0 point', isDefault: true),
      CustomizationOption(label: 'Bien cuit'),
    ],
  );

  CustomizationGroup _withOptions(
      CustomizationGroup g, List<CustomizationOption> options) {
    return CustomizationGroup(
      name: g.name,
      type: g.type,
      isRequired: g.isRequired,
      minChoices: g.minChoices,
      maxChoices: g.maxChoices,
      stepNumber: g.stepNumber,
      options: options,
    );
  }

  /// One option per available product (label = name, price = basePrice).
  List<CustomizationOption> _optionsFrom(Iterable<MenuItem> products) {
    final seen = <String>{};
    final options = <CustomizationOption>[];
    for (final p in products) {
      if (!p.available) continue;
      final label = p.name.trim();
      if (label.isEmpty || !seen.add(label.toLowerCase())) continue;
      options.add(CustomizationOption(label: label, priceModifier: p.price));
    }
    return options;
  }

  bool _isSauceCategory(String name) {
    final n = _norm(name);
    return n.contains('sauce') && !n.contains('extra');
  }

  bool _isExtrasCategory(String name) {
    final n = _norm(name);
    return (n.contains('extra') || n.contains('suppl')) && !n.contains('sauce');
  }

  /// Lowercase, trimmed, accents removed — for tolerant name matching.
  static String _norm(String s) {
    const from = '\u00e0\u00e2\u00e4\u00e9\u00e8\u00ea\u00eb\u00ee\u00ef\u00f4\u00f6\u00f9\u00fb\u00fc\u00e7';
    const to = 'aaaeeeeiioouuuc';
    final lower = s.toLowerCase().trim();
    final buf = StringBuffer();
    for (final ch in lower.split('')) {
      final i = from.indexOf(ch);
      buf.write(i >= 0 ? to[i] : ch);
    }
    return buf.toString();
  }
}