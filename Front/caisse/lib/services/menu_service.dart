import '../models/pos_models.dart';
import 'api_client.dart';

class _IngredientInfo {
  const _IngredientInfo({
    required this.meatIngredients,
    required this.outOfStockIngredients,
  });
  final Set<String> meatIngredients;
  final Set<String> outOfStockIngredients;
}

class MenuService {
  MenuService({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  /// Ingredient family (slug) whose ingredients count as "viande".
  static const String _meatFamily = 'viandes';

  /// Fetches categories + all active products and groups them into the
  /// [MenuCategory] list the POS screen renders.
  ///
  /// Customization groups and availability are dynamic:
  ///  - Any product with an épuisé/out-of-stock ingredient is automatically marked as ÉPUISÉ.
  ///  - "Cuisson" only for products containing red meat (viande, steak, bœuf) — never poultry.
  ///  - "Choix de la sauce" options = products of the "Sauces" category.
  ///  - "Suppléments & Extras" options = products of the "Extras" category.
  Future<List<MenuCategory>> fetchMenu() async {
    final results = await Future.wait<Object>([
      _fetchCategories(),
      _fetchAllProducts(),
      _fetchIngredientInfo(),
    ]);
    final categories = results[0] as List<Category>;
    final rawProducts = results[1] as List<MenuItem>;
    final ingredientInfo = results[2] as _IngredientInfo;

    // Sauces / Extras are looked up among ALL active categories, even if
    // they are hidden from the POS sidebar.
    final active = categories.where((c) => c.isActive).toList();
    final sauceCategoryIds =
        active.where((c) => _isSauceCategory(c.name)).map((c) => c.id).toSet();
    final extrasCategoryIds =
        active.where((c) => _isExtrasCategory(c.name)).map((c) => c.id).toSet();

    final sauceFromCategory = _optionsFrom(
      rawProducts.where((p) => sauceCategoryIds.contains(p.categoryId)),
      outOfStock: ingredientInfo.outOfStockIngredients,
    );
    final extrasFromCategory = _optionsFrom(
      rawProducts.where((p) => extrasCategoryIds.contains(p.categoryId)),
      outOfStock: ingredientInfo.outOfStockIngredients,
    );

    // Fallback if no specific products are in "Sauces" or "Extras" category:
    final sauceOptions = sauceFromCategory.isNotEmpty
        ? sauceFromCategory
        : _defaultSauceOptions
            .where((o) => !ingredientInfo.outOfStockIngredients.contains(_norm(o.label)))
            .toList();

    final extrasOptions = extrasFromCategory.isNotEmpty
        ? extrasFromCategory
        : _defaultExtraOptions
            .where((o) => !ingredientInfo.outOfStockIngredients.contains(_norm(o.label)))
            .toList();

    final products = rawProducts
        .map((p) => _withDynamicGroups(
              p,
              meatIngredients: ingredientInfo.meatIngredients,
              outOfStockIngredients: ingredientInfo.outOfStockIngredients,
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

  /// Fetches ingredients to track:
  /// 1. Red meat ingredients (for cooking level)
  /// 2. Out-of-stock / épuisé ingredients (to automatically disable products)
  Future<_IngredientInfo> _fetchIngredientInfo() async {
    try {
      final json = await _client.get('/ingredients', query: {'limit': '500'});
      final list = (json is Map && json['data'] is List)
          ? json['data'] as List
          : (json is List ? json : const []);

      final meat = <String>{};
      final outOfStock = <String>{};

      for (final raw in list) {
        if (raw is! Map) continue;
        final name = _norm(raw['name']?.toString() ?? '');
        if (name.isEmpty) continue;

        final family = _norm(raw['family']?.toString() ?? '');
        final avail = raw['availability']?.toString() ?? 'available';
        final isOnList86 = raw['isOnList86'] == true;

        // 1. Red meat tracking (excluding poultry)
        if (family == _meatFamily &&
            !name.contains('poulet') &&
            !name.contains('chicken') &&
            !name.contains('dinde')) {
          meat.add(name);
        }

        // 2. Out-of-stock tracking (epuise or bloque or on 86 list)
        if (avail != 'available' || isOnList86) {
          outOfStock.add(name);
        }
      }

      return _IngredientInfo(
        meatIngredients: meat,
        outOfStockIngredients: outOfStock,
      );
    } catch (_) {
      return const _IngredientInfo(
        meatIngredients: {},
        outOfStockIngredients: {},
      );
    }
  }

  // ───────────────────────── dynamic groups ─────────────────────────

  MenuItem _withDynamicGroups(
    MenuItem p, {
    required Set<String> meatIngredients,
    required Set<String> outOfStockIngredients,
    required List<CustomizationOption> sauceOptions,
    required List<CustomizationOption> extrasOptions,
  }) {
    // A product is out of stock if it was manually set to epuise
    // OR if ANY of its ingredients is currently out of stock.
    final bool hasEpuisedIngredient = p.ingredients.any((i) {
      final n = _norm(i);
      return outOfStockIngredients.contains(n);
    });

    final bool isAvailable = p.available && !hasEpuisedIngredient;

    // Cooking level only applies to red meat (viande, steak, bœuf).
    final hasMeat = p.ingredients.any((i) {
      final n = _norm(i);
      if (n.contains('poulet') || n.contains('chicken') || n.contains('dinde')) {
        return false;
      }
      return n.contains('viande') ||
          n.contains('boeuf') ||
          n.contains('steak') ||
          meatIngredients.contains(n);
    });

    final groups = <CustomizationGroup>[];
    var hasCuisson = false;
    var hasSauce = false;
    var hasSupplements = false;

    for (final g in p.customizationGroups) {
      final name = _norm(g.name);
      if (name.contains('cuisson')) {
        // Cooking level only for red meat.
        if (hasMeat) {
          groups.add(g);
          hasCuisson = true;
        }
      } else if (name.contains('sauce')) {
        // Product keeps its sauce step, but the choices come from "Sauces".
        if (sauceOptions.isNotEmpty) {
          groups.add(_withOptions(g, sauceOptions));
          hasSauce = true;
        }
      } else if (name.contains('suppl') || name.contains('extra')) {
        // Choices come from the "Extras" category.
        if (extrasOptions.isNotEmpty) {
          groups.add(_withOptions(g, extrasOptions));
          hasSupplements = true;
        }
      } else {
        groups.add(g);
      }
    }

    // Meat product without a cuisson step configured: add the standard one.
    if (hasMeat && !hasCuisson) groups.insert(0, _defaultCuisson);

    // If product has ingredients or is in food categories (burgers, sandwichs, menus),
    // ensure standard Sauces and Suppléments & Extras are available!
    final bool isFoodItem = p.ingredients.isNotEmpty ||
        p.customizationGroups.isNotEmpty;

    if (isFoodItem) {
      if (!hasSauce && sauceOptions.isNotEmpty) {
        groups.add(_defaultSauces(sauceOptions));
      }
      if (!hasSupplements && extrasOptions.isNotEmpty) {
        groups.add(_defaultExtras(extrasOptions));
      }
    }

    return MenuItem(
      id: p.id,
      name: p.name,
      price: p.price,
      categoryId: p.categoryId,
      available: isAvailable,
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

  static CustomizationGroup _defaultSauces(List<CustomizationOption> options) {
    return CustomizationGroup(
      name: 'Choix de la sauce',
      type: 'multi',
      isRequired: false,
      minChoices: 0,
      maxChoices: 3,
      stepNumber: 1,
      options: options,
    );
  }

  static const List<CustomizationOption> _defaultSauceOptions = [
    CustomizationOption(label: 'Algérienne', isDefault: true),
    CustomizationOption(label: 'Mayonnaise'),
    CustomizationOption(label: 'Ketchup'),
    CustomizationOption(label: 'Barbecue'),
    CustomizationOption(label: 'Samouraï'),
    CustomizationOption(label: 'Biggy'),
    CustomizationOption(label: 'Blanche'),
    CustomizationOption(label: 'Andalouse'),
  ];

  static const List<CustomizationOption> _defaultExtraOptions = [
    CustomizationOption(label: 'Cheddar', priceModifier: 50),
    CustomizationOption(label: 'Gouda', priceModifier: 50),
    CustomizationOption(label: 'Bacon', priceModifier: 80),
    CustomizationOption(label: 'Oignons Frits', priceModifier: 40),
    CustomizationOption(label: 'Double Steak', priceModifier: 150),
    CustomizationOption(label: 'Œuf', priceModifier: 50),
    CustomizationOption(label: 'Galette de pomme de terre', priceModifier: 70),
  ];

  static CustomizationGroup _defaultExtras(List<CustomizationOption> options) {
    return CustomizationGroup(
      name: 'Suppléments & Extras',
      type: 'multi',
      isRequired: false,
      minChoices: 0,
      maxChoices: 10,
      stepNumber: 2,
      options: options,
    );
  }

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
  List<CustomizationOption> _optionsFrom(
    Iterable<MenuItem> products, {
    required Set<String> outOfStock,
  }) {
    final seen = <String>{};
    final options = <CustomizationOption>[];
    for (final p in products) {
      if (!p.available) continue;
      final label = p.name.trim();
      if (label.isEmpty || !seen.add(label.toLowerCase())) continue;
      if (outOfStock.contains(_norm(label))) continue;
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