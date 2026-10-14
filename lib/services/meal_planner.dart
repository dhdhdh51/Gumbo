import 'dart:math' as math;

import '../models/diet.dart';
import '../models/enums.dart';
import '../models/food.dart';
import '../models/guideline_data.dart';

/// One chosen food and the amount of it.
class FoodPick {
  const FoodPick({required this.food, required this.grams, this.pricePerKgInr});

  final Food food;
  final double grams;
  final double? pricePerKgInr;

  double get kcal => food.kcalFor(grams);
  double get proteinG => food.proteinFor(grams);
  double? get costInr =>
      pricePerKgInr == null ? null : pricePerKgInr! * grams / 1000.0;

  FoodPick addGrams(double extra) =>
      FoodPick(food: food, grams: grams + extra, pricePerKgInr: pricePerKgInr);
}

/// Builds a day of Indian meals from the shipped IFCT food database.
///
/// Two modes:
///
///   * Budget mode. Used once the user has entered at least one local price.
///     Picks foods and quantities that reach the protein and calorie targets at
///     the lowest cost, and reports honestly when the budget cannot cover it.
///
///   * Guideline mode. Used when no prices have been entered yet. Builds a
///     balanced plate from the ICMR-NIN "My Plate for the Day" group amounts,
///     scaled to the user's calorie target, with no cost figures at all. The
///     app never invents a price.
class MealPlanner {
  const MealPlanner._();

  /// Average days in a month (365 / 12), used to turn a monthly budget into a
  /// daily one.
  static const double daysPerMonth = 30.4167;

  /// Groups that are never used as the backbone of a meal plan.
  static const Set<String> _excludedGroups = {'condiment', 'beverage'};

  /// Preferred staple for each group, by IFCT code, used in guideline mode so
  /// the plan is a recognisable Indian plate rather than an arbitrary pick.
  static const Map<String, List<String>> _staples = {
    'cereal': ['A019', 'A015', 'A010', 'A005'],
    'pulse': ['B021', 'B010', 'B001', 'B013'],
    'dairy': ['L002', 'L003'],
    'leafy': ['C033', 'C020', 'C002'],
    'vegetable': ['D076', 'D056', 'D036', 'D007'],
    'root': ['F006', 'F002'],
    'fruit': ['E012', 'E001', 'E049'],
    'nut': ['H012', 'H001'],
    'fat': ['T005', 'T006'],
    'egg': ['M004', 'M001'],
    'flesh': ['N003', 'S006', 'P034'],
  };

  /// Daily rupee budget from a monthly figure. Returns null when unset.
  static double? dailyBudget(int monthlyBudgetInr) =>
      monthlyBudgetInr <= 0 ? null : monthlyBudgetInr / daysPerMonth;

  /// Build the day's plan.
  static DayMealPlan plan({
    required GuidelineData data,
    required DietType dietType,
    required int targetKcal,
    required int targetProteinG,
    required int monthlyBudgetInr,
    required Map<String, FoodPrice> prices,
  }) {
    if (targetKcal <= 0 || targetProteinG <= 0) {
      return DayMealPlan.empty(
        targetKcal: targetKcal,
        targetProteinG: targetProteinG,
        dailyBudgetInr: dailyBudget(monthlyBudgetInr),
      );
    }

    final allowed = dietType.allowedFoodTags;
    final pool =
        data.foods
            .where((f) => f.fitsDiet(allowed))
            .where((f) => !_excludedGroups.contains(f.group))
            .where((f) => f.kcal > 0)
            .toList();

    final priced = pool.where((f) => prices.containsKey(f.id)).toList();

    if (priced.isEmpty) {
      return _guidelinePlan(
        data: data,
        pool: pool,
        targetKcal: targetKcal,
        targetProteinG: targetProteinG,
        monthlyBudgetInr: monthlyBudgetInr,
        pricedFoodCount: 0,
      );
    }

    return _budgetPlan(
      pool: priced,
      prices: prices,
      targetKcal: targetKcal,
      targetProteinG: targetProteinG,
      monthlyBudgetInr: monthlyBudgetInr,
    );
  }

  // ------------------------------------------------------------ budget mode

  /// Cheapest-first plan over the foods the user has priced.
  ///
  /// Protein is bought first, because it is the harder and usually dearer
  /// target, then the remaining calories are filled from the cheapest energy
  /// available. Both passes respect a per-food cap so the result is a plate
  /// someone would actually eat rather than two kilograms of one dal.
  static DayMealPlan _budgetPlan({
    required List<Food> pool,
    required Map<String, FoodPrice> prices,
    required int targetKcal,
    required int targetProteinG,
    required int monthlyBudgetInr,
  }) {
    final shortfalls = <MealPlanShortfall>[];
    final picks = <String, FoodPick>{};

    double step(Food f) => (f.servingG ?? 25).toDouble();

    /// Daily cap per food: six portions, and never more than 500 g, so one
    /// cheap staple cannot take over the whole plan.
    double cap(Food f) => math.min(step(f) * 6, 500);

    void add(Food f, double grams) {
      final existing = picks[f.id];
      picks[f.id] =
          existing == null
              ? FoodPick(
                food: f,
                grams: grams,
                pricePerKgInr: prices[f.id]!.pricePerKgInr,
              )
              : existing.addGrams(grams);
    }

    double totalProtein() => picks.values.fold(0.0, (s, p) => s + p.proteinG);
    double totalKcal() => picks.values.fold(0.0, (s, p) => s + p.kcal);

    // ---- pass 1: reach the protein target as cheaply as possible
    final proteinSources =
        pool.where((f) => f.proteinPer100g >= 3).toList()..sort((a, b) {
          final ca = _costPerGramProtein(a, prices[a.id]!.pricePerKgInr);
          final cb = _costPerGramProtein(b, prices[b.id]!.pricePerKgInr);
          return ca.compareTo(cb);
        });

    for (final f in proteinSources) {
      if (totalProtein() >= targetProteinG) break;
      final s = step(f);
      final limit = cap(f);
      var added = picks[f.id]?.grams ?? 0;
      while (added + s <= limit && totalProtein() < targetProteinG) {
        add(f, s);
        added += s;
      }
    }

    if (totalProtein() < targetProteinG) {
      shortfalls.add(MealPlanShortfall.proteinUnreachable);
    }

    // ---- pass 2: fill remaining calories with the cheapest energy
    final energySources =
        pool.toList()..sort((a, b) {
          final ca = _costPerKcal(a, prices[a.id]!.pricePerKgInr);
          final cb = _costPerKcal(b, prices[b.id]!.pricePerKgInr);
          return ca.compareTo(cb);
        });

    for (final f in energySources) {
      if (totalKcal() >= targetKcal) break;
      final s = step(f);
      final limit = cap(f);
      var added = picks[f.id]?.grams ?? 0;
      while (added + s <= limit &&
          totalKcal() + f.kcalFor(s) <= targetKcal * 1.02) {
        add(f, s);
        added += s;
      }
    }

    if (totalKcal() < targetKcal * 0.9) {
      shortfalls.add(MealPlanShortfall.caloriesUnreachable);
    }

    // ---- budget check, reported rather than silently enforced
    final budget = dailyBudget(monthlyBudgetInr);
    final cost = picks.values.fold<double>(0, (s, p) => s + (p.costInr ?? 0));
    if (budget != null && cost > budget) {
      shortfalls.add(MealPlanShortfall.budgetTooLow);
    }

    return DayMealPlan(
      meals: _distribute(picks.values.toList()),
      targetKcal: targetKcal,
      targetProteinG: targetProteinG,
      shortfalls: shortfalls,
      dailyBudgetInr: budget,
      pricedFoodCount: prices.length,
    );
  }

  /// Rupees per gram of protein. Foods with no protein sort last.
  static double _costPerGramProtein(Food f, double pricePerKgInr) {
    final p = f.proteinPer100g;
    if (p <= 0) return double.maxFinite;
    return pricePerKgInr / 10.0 / p;
  }

  /// Rupees per kilocalorie.
  static double _costPerKcal(Food f, double pricePerKgInr) {
    if (f.kcal <= 0) return double.maxFinite;
    return pricePerKgInr / 10.0 / f.kcal;
  }

  // --------------------------------------------------------- guideline mode

  /// Balanced plate from the ICMR-NIN My Plate group amounts, scaled to the
  /// user's calorie target. No prices are shown because none are known.
  static DayMealPlan _guidelinePlan({
    required GuidelineData data,
    required List<Food> pool,
    required int targetKcal,
    required int targetProteinG,
    required int monthlyBudgetInr,
    required int pricedFoodCount,
  }) {
    // My Plate is published for a 2000 kcal day, so scale by the ratio.
    final scale = targetKcal / 2000.0;

    final picks = <FoodPick>[];

    for (final group in data.myPlateGroups) {
      final key = group['group'] as String?;
      if (key == null) continue;
      final grams =
          (group['gramsPerDay'] ?? group['millilitresPerDay']) as num?;
      if (grams == null) continue;

      // "Pulses, eggs and flesh foods" is one My Plate group; pick whichever
      // the user's diet allows, preferring pulses so a veg plate still works.
      final groupsToTry =
          key == 'pulse'
              ? ['pulse', 'egg', 'flesh']
              : key == 'vegetable'
              ? ['vegetable', 'leafy', 'root']
              : [key];

      final share =
          key == 'vegetable' || key == 'pulse'
              ? grams.toDouble() / groupsToTry.length
              : grams.toDouble();

      for (final g in groupsToTry) {
        final food = _pickStaple(pool, g);
        if (food == null) continue;
        picks.add(FoodPick(food: food, grams: _roundGrams(share * scale)));
      }
    }

    final shortfalls = <MealPlanShortfall>[MealPlanShortfall.noPrices];

    return DayMealPlan(
      meals: _distribute(picks),
      targetKcal: targetKcal,
      targetProteinG: targetProteinG,
      shortfalls: shortfalls,
      dailyBudgetInr: dailyBudget(monthlyBudgetInr),
      pricedFoodCount: pricedFoodCount,
    );
  }

  /// Preferred staple for a group, falling back to the first available food.
  static Food? _pickStaple(List<Food> pool, String group) {
    final inGroup = pool.where((f) => f.group == group).toList();
    if (inGroup.isEmpty) return null;
    for (final code in _staples[group] ?? const <String>[]) {
      final hit = inGroup.where((f) => f.id == code).firstOrNull;
      if (hit != null) return hit;
    }
    inGroup.sort((a, b) => a.name.compareTo(b.name));
    return inGroup.first;
  }

  static double _roundGrams(double g) => (g / 5).round() * 5.0;

  // ------------------------------------------------------------- meal slots

  /// Spread the chosen foods across breakfast, lunch, snack and dinner.
  ///
  /// Deterministic so the same inputs always give the same plan: group decides
  /// which slots a food can appear in, and larger amounts get split across the
  /// two main meals.
  static List<PlannedMeal> _distribute(List<FoodPick> picks) {
    if (picks.isEmpty) return const [];

    final slots = <MealSlot, List<MealItem>>{
      MealSlot.breakfast: [],
      MealSlot.lunch: [],
      MealSlot.snack: [],
      MealSlot.dinner: [],
    };

    for (final pick in picks) {
      if (pick.grams <= 0) continue;
      final plan = _slotPlanFor(pick.food.group);
      for (final entry in plan) {
        final grams = pick.grams * entry.share;
        if (grams < 1) continue;
        slots[entry.slot]!.add(
          MealItem.fromFood(
            pick.food,
            _roundGrams(grams),
            pricePerKgInr: pick.pricePerKgInr,
          ),
        );
      }
    }

    return [
      for (final slot in MealSlot.values)
        if (slots[slot]!.isNotEmpty)
          PlannedMeal(slot: slot, items: slots[slot]!),
    ];
  }

  /// Which slots a food group belongs in, and what share goes to each.
  static List<({MealSlot slot, double share})> _slotPlanFor(String group) =>
      switch (group) {
        'cereal' => const [
          (slot: MealSlot.breakfast, share: 0.25),
          (slot: MealSlot.lunch, share: 0.4),
          (slot: MealSlot.dinner, share: 0.35),
        ],
        'pulse' => const [
          (slot: MealSlot.lunch, share: 0.5),
          (slot: MealSlot.dinner, share: 0.5),
        ],
        'flesh' || 'egg' => const [
          (slot: MealSlot.lunch, share: 0.5),
          (slot: MealSlot.dinner, share: 0.5),
        ],
        'dairy' => const [
          (slot: MealSlot.breakfast, share: 0.6),
          (slot: MealSlot.snack, share: 0.4),
        ],
        'fruit' => const [(slot: MealSlot.snack, share: 1.0)],
        'nut' => const [(slot: MealSlot.snack, share: 1.0)],
        'leafy' || 'vegetable' => const [
          (slot: MealSlot.lunch, share: 0.5),
          (slot: MealSlot.dinner, share: 0.5),
        ],
        'root' => const [(slot: MealSlot.lunch, share: 1.0)],
        'fat' => const [
          (slot: MealSlot.lunch, share: 0.5),
          (slot: MealSlot.dinner, share: 0.5),
        ],
        'sugar' => const [(slot: MealSlot.breakfast, share: 1.0)],
        _ => const [(slot: MealSlot.lunch, share: 1.0)],
      };
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
