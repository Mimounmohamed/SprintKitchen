import '../models/inventory_models.dart';
import 'api_client.dart';

class InventoryService {
  InventoryService({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  // ── Families ────────────────────────────────────────────────────────────

  /// GET /api/ingredient-families
  Future<List<IngredientFamily>> fetchFamilies() async {
    final json = await _client.get('/ingredient-families');
    final list = (json['data'] as List<dynamic>)
        .map((e) => IngredientFamily.fromJson(e as Map<String, dynamic>))
        .toList();
    list.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return list;
  }

  /// POST /api/ingredient-families
  /// The server computes the slug from the name itself; no need to send one.
  Future<IngredientFamily> createFamily({
    required String name,
    required String emoji,
  }) async {
    final json = await _client.post('/ingredient-families', {
      'name': name,
      'emoji': emoji,
    });
    return IngredientFamily.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// PUT /api/ingredient-families/:id
  Future<IngredientFamily> updateFamily(
    String id, {
    required String name,
    required String emoji,
  }) async {
    final json = await _client.put('/ingredient-families/$id', {
      'name': name,
      'emoji': emoji,
    });
    return IngredientFamily.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// DELETE /api/ingredient-families/:id (soft delete; the server refuses if
  /// active ingredients still use it and throws an ApiException with that
  /// message).
  Future<void> deleteFamily(String id) => _client.delete('/ingredient-families/$id');

  // ── Ingredients ─────────────────────────────────────────────────────────

  /// GET /api/ingredients/families — per-family total/épuisé counts, used
  /// for the sidebar badges.
  Future<List<FamilyStat>> fetchFamilyStats() async {
    final json = await _client.get('/ingredients/families');
    return (json['data'] as List<dynamic>)
        .map((e) => FamilyStat.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/ingredients?family=slug
  Future<List<Ingredient>> fetchIngredients({required String family}) async {
    final json = await _client.get('/ingredients', query: {'family': family});
    return (json['data'] as List<dynamic>)
        .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// PATCH /api/ingredients/:id/availability
  Future<Ingredient> setAvailability(
    String id,
    String availability, {
    String? notes,
  }) async {
    final json = await _client.patch('/ingredients/$id/availability', {
      'availability': availability,
      if (notes != null) 'notes': notes,
    });
    return Ingredient.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// POST /api/ingredients
  Future<Ingredient> createIngredient({
    required String name,
    required String family,
    required String unit,
    String? notes,
  }) async {
    final json = await _client.post('/ingredients', {
      'name': name,
      'family': family,
      'unit': unit,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return Ingredient.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// PUT /api/ingredients/:id
  Future<Ingredient> updateIngredient(
    String id, {
    required String name,
    required String family,
    required String unit,
    String? notes,
  }) async {
    final json = await _client.put('/ingredients/$id', {
      'name': name,
      'family': family,
      'unit': unit,
      'notes': notes ?? '',
    });
    return Ingredient.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// DELETE /api/ingredients/:id (soft delete)
  Future<void> deleteIngredient(String id) => _client.delete('/ingredients/$id');
}