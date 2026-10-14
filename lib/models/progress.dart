/// A weekly weight check-in. Only ever created from a number the user typed.
class WeighIn {
  const WeighIn({
    required this.id,
    required this.recordedAt,
    required this.weightKg,
    required this.newHealthProblem,
    this.note,
  });

  final int id;
  final DateTime recordedAt;
  final double weightKg;

  /// Answer to "any new health problem or medication change?". A yes pauses
  /// automatic diet changes until the user clears it.
  final bool newHealthProblem;
  final String? note;

  Map<String, dynamic> toJson() => {
    'id': id,
    'recordedAt': recordedAt.toIso8601String(),
    'weightKg': weightKg,
    'newHealthProblem': newHealthProblem,
    'note': note,
  };

  static WeighIn fromJson(Map<String, dynamic> j) => WeighIn(
    id: (j['id'] as num?)?.toInt() ?? 0,
    recordedAt:
        DateTime.tryParse((j['recordedAt'] as String?) ?? '') ?? DateTime.now(),
    weightKg: (j['weightKg'] as num).toDouble(),
    newHealthProblem: j['newHealthProblem'] == true,
    note: j['note'] as String?,
  );
}

/// Body measurements in centimetres. Every field is optional: the app shows an
/// empty state rather than a zero for anything the user has not measured.
class BodyMeasurement {
  const BodyMeasurement({
    required this.id,
    required this.recordedAt,
    this.waistCm,
    this.chestCm,
    this.hipCm,
    this.armCm,
    this.thighCm,
    this.neckCm,
  });

  final int id;
  final DateTime recordedAt;
  final double? waistCm;
  final double? chestCm;
  final double? hipCm;
  final double? armCm;
  final double? thighCm;
  final double? neckCm;

  bool get isEmpty =>
      waistCm == null &&
      chestCm == null &&
      hipCm == null &&
      armCm == null &&
      thighCm == null &&
      neckCm == null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'recordedAt': recordedAt.toIso8601String(),
    'waistCm': waistCm,
    'chestCm': chestCm,
    'hipCm': hipCm,
    'armCm': armCm,
    'thighCm': thighCm,
    'neckCm': neckCm,
  };

  static BodyMeasurement fromJson(Map<String, dynamic> j) => BodyMeasurement(
    id: (j['id'] as num?)?.toInt() ?? 0,
    recordedAt:
        DateTime.tryParse((j['recordedAt'] as String?) ?? '') ?? DateTime.now(),
    waistCm: (j['waistCm'] as num?)?.toDouble(),
    chestCm: (j['chestCm'] as num?)?.toDouble(),
    hipCm: (j['hipCm'] as num?)?.toDouble(),
    armCm: (j['armCm'] as num?)?.toDouble(),
    thighCm: (j['thighCm'] as num?)?.toDouble(),
    neckCm: (j['neckCm'] as num?)?.toDouble(),
  );
}

/// A best-ever result for one exercise, derived entirely from logged sets.
class PersonalRecord {
  const PersonalRecord({
    required this.exerciseId,
    required this.exerciseName,
    required this.achievedAt,
    this.bestWeightKg,
    this.bestReps,
    this.bestSeconds,
    this.bestVolume,
  });

  final String exerciseId;
  final String exerciseName;
  final DateTime achievedAt;
  final double? bestWeightKg;
  final int? bestReps;
  final int? bestSeconds;
  final double? bestVolume;

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'exerciseName': exerciseName,
    'achievedAt': achievedAt.toIso8601String(),
    'bestWeightKg': bestWeightKg,
    'bestReps': bestReps,
    'bestSeconds': bestSeconds,
    'bestVolume': bestVolume,
  };
}

/// How weight is trending against the user's goal, used to decide whether the
/// calorie target needs adjusting.
class WeightTrend {
  const WeightTrend({
    required this.weeksObserved,
    required this.changeKg,
    required this.movingTowardsGoal,
    required this.stalled,
  });

  final int weeksObserved;
  final double changeKg;
  final bool movingTowardsGoal;

  /// True when at least two check-ins have passed with no movement towards the
  /// goal, which is the trigger for a calorie adjustment.
  final bool stalled;

  static const WeightTrend none = WeightTrend(
    weeksObserved: 0,
    changeKg: 0,
    movingTowardsGoal: false,
    stalled: false,
  );
}
