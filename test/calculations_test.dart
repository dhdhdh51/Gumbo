import 'package:flutter_test/flutter_test.dart';
import 'package:trainerapp/models/enums.dart';
import 'package:trainerapp/models/progress.dart';
import 'package:trainerapp/models/targets.dart';
import 'package:trainerapp/services/calculations.dart';

import 'support/test_data.dart';

void main() {
  final data = loadGuidelineData();

  group('Mifflin-St Jeor BMR', () {
    test('male worked example', () {
      // 10*80 + 6.25*180 - 5*30 + 5 = 800 + 1125 - 150 + 5 = 1780
      final v = Calculations.bmr(
        sex: Sex.male,
        weightKg: 80,
        heightCm: 180,
        ageYears: 30,
      );
      expect(v, closeTo(1780, 0.001));
    });

    test('female worked example', () {
      // 10*60 + 6.25*165 - 5*30 - 161 = 600 + 1031.25 - 150 - 161 = 1320.25
      final v = Calculations.bmr(
        sex: Sex.female,
        weightKg: 60,
        heightCm: 165,
        ageYears: 30,
      );
      expect(v, closeTo(1320.25, 0.001));
    });

    test('female result is 166 kcal below male for identical inputs', () {
      final male = Calculations.bmr(
        sex: Sex.male,
        weightKg: 70,
        heightCm: 170,
        ageYears: 25,
      );
      final female = Calculations.bmr(
        sex: Sex.female,
        weightKg: 70,
        heightCm: 170,
        ageYears: 25,
      );
      expect(male - female, closeTo(166, 0.001));
    });

    test('BMR falls as age rises', () {
      final young = Calculations.bmr(
        sex: Sex.male,
        weightKg: 70,
        heightCm: 175,
        ageYears: 20,
      );
      final old = Calculations.bmr(
        sex: Sex.male,
        weightKg: 70,
        heightCm: 175,
        ageYears: 70,
      );
      expect(young - old, closeTo(250, 0.001)); // 5 kcal per year over 50 years
    });
  });

  group('maintenance calories', () {
    test('sedentary uses the published ICMR-NIN PAL of 1.40', () {
      final bmr = Calculations.bmr(
        sex: Sex.male,
        weightKg: 65,
        heightCm: 170,
        ageYears: 30,
      );
      final maintenance = Calculations.maintenance(
        data: data,
        sex: Sex.male,
        level: ActivityLevel.sedentary,
        bmrKcal: bmr,
      );
      expect(maintenance, closeTo(bmr * 1.40, 0.001));
    });

    test('maintenance rises with activity level', () {
      final bmr = 1600.0;
      final sed = Calculations.maintenance(
        data: data,
        sex: Sex.male,
        level: ActivityLevel.sedentary,
        bmrKcal: bmr,
      );
      final mod = Calculations.maintenance(
        data: data,
        sex: Sex.male,
        level: ActivityLevel.moderate,
        bmrKcal: bmr,
      );
      final heavy = Calculations.maintenance(
        data: data,
        sex: Sex.male,
        level: ActivityLevel.heavy,
        bmrKcal: bmr,
      );
      expect(mod, greaterThan(sed));
      expect(heavy, greaterThan(mod));
    });

    test('ICMR reference scales the published kcal/kg by body weight', () {
      // Adult man, sedentary: 32 kcal/kg/day published by ICMR-NIN 2020.
      final ref = Calculations.icmrReference(
        data: data,
        sex: Sex.male,
        level: ActivityLevel.sedentary,
        weightKg: 65,
      );
      expect(ref, 32 * 65);
    });
  });

  group('goal adjustment', () {
    test('gain adds a surplus and lose subtracts a deficit', () {
      final base = testProfile(weightKg: 80, heightCm: 180, age: 30);

      final maintain = Calculations.nutritionTargets(
        data: data,
        profile: base,
        access: AccessLevel.full,
      );
      final gain = Calculations.nutritionTargets(
        data: data,
        profile: base.copyWith(goal: Goal.gain),
        access: AccessLevel.full,
      );
      final lose = Calculations.nutritionTargets(
        data: data,
        profile: base.copyWith(goal: Goal.lose),
        access: AccessLevel.full,
      );

      expect(gain.targetKcal, greaterThan(maintain.targetKcal));
      expect(lose.targetKcal, lessThan(maintain.targetKcal));
      expect(gain.targetKcal - maintain.targetKcal, 300);
      expect(maintain.targetKcal - lose.targetKcal, 400);
    });

    test('maintain target equals maintenance and has no clamps', () {
      final t = Calculations.nutritionTargets(
        data: data,
        profile: testProfile(weightKg: 75, heightCm: 178),
        access: AccessLevel.full,
      );
      expect(t.targetKcal, t.maintenanceKcal.round());
      expect(t.clamps, isEmpty);
      expect(t.goalApplied, Goal.maintain);
    });
  });

  group('safe limits', () {
    test('never drops below the Mifflin-St Jeor BMR', () {
      // A small, light person on a Lose goal: the raw deficit would undercut BMR.
      final t = Calculations.nutritionTargets(
        data: data,
        profile: testProfile(
          sex: Sex.female,
          weightKg: 48,
          heightCm: 150,
          age: 55,
          goal: Goal.lose,
        ),
        access: AccessLevel.full,
      );
      expect(t.targetKcal, greaterThanOrEqualTo(t.bmrKcal.round()));
    });

    test('never drops below the ICMR-NIN 1000 kcal weight-reduction floor', () {
      final t = Calculations.nutritionTargets(
        data: data,
        profile: testProfile(
          sex: Sex.female,
          weightKg: 40,
          heightCm: 140,
          age: 70,
          goal: Goal.lose,
        ),
        access: AccessLevel.full,
      );
      expect(t.targetKcal, greaterThanOrEqualTo(1000));
    });

    test('deficit is capped at 40% of estimated needs', () {
      final t = Calculations.nutritionTargets(
        data: data,
        profile: testProfile(weightKg: 70, goal: Goal.lose),
        access: AccessLevel.full,
      );
      expect(
        t.targetKcal,
        greaterThanOrEqualTo((t.maintenanceKcal * 0.6).floor()),
      );
    });

    test('weekly loss never exceeds half a kilogram', () {
      for (final weight in [50.0, 60.0, 80.0, 110.0]) {
        final t = Calculations.nutritionTargets(
          data: data,
          profile: testProfile(weightKg: weight, goal: Goal.lose),
          access: AccessLevel.full,
        );
        expect(
          t.weeklyChangeKg,
          greaterThanOrEqualTo(-0.5001),
          reason: 'weight $weight kg produced ${t.weeklyChangeKg} kg/week',
        );
      }
    });

    test('weekly loss cap also respects 1% of body weight for light users', () {
      // 40 kg user: 1% is 0.4 kg, which is stricter than the 0.5 kg rule.
      final cap = Calculations.maxWeeklyLossKg(data: data, weightKg: 40);
      expect(cap, closeTo(0.4, 0.0001));

      // 80 kg user: 1% is 0.8 kg, so the 0.5 kg rule governs.
      expect(
        Calculations.maxWeeklyLossKg(data: data, weightKg: 80),
        closeTo(0.5, 0.0001),
      );
    });

    test('calorie floor is the higher of BMR and the ICMR floor', () {
      expect(Calculations.calorieFloor(data: data, bmrKcal: 900), 1000);
      expect(Calculations.calorieFloor(data: data, bmrKcal: 1700), 1700);
    });

    test('BMI below 18.5 blocks the weight-loss goal', () {
      // 45 kg at 170 cm is a BMI of about 15.6.
      expect(
        Calculations.weightLossBlockedByBmi(
          data: data,
          weightKg: 45,
          heightCm: 170,
        ),
        isTrue,
      );
      // 60 kg at 170 cm is a BMI of about 20.8.
      expect(
        Calculations.weightLossBlockedByBmi(
          data: data,
          weightKg: 60,
          heightCm: 170,
        ),
        isFalse,
      );
    });

    test('underweight user asking to lose is switched to maintain', () {
      final t = Calculations.nutritionTargets(
        data: data,
        profile: testProfile(weightKg: 45, heightCm: 170, goal: Goal.lose),
        access: AccessLevel.full,
      );
      expect(t.goalApplied, Goal.maintain);
      expect(t.hasClamp(TargetClamp.underweightNoLoss), isTrue);
    });

    test('a serious screening flag without clearance blocks the deficit', () {
      final t = Calculations.nutritionTargets(
        data: data,
        profile: testProfile(weightKg: 90, heightCm: 175, goal: Goal.lose),
        access: AccessLevel.full,
        medicalClearance: false,
      );
      expect(t.goalApplied, Goal.maintain);
    });

    test('gain surplus is capped so weekly gain stays moderate', () {
      // The cap is half a kilogram per week, matching the ICMR-NIN safe rate of
      // change, so the default 300 kcal surplus fits inside it.
      final t = Calculations.nutritionTargets(
        data: data,
        profile: testProfile(weightKg: 55, heightCm: 165, goal: Goal.gain),
        access: AccessLevel.full,
      );
      expect(t.weeklyChangeKg, lessThanOrEqualTo(0.5001));

      // An unreasonably large stall nudge still cannot exceed the cap.
      final nudged = Calculations.nutritionTargets(
        data: data,
        profile: testProfile(weightKg: 55, heightCm: 165, goal: Goal.gain),
        access: AccessLevel.full,
        weightTrendAdjustmentKcal: 2000,
      );
      expect(nudged.weeklyChangeKg, lessThanOrEqualTo(0.5001));
    });
  });

  group('minors', () {
    test('a 15 year old never gets a calorie deficit', () {
      final t = Calculations.nutritionTargets(
        data: data,
        profile: testProfile(age: 15, weightKg: 70, goal: Goal.lose),
        access: AccessLevel.activityOnly,
      );
      expect(t.goalApplied, Goal.maintain);
      expect(t.hasClamp(TargetClamp.minorNoDeficit), isTrue);
      expect(t.targetKcal, greaterThanOrEqualTo(t.maintenanceKcal.round()));
    });

    test('a minor protein target uses the ICMR-NIN adolescent RDA', () {
      // Boys 16-18: RDA 0.86 g/kg/day.
      final p = Calculations.proteinTarget(
        data: data,
        profile: testProfile(age: 17, sex: Sex.male, weightKg: 60),
        access: AccessLevel.activityOnly,
      );
      expect(p.target, (0.86 * 60).round());
      expect(p.min, p.target);
      expect(p.max, p.target);
    });
  });

  group('protein targets', () {
    test('training adult sits inside the 1.2-2.0 g/kg sports range', () {
      final p = Calculations.proteinTarget(
        data: data,
        profile: testProfile(weightKg: 70, goal: Goal.maintain),
        access: AccessLevel.full,
      );
      expect(p.min, greaterThanOrEqualTo((1.2 * 70).round()));
      expect(p.max, (2.0 * 70).round());
      expect(p.target, inInclusiveRange(p.min, p.max));
    });

    test('never below the ICMR-NIN adult RDA of 0.83 g/kg', () {
      final p = Calculations.proteinTarget(
        data: data,
        profile: testProfile(weightKg: 95),
        access: AccessLevel.full,
      );
      expect(p.target, greaterThanOrEqualTo((0.83 * 95).round()));
    });

    test('a deficit raises protein relative to maintenance', () {
      final lose = Calculations.proteinTarget(
        data: data,
        profile: testProfile(weightKg: 80, goal: Goal.lose),
        access: AccessLevel.full,
      );
      final maintain = Calculations.proteinTarget(
        data: data,
        profile: testProfile(weightKg: 80, goal: Goal.maintain),
        access: AccessLevel.full,
      );
      expect(lose.target, greaterThan(maintain.target));
    });
  });

  group('other daily targets', () {
    test('water target is the ICMR-NIN two litres', () {
      final t = Calculations.nutritionTargets(
        data: data,
        profile: testProfile(),
        access: AccessLevel.full,
      );
      expect(t.waterMl, 2000);
    });

    test('salt, sugar and visible fat limits come from the sources', () {
      final t = Calculations.nutritionTargets(
        data: data,
        profile: testProfile(
          sex: Sex.male,
          activityLevel: ActivityLevel.sedentary,
        ),
        access: AccessLevel.full,
      );
      expect(t.saltLimitG, 5);
      expect(t.addedSugarLimitG, 30);
      expect(t.visibleFatLimitG, 30); // sedentary adult man
      expect(t.fibreMinG, 25);
    });

    test(
      'macronutrient gram ranges follow the WHO percent-of-energy bands',
      () {
        final t = Calculations.nutritionTargets(
          data: data,
          profile: testProfile(),
          access: AccessLevel.full,
        );
        // Fat 15-30% of energy at 9 kcal/g.
        expect(t.fatMinG, closeTo(t.targetKcal * 0.15 / 9, 0.01));
        expect(t.fatMaxG, closeTo(t.targetKcal * 0.30 / 9, 0.01));
        // Carbohydrate 45-75% of energy at 4 kcal/g.
        expect(t.carbMinG, closeTo(t.targetKcal * 0.45 / 4, 0.01));
        expect(t.carbMaxG, closeTo(t.targetKcal * 0.75 / 4, 0.01));
      },
    );
  });

  group('weight trend and stall adjustment', () {
    WeighIn w(int daysAgo, double kg) => WeighIn(
      id: daysAgo,
      recordedAt: DateTime(2026, 3, 1).subtract(Duration(days: daysAgo)),
      weightKg: kg,
      newHealthProblem: false,
    );

    test('not enough check-ins yields no trend', () {
      final t = Calculations.weightTrend(
        weighIns: [w(0, 80), w(7, 80.2)],
        goal: Goal.lose,
      );
      expect(t.weeksObserved, 0);
      expect(t.stalled, isFalse);
    });

    test('flat weight on a lose goal is a stall', () {
      final t = Calculations.weightTrend(
        weighIns: [w(0, 80.0), w(7, 80.1), w(14, 80.0)],
        goal: Goal.lose,
      );
      expect(t.stalled, isTrue);
      expect(t.movingTowardsGoal, isFalse);
    });

    test('falling weight on a lose goal is progress', () {
      final t = Calculations.weightTrend(
        weighIns: [w(0, 78.5), w(7, 79.2), w(14, 80.0)],
        goal: Goal.lose,
      );
      expect(t.stalled, isFalse);
      expect(t.movingTowardsGoal, isTrue);
      expect(t.changeKg, closeTo(-1.5, 0.0001));
    });

    test('flat weight on a maintain goal is not a stall', () {
      final t = Calculations.weightTrend(
        weighIns: [w(0, 80.0), w(7, 80.1), w(14, 80.0)],
        goal: Goal.maintain,
      );
      expect(t.stalled, isFalse);
    });

    test(
      'a stall nudges calories by the published step, in the right direction',
      () {
        final stalledLose = Calculations.weightTrend(
          weighIns: [w(0, 80.0), w(7, 80.0), w(14, 80.0)],
          goal: Goal.lose,
        );
        expect(
          Calculations.stallAdjustment(
            data: data,
            trend: stalledLose,
            goal: Goal.lose,
          ),
          -100,
        );
        expect(
          Calculations.stallAdjustment(
            data: data,
            trend: stalledLose,
            goal: Goal.gain,
          ),
          100,
        );
      },
    );

    test('no stall means no adjustment', () {
      final moving = Calculations.weightTrend(
        weighIns: [w(0, 78.0), w(7, 79.0), w(14, 80.0)],
        goal: Goal.lose,
      );
      expect(
        Calculations.stallAdjustment(
          data: data,
          trend: moving,
          goal: Goal.lose,
        ),
        0,
      );
    });

    test('a paused diet freezes the stall nudge', () {
      final profile = testProfile(weightKg: 85, goal: Goal.lose);
      final applied = Calculations.nutritionTargets(
        data: data,
        profile: profile,
        access: AccessLevel.full,
        weightTrendAdjustmentKcal: -100,
      );
      final paused = Calculations.nutritionTargets(
        data: data,
        profile: profile,
        access: AccessLevel.full,
        weightTrendAdjustmentKcal: -100,
        dietChangesPaused: true,
      );
      expect(paused.targetKcal, greaterThan(applied.targetKcal));
    });
  });
}
