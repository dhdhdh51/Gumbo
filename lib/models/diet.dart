import 'enums.dart';
import 'food.dart';

/// One food and quantity inside a planned or logged meal.
class MealItem {
  const MealItem({
    required this.foodId,
    required this.foodName,
    required this.grams,
    required this.kcal,
    required this.proteinG,
    this.carbG = 0,
    this.fatG = 0,
    this.costInr,
  });

  final String foodId;
  final String foodName;
  final double grams;
  final double kcal;
  final double proteinG;
  final double carbG;
  final double fatG;

  /// Null when the user has not entered a price for this food.
  final double? costInr;

  static MealItem fromFood(Food food, double grams, {double? pricePerKgInr}) =>
      MealItem(
        foodId: food.id,
        foodName: food.name,
        grams: grams,
        kcal: food.kcalFor(grams),
        proteinG: food.proteinFor(grams),
        carbG: food.carbFor(grams),
        fatG: food.fatFor(grams),
        costInr: pricePerKgInr == null ? null : pricePerKgInr * grams / 1000.0,
      );

  Map<String, dynamic> toJson() => {
    'foodId': foodId,
    'foodName': foodName,
    'grams': grams,
    'kcal': kcal,
    'proteinG': proteinG,
    'carbG': carbG,
    'fatG': fatG,
    'costInr': costInr,
  };

  static MealItem fromJson(Map<String, dynamic> j) => MealItem(
    foodId: j['foodId'] as String,
    foodName: (j['foodName'] as String?) ?? '',
    grams: (j['grams'] as num).toDouble(),
    kcal: (j['kcal'] as num).toDouble(),
    proteinG: (j['proteinG'] as num).toDouble(),
    carbG: (j['carbG'] as num?)?.toDouble() ?? 0,
    fatG: (j['fatG'] as num?)?.toDouble() ?? 0,
    costInr: (j['costInr'] as num?)?.toDouble(),
  );
}

/// A planned meal for one slot of the day.
class PlannedMeal {
  const PlannedMeal({required this.slot, required this.items});

  final MealSlot slot;
  final List<MealItem> items;

  double get kcal => items.fold(0.0, (s, i) => s + i.kcal);
  double get proteinG => items.fold(0.0, (s, i) => s + i.proteinG);
  double get carbG => items.fold(0.0, (s, i) => s + i.carbG);
  double get fatG => items.fold(0.0, (s, i) => s + i.fatG);

  /// Null when any item in the meal has no user-entered price, because a
  /// partial total would be misleading.
  double? get costInr {
    double total = 0;
    for (final i in items) {
      final c = i.costInr;
      if (c == null) return null;
      total += c;
    }
    return total;
  }
}

/// Why a budget meal plan could not fully meet the targets.
enum MealPlanShortfall {
  /// No prices entered yet, so cost cannot be optimised at all.
  noPrices,

  /// The cheapest combination that hits the targets still costs more than the
  /// user's monthly budget.
  budgetTooLow,

  /// Protein target could not be reached from the affordable foods available.
  proteinUnreachable,

  /// Calorie target could not be reached from the affordable foods available.
  caloriesUnreachable,
}

/// A whole day of planned meals, built from the real food database.
class DayMealPlan {
  const DayMealPlan({
    required this.meals,
    required this.targetKcal,
    required this.targetProteinG,
    required this.shortfalls,
    this.dailyBudgetInr,
    this.pricedFoodCount = 0,
  });

  const DayMealPlan.empty({
    this.targetKcal = 0,
    this.targetProteinG = 0,
    this.dailyBudgetInr,
  }) : meals = const [],
       shortfalls = const [],
       pricedFoodCount = 0;

  final List<PlannedMeal> meals;
  final int targetKcal;
  final int targetProteinG;

  /// Problems the planner hit. Reported honestly instead of silently producing
  /// a plan that does not meet the target.
  final List<MealPlanShortfall> shortfalls;

  /// Derived from the monthly budget the user set, or null when none is set.
  final double? dailyBudgetInr;

  /// How many foods the user has entered a price for.
  final int pricedFoodCount;

  bool get isEmpty => meals.isEmpty;

  double get totalKcal => meals.fold(0.0, (s, m) => s + m.kcal);
  double get totalProteinG => meals.fold(0.0, (s, m) => s + m.proteinG);
  double get totalCarbG => meals.fold(0.0, (s, m) => s + m.carbG);
  double get totalFatG => meals.fold(0.0, (s, m) => s + m.fatG);

  /// Null when any meal has an unpriced item.
  double? get totalCostInr {
    double total = 0;
    for (final m in meals) {
      final c = m.costInr;
      if (c == null) return null;
      total += c;
    }
    return total;
  }

  bool get withinBudget {
    final cost = totalCostInr;
    final budget = dailyBudgetInr;
    if (cost == null || budget == null) return true;
    return cost <= budget;
  }
}

/// A meal the user actually ate.
class FoodLogEntry {
  const FoodLogEntry({
    required this.id,
    required this.loggedAt,
    required this.slot,
    required this.item,
  });

  final int id;
  final DateTime loggedAt;
  final MealSlot slot;
  final MealItem item;

  Map<String, dynamic> toJson() => {
    'id': id,
    'loggedAt': loggedAt.toIso8601String(),
    'slot': slot.name,
    'item': item.toJson(),
  };
}

/// Water logged for one day, in millilitres.
class WaterLogEntry {
  const WaterLogEntry({required this.day, required this.millilitres});

  /// Date only, normalised to midnight local time.
  final DateTime day;
  final int millilitres;

  Map<String, dynamic> toJson() => {
    'day': day.toIso8601String(),
    'millilitres': millilitres,
  };
}

/// Totals eaten so far today, used for progress rings and empty states.
class DayNutritionTotals {
  const DayNutritionTotals({
    required this.kcal,
    required this.proteinG,
    required this.carbG,
    required this.fatG,
    required this.entryCount,
  });

  static const DayNutritionTotals empty = DayNutritionTotals(
    kcal: 0,
    proteinG: 0,
    carbG: 0,
    fatG: 0,
    entryCount: 0,
  );

  final double kcal;
  final double proteinG;
  final double carbG;
  final double fatG;
  final int entryCount;

  bool get hasData => entryCount > 0;
}
