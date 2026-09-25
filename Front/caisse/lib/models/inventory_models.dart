/// A stock/menu family (mirrors Back/models/IngredientFamily.js).
class IngredientFamily {
  const IngredientFamily({
    required this.id,
    required this.name,
    required this.slug,
    this.emoji = '📦',
    this.displayOrder = 0,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String slug;
  final String emoji;
  final int displayOrder;
  final bool isActive;

  factory IngredientFamily.fromJson(Map<String, dynamic> json) =>
      IngredientFamily(
        id: json['_id'] as String,
        name: json['name'] as String? ?? '',
        slug: json['slug'] as String? ?? '',
        emoji: json['emoji'] as String? ?? '📦',
        displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
        isActive: json['isActive'] as bool? ?? true,
      );
}

/// Per-family counts from GET /api/ingredients/families
/// (an aggregate, so it only has a slug + two numbers).
class FamilyStat {
  const FamilyStat({required this.slug, required this.total, required this.epuise});

  final String slug;
  final int total;
  final int epuise;

  factory FamilyStat.fromJson(Map<String, dynamic> json) => FamilyStat(
        slug: json['_id'] as String? ?? '',
        total: (json['total'] as num?)?.toInt() ?? 0,
        epuise: (json['epuise'] as num?)?.toInt() ?? 0,
      );
}

/// availability: 'available' | 'epuise' | 'bloque'
class Ingredient {
  const Ingredient({
    required this.id,
    required this.name,
    required this.family,
    this.unit = 'unité',
    this.availability = 'available',
    this.isOnList86 = false,
    this.notes,
    this.displayOrder = 0,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String family; // family slug
  final String unit;
  final String availability;
  final bool isOnList86;
  final String? notes;
  final int displayOrder;
  final bool isActive;

  bool get isEpuise => availability != 'available';
  bool get isBloque => availability == 'bloque';

  Ingredient copyWith({String? availability, String? notes}) => Ingredient(
        id: id,
        name: name,
        family: family,
        unit: unit,
        availability: availability ?? this.availability,
        isOnList86: (availability ?? this.availability) != 'available',
        notes: notes ?? this.notes,
        displayOrder: displayOrder,
        isActive: isActive,
      );

  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
        id: json['_id'] as String,
        name: json['name'] as String? ?? '',
        family: json['family'] as String? ?? '',
        unit: json['unit'] as String? ?? 'unité',
        availability: json['availability'] as String? ?? 'available',
        isOnList86: json['isOnList86'] as bool? ?? false,
        notes: json['notes'] as String?,
        displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
        isActive: json['isActive'] as bool? ?? true,
      );
}