import 'enums.dart';

/// Why a calorie target ended up where it did.
///
/// Every clamp that fired is recorded so the Diet screen can explain the number
/// honestly instead of presenting it as a black box.
enum TargetClamp {
  /// Target was raised to the Mifflin-St Jeor resting energy expenditure.
  bmrFloor,

  /// Target was raised to the ICMR-NIN 1000 kcal weight-reduction floor.
  icmrFloor,

  /// Deficit was capped at 40% of estimated needs, per ICMR-NIN.
  maxDeficit,

  /// Weekly loss was capped at half a kilogram per week, per ICMR-NIN.
  maxWeeklyLoss,

  /// Weight-loss goal refused because BMI is below 18.5.
  underweightNoLoss,

  /// No deficit applied because the user is under 18.
  minorNoDeficit,
}

/// The daily nutrition target the app will hold the user to.
class NutritionTargets {
  const NutritionTargets({
    required this.bmrKcal,
    required this.maintenanceKcal,
    required this.targetKcal,
    required this.proteinG,
    required this.proteinMinG,
    required this.proteinMaxG,
    required this.waterMl,
    required this.clamps,
    required this.goalApplied,
    this.icmrReferenceKcal,
    this.fatMinG,
    this.fatMaxG,
    this.carbMinG,
    this.carbMaxG,
    this.visibleFatLimitG,
    this.addedSugarLimitG,
    this.saltLimitG,
    this.fibreMinG,
    this.weeklyChangeKg,
  });

  /// Resting energy expenditure from the Mifflin-St Jeor equation.
  final double bmrKcal;

  /// Maintenance estimate: BMR multiplied by the physical activity level.
  final double maintenanceKcal;

  /// Final daily calorie target after goal adjustment and all safe limits.
  final int targetKcal;

  /// Published ICMR-NIN reference for this sex and activity level, shown beside
  /// the computed figure as a cross-check. Null outside the adult tables.
  final int? icmrReferenceKcal;

  final int proteinG;
  final int proteinMinG;
  final int proteinMaxG;
  final int waterMl;

  final double? fatMinG;
  final double? fatMaxG;
  final double? carbMinG;
  final double? carbMaxG;
  final double? visibleFatLimitG;
  final double? addedSugarLimitG;
  final double? saltLimitG;
  final double? fibreMinG;

  /// Expected weekly weight change in kg at this target. Negative for loss.
  final double? weeklyChangeKg;

  /// Which safe limits actually changed the number.
  final List<TargetClamp> clamps;

  /// The goal the app was able to honour, which may differ from the requested
  /// goal when a safety rule blocked it.
  final Goal goalApplied;

  bool get wasClamped => clamps.isNotEmpty;

  bool hasClamp(TargetClamp c) => clamps.contains(c);

  Map<String, dynamic> toJson() => {
    'bmrKcal': bmrKcal,
    'maintenanceKcal': maintenanceKcal,
    'targetKcal': targetKcal,
    'icmrReferenceKcal': icmrReferenceKcal,
    'proteinG': proteinG,
    'proteinMinG': proteinMinG,
    'proteinMaxG': proteinMaxG,
    'waterMl': waterMl,
    'fatMinG': fatMinG,
    'fatMaxG': fatMaxG,
    'carbMinG': carbMinG,
    'carbMaxG': carbMaxG,
    'visibleFatLimitG': visibleFatLimitG,
    'addedSugarLimitG': addedSugarLimitG,
    'saltLimitG': saltLimitG,
    'fibreMinG': fibreMinG,
    'weeklyChangeKg': weeklyChangeKg,
    'clamps': clamps.map((c) => c.name).toList(),
    'goalApplied': goalApplied.name,
  };
}

/// Weekly activity target for the user's age band, taken from WHO 2020.
class ActivityTargets {
  const ActivityTargets({
    required this.bandId,
    required this.bandLabel,
    required this.aerobicMinutesPerWeek,
    required this.strengthDaysPerWeek,
    required this.sourceId,
    this.aerobicMinutesPerWeekMax,
    this.balanceDaysPerWeek,
  });

  final String bandId;
  final String bandLabel;
  final int aerobicMinutesPerWeek;
  final int? aerobicMinutesPerWeekMax;
  final int strengthDaysPerWeek;
  final int? balanceDaysPerWeek;
  final String sourceId;
}
