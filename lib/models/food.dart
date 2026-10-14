/// A food from the Indian Food Composition Tables 2017.
///
/// Every nutrient value is per 100 g edible portion, exactly as published.
/// Price is deliberately absent: the app ships no prices at all, and the user
/// enters their own local prices, which are stored separately in [FoodPrice].
class Food {
  const Food({
    required this.id,
    required this.name,
    required this.ifctGroup,
    required this.group,
    required this.dietTag,
    required this.kcal,
    this.hindiName,
    this.scientificName,
    this.proteinG,
    this.carbG,
    this.fatG,
    this.fibreG,
    this.servingG,
    this.servingSourceId,
    this.energyDerived = false,
    this.energyFormula,
    this.energySourceId,
  });

  /// IFCT 2017 food code, for example "A015".
  final String id;
  final String name;
  final String? hindiName;
  final String? scientificName;

  /// IFCT food group label, for example "Cereals and Millets".
  final String ifctGroup;

  /// Simplified planner group: cereal, pulse, dairy, egg, flesh, root, leafy,
  /// vegetable, fruit, nut, fat, sugar, condiment, beverage.
  final String group;

  /// One of `veg`, `egg`, `nonveg`.
  final String dietTag;

  final int kcal;
  final double? proteinG;
  final double? carbG;
  final double? fatG;
  final double? fibreG;

  /// Published ICMR-NIN food-group portion size in grams. Null when the group
  /// has no published portion size, in which case the UI shows per 100 g only.
  final int? servingG;
  final String? servingSourceId;

  /// True when IFCT 2017 carries no computed energy value for this food, so
  /// the energy was derived from its published macronutrient content using the
  /// ICMR-NIN energy factors. Only the edible oils and fats group is affected.
  /// The UI labels these so a derived figure is never shown as a measured one.
  final bool energyDerived;
  final String? energyFormula;
  final String? energySourceId;

  bool get hasServing => servingG != null;

  /// Localised display name, falling back to the IFCT name.
  String displayName(String languageCode) {
    if (languageCode == 'hi' && (hindiName?.isNotEmpty ?? false)) {
      return hindiName!;
    }
    return name;
  }

  double get proteinPer100g => proteinG ?? 0;
  double get carbPer100g => carbG ?? 0;
  double get fatPer100g => fatG ?? 0;

  /// Kilocalories in [grams] of this food.
  double kcalFor(double grams) => kcal * grams / 100.0;

  double proteinFor(double grams) => proteinPer100g * grams / 100.0;

  double carbFor(double grams) => carbPer100g * grams / 100.0;

  double fatFor(double grams) => fatPer100g * grams / 100.0;

  /// True when this food fits a diet made of [allowedTags].
  bool fitsDiet(Set<String> allowedTags) => allowedTags.contains(dietTag);

  static Food fromJson(Map<String, dynamic> j) => Food(
    id: j['id'] as String,
    name: j['name'] as String,
    hindiName: j['hindiName'] as String?,
    scientificName: j['scientificName'] as String?,
    ifctGroup: j['ifctGroup'] as String,
    group: j['group'] as String,
    dietTag: j['dietTag'] as String,
    kcal: (j['kcal'] as num).toInt(),
    proteinG: (j['proteinG'] as num?)?.toDouble(),
    carbG: (j['carbG'] as num?)?.toDouble(),
    fatG: (j['fatG'] as num?)?.toDouble(),
    fibreG: (j['fibreG'] as num?)?.toDouble(),
    servingG: (j['servingG'] as num?)?.toInt(),
    servingSourceId: j['servingSourceId'] as String?,
    energyDerived: j['energyDerived'] == true,
    energyFormula: j['energyFormula'] as String?,
    energySourceId: j['energySourceId'] as String?,
  );
}

/// A price the user entered for a food, in rupees per kilogram.
///
/// The app never ships prices. Until the user enters one, budget planning for
/// that food is simply not possible and the UI says so.
class FoodPrice {
  const FoodPrice({
    required this.foodId,
    required this.pricePerKgInr,
    required this.updatedAt,
  });

  final String foodId;
  final double pricePerKgInr;
  final DateTime updatedAt;

  /// Cost in rupees of [grams] of this food.
  double costFor(double grams) => pricePerKgInr * grams / 1000.0;

  Map<String, dynamic> toJson() => {
    'foodId': foodId,
    'pricePerKgInr': pricePerKgInr,
    'updatedAt': updatedAt.toIso8601String(),
  };

  static FoodPrice fromJson(Map<String, dynamic> j) => FoodPrice(
    foodId: j['foodId'] as String,
    pricePerKgInr: (j['pricePerKgInr'] as num).toDouble(),
    updatedAt:
        DateTime.tryParse((j['updatedAt'] as String?) ?? '') ?? DateTime.now(),
  );
}
