import 'package:flutter_test/flutter_test.dart';
import 'package:trainerapp/models/diet.dart';
import 'package:trainerapp/models/enums.dart';
import 'package:trainerapp/models/food.dart';
import 'package:trainerapp/services/meal_planner.dart';

import 'support/test_data.dart';

void main() {
  final data = loadGuidelineData();

  /// Prices the user "entered" for a handful of staples, in rupees per kg.
  /// These are test inputs only; the app ships no prices whatsoever.
  Map<String, FoodPrice> pricesFor(Map<String, double> perKg) => {
    for (final e in perKg.entries)
      e.key: FoodPrice(
        foodId: e.key,
        pricePerKgInr: e.value,
        updatedAt: DateTime(2026, 1, 1),
      ),
  };

  final vegPrices = pricesFor({
    'A019': 45, // wheat flour, atta
    'A015': 55, // rice, raw, milled
    'B021': 160, // red gram dal
    'B010': 130, // green gram dal
    'L002': 60, // cow milk
    'L003': 400, // paneer
    'D076': 30, // tomato
    'C033': 40, // spinach
    'E012': 60, // banana
    'H012': 140, // groundnut
    'T005': 180, // groundnut oil
  });

  group('daily budget', () {
    test('a monthly budget becomes a daily one', () {
      final d = MealPlanner.dailyBudget(6000)!;
      expect(d, closeTo(6000 / 30.4167, 0.01));
    });

    test('no budget set means no daily budget', () {
      expect(MealPlanner.dailyBudget(0), isNull);
      expect(MealPlanner.dailyBudget(-5), isNull);
    });
  });

  group('guideline mode, when the user has entered no prices', () {
    test('reports the missing prices rather than inventing them', () {
      final plan = MealPlanner.plan(
        data: data,
        dietType: DietType.veg,
        targetKcal: 2000,
        targetProteinG: 90,
        monthlyBudgetInr: 6000,
        prices: const {},
      );
      expect(plan.shortfalls, contains(MealPlanShortfall.noPrices));
      expect(plan.pricedFoodCount, 0);
      expect(plan.totalCostInr, isNull);
      for (final meal in plan.meals) {
        expect(meal.costInr, isNull);
        for (final item in meal.items) {
          expect(item.costInr, isNull);
        }
      }
    });

    test('still produces a usable balanced plate', () {
      final plan = MealPlanner.plan(
        data: data,
        dietType: DietType.veg,
        targetKcal: 2000,
        targetProteinG: 90,
        monthlyBudgetInr: 0,
        prices: const {},
      );
      expect(plan.meals, isNotEmpty);
      expect(plan.totalKcal, greaterThan(0));
      // My Plate is published for 2000 kcal, so a 2000 kcal target should land
      // reasonably close without any scaling distortion.
      expect(plan.totalKcal, inInclusiveRange(1200, 2600));
    });

    test('scales with the calorie target', () {
      final small = MealPlanner.plan(
        data: data,
        dietType: DietType.veg,
        targetKcal: 1500,
        targetProteinG: 70,
        monthlyBudgetInr: 0,
        prices: const {},
      );
      final large = MealPlanner.plan(
        data: data,
        dietType: DietType.veg,
        targetKcal: 3000,
        targetProteinG: 140,
        monthlyBudgetInr: 0,
        prices: const {},
      );
      expect(large.totalKcal, greaterThan(small.totalKcal));
    });
  });

  group('diet type is always respected', () {
    test('a veg plan contains only veg-tagged foods', () {
      for (final prices in [const <String, FoodPrice>{}, vegPrices]) {
        final plan = MealPlanner.plan(
          data: data,
          dietType: DietType.veg,
          targetKcal: 2200,
          targetProteinG: 100,
          monthlyBudgetInr: 9000,
          prices: prices,
        );
        for (final meal in plan.meals) {
          for (final item in meal.items) {
            expect(
              data.foodById(item.foodId)!.dietTag,
              'veg',
              reason: item.foodName,
            );
          }
        }
      }
    });

    test('an egg diet allows veg and egg but never meat or fish', () {
      final prices = pricesFor({
        ...{for (final e in vegPrices.entries) e.key: e.value.pricePerKgInr},
        'M004': 7,
        'N003': 250,
      });
      final plan = MealPlanner.plan(
        data: data,
        dietType: DietType.egg,
        targetKcal: 2200,
        targetProteinG: 110,
        monthlyBudgetInr: 9000,
        prices: prices,
      );
      final tags = <String>{};
      for (final meal in plan.meals) {
        for (final item in meal.items) {
          tags.add(data.foodById(item.foodId)!.dietTag);
        }
      }
      expect(tags, isNot(contains('nonveg')));
    });

    test('a non-veg diet may use any food', () {
      final prices = pricesFor({
        'A019': 45,
        'B021': 160,
        'N003': 240, // chicken breast
        'S006': 220, // rohu
        'D076': 30,
      });
      final plan = MealPlanner.plan(
        data: data,
        dietType: DietType.nonVeg,
        targetKcal: 2400,
        targetProteinG: 130,
        monthlyBudgetInr: 12000,
        prices: prices,
      );
      expect(plan.meals, isNotEmpty);
      expect(plan.shortfalls, isNot(contains(MealPlanShortfall.noPrices)));
    });
  });

  group('budget mode', () {
    test('only priced foods are used', () {
      final plan = MealPlanner.plan(
        data: data,
        dietType: DietType.veg,
        targetKcal: 2200,
        targetProteinG: 100,
        monthlyBudgetInr: 9000,
        prices: vegPrices,
      );
      for (final meal in plan.meals) {
        for (final item in meal.items) {
          expect(vegPrices.keys, contains(item.foodId), reason: item.foodName);
          expect(item.costInr, isNotNull);
        }
      }
      expect(plan.totalCostInr, isNotNull);
    });

    test('reaches the protein target when it is achievable', () {
      final plan = MealPlanner.plan(
        data: data,
        dietType: DietType.veg,
        targetKcal: 2200,
        targetProteinG: 90,
        monthlyBudgetInr: 9000,
        prices: vegPrices,
      );
      expect(
        plan.shortfalls,
        isNot(contains(MealPlanShortfall.proteinUnreachable)),
      );
      expect(plan.totalProteinG, greaterThanOrEqualTo(90));
    });

    test('does not blow past the calorie target', () {
      final plan = MealPlanner.plan(
        data: data,
        dietType: DietType.veg,
        targetKcal: 2200,
        targetProteinG: 90,
        monthlyBudgetInr: 9000,
        prices: vegPrices,
      );
      expect(plan.totalKcal, lessThanOrEqualTo(2200 * 1.1));
    });

    test('prefers the cheaper of two protein sources', () {
      // Paneer is priced far above dal, so the planner should lean on dal.
      final plan = MealPlanner.plan(
        data: data,
        dietType: DietType.veg,
        targetKcal: 2200,
        targetProteinG: 100,
        monthlyBudgetInr: 9000,
        prices: vegPrices,
      );
      double gramsOf(String id) {
        double g = 0;
        for (final m in plan.meals) {
          for (final i in m.items) {
            if (i.foodId == id) g += i.grams;
          }
        }
        return g;
      }

      expect(gramsOf('B021') + gramsOf('B010'), greaterThan(gramsOf('L003')));
    });

    test('says so honestly when the budget is too low', () {
      final plan = MealPlanner.plan(
        data: data,
        dietType: DietType.veg,
        targetKcal: 2600,
        targetProteinG: 130,
        monthlyBudgetInr: 300, // about 10 rupees a day
        prices: vegPrices,
      );
      expect(plan.shortfalls, contains(MealPlanShortfall.budgetTooLow));
      expect(plan.withinBudget, isFalse);
      // The plan is still returned so the user can see what it would cost.
      expect(plan.meals, isNotEmpty);
      expect(plan.totalCostInr, isNotNull);
    });

    test('a generous budget is reported as within budget', () {
      final plan = MealPlanner.plan(
        data: data,
        dietType: DietType.veg,
        targetKcal: 2200,
        targetProteinG: 90,
        monthlyBudgetInr: 30000,
        prices: vegPrices,
      );
      expect(plan.shortfalls, isNot(contains(MealPlanShortfall.budgetTooLow)));
      expect(plan.withinBudget, isTrue);
    });

    test('reports an unreachable protein target instead of faking it', () {
      // Only oil is priced: plenty of energy, almost no protein.
      final plan = MealPlanner.plan(
        data: data,
        dietType: DietType.veg,
        targetKcal: 2000,
        targetProteinG: 120,
        monthlyBudgetInr: 9000,
        prices: pricesFor({'T005': 180}),
      );
      expect(plan.shortfalls, contains(MealPlanShortfall.proteinUnreachable));
      expect(plan.totalProteinG, lessThan(120));
    });

    test('no single food is allowed to dominate the day', () {
      final plan = MealPlanner.plan(
        data: data,
        dietType: DietType.veg,
        targetKcal: 2600,
        targetProteinG: 120,
        monthlyBudgetInr: 20000,
        prices: vegPrices,
      );
      final grams = <String, double>{};
      for (final m in plan.meals) {
        for (final i in m.items) {
          grams[i.foodId] = (grams[i.foodId] ?? 0) + i.grams;
        }
      }
      for (final e in grams.entries) {
        expect(
          e.value,
          lessThanOrEqualTo(520),
          reason: '${e.key} reached ${e.value} g',
        );
      }
    });

    test('is deterministic: the same inputs give the same plan', () {
      DayMealPlan build() => MealPlanner.plan(
        data: data,
        dietType: DietType.veg,
        targetKcal: 2200,
        targetProteinG: 100,
        monthlyBudgetInr: 9000,
        prices: vegPrices,
      );
      final a = build();
      final b = build();
      expect(a.totalKcal, b.totalKcal);
      expect(a.totalProteinG, b.totalProteinG);
      expect(a.totalCostInr, b.totalCostInr);
      expect(a.meals.length, b.meals.length);
    });
  });

  group('meal structure', () {
    test('foods land in sensible slots', () {
      final plan = MealPlanner.plan(
        data: data,
        dietType: DietType.veg,
        targetKcal: 2200,
        targetProteinG: 90,
        monthlyBudgetInr: 9000,
        prices: vegPrices,
      );
      final slots = plan.meals.map((m) => m.slot).toList();
      expect(slots, isNotEmpty);
      // Slots always come out in day order.
      final indices = slots.map((s) => MealSlot.values.indexOf(s)).toList();
      final sorted = [...indices]..sort();
      expect(indices, sorted);
      // No meal is created empty.
      for (final m in plan.meals) {
        expect(m.items, isNotEmpty);
      }
    });

    test('meal totals add up to the day totals', () {
      final plan = MealPlanner.plan(
        data: data,
        dietType: DietType.veg,
        targetKcal: 2200,
        targetProteinG: 90,
        monthlyBudgetInr: 9000,
        prices: vegPrices,
      );
      final sumKcal = plan.meals.fold<double>(0, (s, m) => s + m.kcal);
      expect(plan.totalKcal, closeTo(sumKcal, 0.001));
    });

    test('an empty target yields an empty plan, not a broken one', () {
      final plan = MealPlanner.plan(
        data: data,
        dietType: DietType.veg,
        targetKcal: 0,
        targetProteinG: 0,
        monthlyBudgetInr: 0,
        prices: const {},
      );
      expect(plan.isEmpty, isTrue);
      expect(plan.meals, isEmpty);
    });
  });
}
