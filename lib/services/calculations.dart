import 'dart:math' as math;

import '../models/enums.dart';
import '../models/guideline_data.dart';
import '../models/profile.dart';
import '../models/progress.dart';
import '../models/targets.dart';

/// Pure nutrition and energy maths. No Flutter, no I/O, no state.
///
/// Reading order for the calorie target:
///   1. [bmr]            resting energy expenditure, Mifflin-St Jeor
///   2. [maintenance]    BMR multiplied by the physical activity level
///   3. [nutritionTargets] applies the goal, then every safe limit in turn
///
/// Each safe limit records a [TargetClamp] so the Diet screen can tell the user
/// exactly which rule changed their number, and cite it.
class Calculations {
  const Calculations._();

  // -------------------------------------------------------------- BMR / TDEE

  /// Resting energy expenditure in kcal/day, Mifflin-St Jeor (1990).
  ///
  /// Male:   10*kg + 6.25*cm - 5*age + 5
  /// Female: 10*kg + 6.25*cm - 5*age - 161
  static double bmr({
    required Sex sex,
    required double weightKg,
    required double heightCm,
    required int ageYears,
  }) {
    final base = 10 * weightKg + 6.25 * heightCm - 5 * ageYears;
    return sex == Sex.male ? base + 5 : base - 161;
  }

  /// Maintenance calories: BMR multiplied by the physical activity level.
  ///
  /// The sedentary PAL of 1.40 is published by ICMR-NIN (2020). The moderate
  /// and heavy PALs are scaled from it using ICMR-NIN's own published kcal/kg
  /// figures, and are flagged as derived wherever the app shows them.
  static double maintenance({
    required GuidelineData data,
    required Sex sex,
    required ActivityLevel level,
    required double bmrKcal,
  }) {
    final pal = data.activityEnergy[level]?.forSex(sex).pal ?? 1.4;
    return bmrKcal * pal;
  }

  /// The published ICMR-NIN daily energy figure for this sex and activity
  /// level, scaled to the user's actual body weight using the published
  /// kcal/kg/day value. Shown beside the computed target as a cross-check.
  static int? icmrReference({
    required GuidelineData data,
    required Sex sex,
    required ActivityLevel level,
    required double weightKg,
  }) {
    final e = data.activityEnergy[level]?.forSex(sex);
    if (e == null) return null;
    return (e.kcalPerKgPerDay * weightKg).round();
  }

  // -------------------------------------------------------------------- BMI

  static double? bmi({required double weightKg, required double heightCm}) {
    if (heightCm <= 50 || weightKg <= 0) return null;
    final m = heightCm / 100.0;
    return weightKg / (m * m);
  }

  /// True when a Lose goal must be refused because the user is already below
  /// the lower end of the normal BMI range for Indian adults (18.5).
  static bool weightLossBlockedByBmi({
    required GuidelineData data,
    required double weightKg,
    required double heightCm,
  }) {
    final value = bmi(weightKg: weightKg, heightCm: heightCm);
    if (value == null) return false;
    final floor = data.weightSafety['minBmiForWeightLossGoal']?.value ?? 18.5;
    return value < floor;
  }

  // ------------------------------------------------------------- safe limits

  /// Largest weekly loss the app will aim for, in kg.
  ///
  /// ICMR-NIN gives half a kilogram per week as safe. An additional app guard
  /// keeps that below 1% of current body weight, which only matters for lighter
  /// users, for whom half a kilogram is a larger share of body weight.
  static double maxWeeklyLossKg({
    required GuidelineData data,
    required double weightKg,
  }) {
    final absolute = data.weightSafety['maxLossKgPerWeek']?.value ?? 0.5;
    final percent =
        data.weightSafety['maxLossPercentBodyWeightPerWeek']?.value ?? 1.0;
    final percentCap = weightKg * percent / 100.0;
    return math.min(absolute, percentCap);
  }

  /// Lowest daily calorie target the app will ever set.
  ///
  /// The higher of the user's own resting energy expenditure and the ICMR-NIN
  /// floor of 1000 kcal/day for weight-reduction diets.
  static double calorieFloor({
    required GuidelineData data,
    required double bmrKcal,
  }) {
    final icmr = data.calorieSafety['weightReductionFloorKcal']?.value ?? 1000;
    return math.max(bmrKcal, icmr);
  }

  // -------------------------------------------------------------- protein

  /// Protein target in grams per day, with the range the app considers safe.
  ///
  /// For training adults the target sits inside the sports-nutrition range of
  /// 1.2 to 2.0 g/kg/day. The ICMR-NIN RDA of 0.83 g/kg/day is the floor: the
  /// target is never allowed below it. For under-18s the ICMR-NIN adolescent
  /// RDA is used directly and the sports range is not applied, because those
  /// higher intakes are stated for training adults.
  static ({int target, int min, int max}) proteinTarget({
    required GuidelineData data,
    required UserProfile profile,
    required AccessLevel access,
  }) {
    final weight = profile.weightKg;

    if (access == AccessLevel.activityOnly) {
      // Under 18: use the published adolescent RDA for this age and sex.
      final row =
          data.adolescentProtein
              .where((p) => p.matches(profile.age, profile.sex))
              .firstOrNull;
      final gPerKg = row?.rdaGPerKg ?? 0.86;
      final target = (gPerKg * weight).round();
      return (target: target, min: target, max: target);
    }

    final adult =
        data.adultProtein.where((p) => p.sex == profile.sex).firstOrNull ??
        data.adultProtein.first;
    final rdaFloorG = adult.rdaGPerKg * weight;

    final range = data.trainingProteinRange;
    final minG = math.max(rdaFloorG, range.min * weight);
    final maxG = range.max * weight;

    // Within the sports-nutrition range, lean higher when the user is in a
    // deficit, because ICMR-NIN notes that more protein helps preserve muscle
    // during an energy-deficient diet, and higher again when gaining.
    final double factor = switch (profile.goal) {
      Goal.lose => 0.80,
      Goal.gain => 0.65,
      Goal.maintain => 0.45,
    };
    final target = minG + (maxG - minG) * factor;

    return (target: target.round(), min: minG.round(), max: maxG.round());
  }

  // ------------------------------------------------------------ full targets

  /// Build the complete daily target set for a profile.
  ///
  /// [weightTrendAdjustmentKcal] is the accumulated nudge from stalled weekly
  /// check-ins. [dietChangesPaused] freezes that nudge at zero, which is what
  /// happens after the user reports a new health problem at a check-in.
  static NutritionTargets nutritionTargets({
    required GuidelineData data,
    required UserProfile profile,
    required AccessLevel access,
    double weightTrendAdjustmentKcal = 0,
    bool dietChangesPaused = false,
    bool medicalClearance = true,
  }) {
    final clamps = <TargetClamp>[];

    final bmrKcal = bmr(
      sex: profile.sex,
      weightKg: profile.weightKg,
      heightCm: profile.heightCm,
      ageYears: profile.age,
    );
    final maintenanceKcal = maintenance(
      data: data,
      sex: profile.sex,
      level: profile.activityLevel,
      bmrKcal: bmrKcal,
    );

    // ---- decide which goal we are actually allowed to pursue
    var goal = profile.goal;

    if (goal == Goal.lose) {
      if (!access.allowsCalorieDeficit) {
        goal = Goal.maintain;
        clamps.add(TargetClamp.minorNoDeficit);
      } else if (weightLossBlockedByBmi(
        data: data,
        weightKg: profile.weightKg,
        heightCm: profile.heightCm,
      )) {
        goal = Goal.maintain;
        clamps.add(TargetClamp.underweightNoLoss);
      } else if (!medicalClearance) {
        // A serious screening answer without confirmed clearance blocks a
        // deficit, but maintenance eating is still fine.
        goal = Goal.maintain;
      }
    }

    // ---- apply the goal
    final surplus = data.calorieSafety['defaultGainSurplusKcal']?.value ?? 300;
    final deficit = data.calorieSafety['defaultLoseDeficitKcal']?.value ?? 400;

    double target = switch (goal) {
      Goal.gain => maintenanceKcal + surplus,
      Goal.lose => maintenanceKcal - deficit,
      Goal.maintain => maintenanceKcal,
    };

    // ---- stalled-progress nudge, unless diet changes are paused
    if (!dietChangesPaused && goal != Goal.maintain) {
      target += weightTrendAdjustmentKcal;
    }

    // ---- safe limits
    //
    // Each bound is computed first, then applied to the rounded integer at the
    // end. Clamping the integer rather than the double matters: rounding a
    // double that sits exactly on a bound can push the stored target half a
    // kilocalorie past a safety limit, and a limit that can be exceeded at all
    // is not a limit.

    // Deficit capped at 40% of estimated needs (ICMR-NIN).
    final maxDeficitPct =
        data.calorieSafety['maxDeficitPercentOfNeeds']?.value ?? 40;
    final deficitFloor = maintenanceKcal * (1 - maxDeficitPct / 100.0);

    // Implied weekly weight change capped at the published safe rate. A
    // kilogram of body tissue is treated as 7700 kcal for this conversion.
    final maxLoss = maxWeeklyLossKg(data: data, weightKg: profile.weightKg);
    final lossFloor = maintenanceKcal - maxLoss * _kcalPerKgBodyWeight / 7.0;

    final maxGain = data.weightSafety['maxGainKgPerWeek']?.value ?? 0.5;
    final gainCeiling = maintenanceKcal + maxGain * _kcalPerKgBodyWeight / 7.0;

    final icmrFloor =
        data.calorieSafety['weightReductionFloorKcal']?.value ?? 1000;

    var targetKcal = target.round();

    if (goal == Goal.lose) {
      if (targetKcal < deficitFloor) {
        targetKcal = deficitFloor.ceil();
        clamps.add(TargetClamp.maxDeficit);
      }
      if (targetKcal < lossFloor) {
        targetKcal = lossFloor.ceil();
        clamps.add(TargetClamp.maxWeeklyLoss);
      }
    }

    if (goal == Goal.gain && targetKcal > gainCeiling) {
      targetKcal = gainCeiling.floor();
    }

    // Absolute floors always win, whatever the goal.
    if (targetKcal < bmrKcal) {
      targetKcal = bmrKcal.ceil();
      clamps.add(TargetClamp.bmrFloor);
    }
    if (targetKcal < icmrFloor) {
      targetKcal = icmrFloor.ceil();
      clamps.add(TargetClamp.icmrFloor);
    }

    // ---- protein
    final protein = proteinTarget(
      data: data,
      profile: profile.copyWith(goal: goal),
      access: access,
    );

    // ---- macronutrient ranges from the WHO percent-of-energy bands
    double? gramsFrom(String id, String key, double kcalPerGram) {
      final t = data.dietTargetById(id);
      final pct = t?[key];
      if (pct == null) return null;
      return targetKcal * (pct / 100.0) / kcalPerGram;
    }

    // ---- water
    final waterTarget = data.dietTargetById('water');
    final waterMl = (waterTarget?['millilitresPerDay'] ?? 2000).toInt();

    // ---- visible fat limit for this sex and activity level
    double? visibleFat;
    final visible =
        data.dietLimits.where((l) => l.id == 'visible_fat').firstOrNull;
    if (visible != null) {
      // byGroup is not numeric so it is not in DietTarget.values; fall back to
      // the published overall band when the group row is unavailable.
      visibleFat = _visibleFatFor(profile.sex, profile.activityLevel);
    }

    final addedSugar =
        data.dietLimits.where((l) => l.id == 'added_sugar_india').firstOrNull;
    final salt = data.dietLimits.where((l) => l.id == 'salt').firstOrNull;
    final fibre = data.dietTargetById('dietary_fibre');

    // ---- expected weekly change at this target
    final dailyDelta = targetKcal - maintenanceKcal;
    final weeklyChangeKg = dailyDelta * 7 / _kcalPerKgBodyWeight;

    return NutritionTargets(
      bmrKcal: bmrKcal,
      maintenanceKcal: maintenanceKcal,
      targetKcal: targetKcal,
      icmrReferenceKcal: icmrReference(
        data: data,
        sex: profile.sex,
        level: profile.activityLevel,
        weightKg: profile.weightKg,
      ),
      proteinG: protein.target,
      proteinMinG: protein.min,
      proteinMaxG: protein.max,
      waterMl: waterMl,
      fatMinG: gramsFrom('fat_percent_energy', 'minPercentEnergy', 9),
      fatMaxG: gramsFrom('fat_percent_energy', 'maxPercentEnergy', 9),
      carbMinG: gramsFrom('carbohydrate_percent_energy', 'minPercentEnergy', 4),
      carbMaxG: gramsFrom('carbohydrate_percent_energy', 'maxPercentEnergy', 4),
      visibleFatLimitG: visibleFat,
      addedSugarLimitG: addedSugar?['maxGramsPerDayMax']?.toDouble(),
      saltLimitG: salt?['maxGramsPerDay']?.toDouble(),
      fibreMinG: fibre?['minGramsPerDay']?.toDouble(),
      weeklyChangeKg: weeklyChangeKg,
      clamps: clamps,
      goalApplied: goal,
    );
  }

  /// ICMR-NIN visible fat allowance in g/day by sex and activity level.
  static double _visibleFatFor(Sex sex, ActivityLevel level) {
    if (sex == Sex.male) {
      return switch (level) {
        ActivityLevel.sedentary => 30,
        ActivityLevel.moderate => 40,
        ActivityLevel.heavy => 50,
      };
    }
    return switch (level) {
      ActivityLevel.sedentary => 20,
      ActivityLevel.moderate => 30,
      ActivityLevel.heavy => 40,
    };
  }

  /// Energy content of a kilogram of body tissue, used to convert between a
  /// daily calorie delta and an expected weekly weight change.
  static const double _kcalPerKgBodyWeight = 7700;

  // --------------------------------------------------------- weight trend

  /// Decide whether weight is moving towards the goal.
  ///
  /// [weighIns] must be newest-first. A stall is two or more check-ins with no
  /// movement towards the goal, which is the trigger to nudge calories.
  static WeightTrend weightTrend({
    required List<WeighIn> weighIns,
    required Goal goal,
    int weeksRequired = 2,
  }) {
    if (weighIns.length < weeksRequired + 1) return WeightTrend.none;

    final latest = weighIns.first;
    final baseline = weighIns[weeksRequired];
    final change = latest.weightKg - baseline.weightKg;

    // A small band around zero counts as "no movement", so normal daily noise
    // does not look like progress.
    const noiseKg = 0.3;

    final moving = switch (goal) {
      Goal.lose => change <= -noiseKg,
      Goal.gain => change >= noiseKg,
      Goal.maintain => change.abs() < 1.0,
    };

    return WeightTrend(
      weeksObserved: weeksRequired,
      changeKg: change,
      movingTowardsGoal: moving,
      stalled: goal != Goal.maintain && !moving,
    );
  }

  /// Calorie nudge to apply when progress has stalled.
  ///
  /// Negative for a Lose goal (eat a little less), positive for Gain.
  /// Returns zero when nothing should change.
  static double stallAdjustment({
    required GuidelineData data,
    required WeightTrend trend,
    required Goal goal,
  }) {
    if (!trend.stalled) return 0;
    final step = data.stallAdjustment.min;
    return switch (goal) {
      Goal.lose => -step,
      Goal.gain => step,
      Goal.maintain => 0,
    };
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
