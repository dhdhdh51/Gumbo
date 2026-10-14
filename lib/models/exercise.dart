import 'enums.dart';

/// Default sets, reps and rest for one goal.
///
/// For a [Exercise.loadType] of `timed`, [repsMin] and [repsMax] are seconds
/// per set rather than repetitions.
class ExercisePrescription {
  const ExercisePrescription({
    required this.sets,
    required this.repsMin,
    required this.repsMax,
    required this.restSec,
  });

  final int sets;
  final int repsMin;
  final int repsMax;
  final int restSec;

  int get repsMid => ((repsMin + repsMax) / 2).round();

  ExercisePrescription copyWith({
    int? sets,
    int? repsMin,
    int? repsMax,
    int? restSec,
  }) => ExercisePrescription(
    sets: sets ?? this.sets,
    repsMin: repsMin ?? this.repsMin,
    repsMax: repsMax ?? this.repsMax,
    restSec: restSec ?? this.restSec,
  );

  Map<String, dynamic> toJson() => {
    'sets': sets,
    'repsMin': repsMin,
    'repsMax': repsMax,
    'restSec': restSec,
  };

  static ExercisePrescription fromJson(Map<String, dynamic> j) =>
      ExercisePrescription(
        sets: (j['sets'] as num).toInt(),
        repsMin: (j['repsMin'] as num).toInt(),
        repsMax: (j['repsMax'] as num).toInt(),
        restSec: (j['restSec'] as num).toInt(),
      );
}

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.primaryMuscles,
    required this.secondaryMuscles,
    required this.equipment,
    required this.equipmentDetail,
    required this.difficulty,
    required this.pattern,
    required this.isCompound,
    required this.loadType,
    required this.repUnit,
    required this.lowImpact,
    required this.defaults,
    required this.steps,
    required this.mistakes,
    required this.safety,
  });

  final String id;
  final String name;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;

  /// One of `bodyweight`, `home`, `gym`.
  final String equipment;
  final String equipmentDetail;
  final ExperienceLevel difficulty;

  /// Movement pattern, used to build balanced sessions.
  final String pattern;
  final bool isCompound;

  /// One of `external`, `bodyweight`, `timed`.
  final String loadType;

  /// Suitable for a lighter default intensity, including older beginners.
  final bool lowImpact;

  /// What the prescription numbers mean: `reps` or `seconds`.
  ///
  /// Independent of [loadType]. A farmer walk is externally loaded and measured
  /// in seconds; a push-up is unloaded and measured in reps.
  final String repUnit;

  final Map<Goal, ExercisePrescription> defaults;
  final List<String> steps;
  final List<String> mistakes;
  final List<String> safety;

  /// This app ships no exercise images or videos, so the media area is always
  /// hidden rather than filled with a placeholder.
  bool get hasMedia => false;

  /// True when sets are prescribed in seconds rather than repetitions.
  bool get isTimed => repUnit == 'seconds';

  /// Weight can be logged only for externally loaded movements.
  bool get tracksWeight => loadType == 'external';

  List<String> get allMuscles => [...primaryMuscles, ...secondaryMuscles];

  ExercisePrescription prescriptionFor(Goal goal) =>
      defaults[goal] ?? defaults[Goal.maintain]!;

  /// True when this exercise can be performed at [place].
  bool availableAt(TrainingPlace place) {
    if (place == TrainingPlace.gym) return true;
    return equipment != 'gym';
  }

  static Exercise fromJson(Map<String, dynamic> j) {
    final rawDefaults = (j['defaults'] as Map).cast<String, dynamic>();
    return Exercise(
      id: j['id'] as String,
      name: j['name'] as String,
      primaryMuscles:
          (j['primaryMuscles'] as List).map((e) => e as String).toList(),
      secondaryMuscles:
          (j['secondaryMuscles'] as List).map((e) => e as String).toList(),
      equipment: j['equipment'] as String,
      equipmentDetail: (j['equipmentDetail'] as String?) ?? '',
      difficulty: ExperienceLevel.fromName(j['difficulty'] as String),
      pattern: j['pattern'] as String,
      isCompound: j['isCompound'] == true,
      loadType: j['loadType'] as String,
      repUnit: (j['repUnit'] as String?) ?? 'reps',
      lowImpact: j['lowImpact'] == true,
      defaults: {
        for (final goal in Goal.values)
          if (rawDefaults[goal.name] != null)
            goal: ExercisePrescription.fromJson(
              (rawDefaults[goal.name] as Map).cast<String, dynamic>(),
            ),
      },
      steps: (j['steps'] as List).map((e) => e as String).toList(),
      mistakes: (j['mistakes'] as List).map((e) => e as String).toList(),
      safety: (j['safety'] as List).map((e) => e as String).toList(),
    );
  }
}
