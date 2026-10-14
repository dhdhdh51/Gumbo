import 'enums.dart';
import 'exercise.dart';

/// One day of a generated training week.
class PlannedDay {
  const PlannedDay({
    required this.dayIndex,
    required this.isRest,
    required this.labelKey,
    required this.muscleGroups,
    required this.exercises,
    this.isDeload = false,
  });

  /// 0-based index within the rotation, not a weekday.
  final int dayIndex;
  final bool isRest;

  /// Localisation key for the session name, for example `splitChestTriceps`.
  final String labelKey;

  /// Muscle groups this session targets, used to pick exercises and to show
  /// "Today: Chest + Triceps".
  final List<String> muscleGroups;
  final List<PlannedExercise> exercises;
  final bool isDeload;

  int get totalSets => exercises.fold(0, (sum, e) => sum + e.prescription.sets);
}

/// An exercise inside a planned session, with the sets and reps to perform.
class PlannedExercise {
  const PlannedExercise({
    required this.exercise,
    required this.prescription,
    this.suggestedWeightKg,
    this.progressionReasonKey,
  });

  final Exercise exercise;
  final ExercisePrescription prescription;

  /// Carried forward from history by the progression engine. Null when the
  /// user has never logged this exercise, in which case the app asks rather
  /// than inventing a starting weight.
  final double? suggestedWeightKg;

  /// Localisation key explaining why the suggestion changed, for example
  /// `progressionTooEasy`.
  final String? progressionReasonKey;

  PlannedExercise copyWith({
    ExercisePrescription? prescription,
    double? suggestedWeightKg,
    String? progressionReasonKey,
  }) => PlannedExercise(
    exercise: exercise,
    prescription: prescription ?? this.prescription,
    suggestedWeightKg: suggestedWeightKg ?? this.suggestedWeightKg,
    progressionReasonKey: progressionReasonKey ?? this.progressionReasonKey,
  );
}

/// A full week of planned days.
class WeeklyPlan {
  const WeeklyPlan({
    required this.split,
    required this.daysPerWeek,
    required this.days,
    required this.weekNumber,
    required this.isDeloadWeek,
  });

  final SplitType split;
  final int daysPerWeek;

  /// Always seven entries, one per day of the rotation.
  final List<PlannedDay> days;

  /// 1-based training week since the plan start date.
  final int weekNumber;
  final bool isDeloadWeek;

  PlannedDay dayAt(int index) => days[index % days.length];
}

/// A logged set.
class SetLog {
  const SetLog({
    required this.setNumber,
    required this.reps,
    this.weightKg,
    this.seconds,
    this.completed = true,
  });

  final int setNumber;
  final int reps;
  final double? weightKg;

  /// Used instead of reps for timed exercises.
  final int? seconds;
  final bool completed;

  /// Simple volume measure in kg-reps, used for personal records.
  double get volume => (weightKg ?? 0) * reps;

  Map<String, dynamic> toJson() => {
    'setNumber': setNumber,
    'reps': reps,
    'weightKg': weightKg,
    'seconds': seconds,
    'completed': completed,
  };

  static SetLog fromJson(Map<String, dynamic> j) => SetLog(
    setNumber: (j['setNumber'] as num).toInt(),
    reps: (j['reps'] as num).toInt(),
    weightKg: (j['weightKg'] as num?)?.toDouble(),
    seconds: (j['seconds'] as num?)?.toInt(),
    completed: j['completed'] != false,
  );
}

/// Everything recorded for one exercise inside a session.
class ExerciseLog {
  const ExerciseLog({
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
    this.feedback,
    this.skipped = false,
    this.replacedExerciseId,
  });

  final String exerciseId;
  final String exerciseName;
  final List<SetLog> sets;

  /// Collected after every exercise and used to drive progressive overload.
  final SetFeedback? feedback;
  final bool skipped;

  /// Set when the user swapped this exercise in for another one.
  final String? replacedExerciseId;

  int get completedSets => sets.where((s) => s.completed).length;

  double get totalVolume => sets.fold(0.0, (sum, s) => sum + s.volume);

  /// Heaviest weight used on a completed set, or null if never loaded.
  double? get topWeightKg {
    double? best;
    for (final s in sets) {
      final w = s.weightKg;
      if (!s.completed || w == null) continue;
      if (best == null || w > best) best = w;
    }
    return best;
  }

  ExerciseLog copyWith({
    List<SetLog>? sets,
    SetFeedback? feedback,
    bool? skipped,
    String? replacedExerciseId,
  }) => ExerciseLog(
    exerciseId: exerciseId,
    exerciseName: exerciseName,
    sets: sets ?? this.sets,
    feedback: feedback ?? this.feedback,
    skipped: skipped ?? this.skipped,
    replacedExerciseId: replacedExerciseId ?? this.replacedExerciseId,
  );

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'exerciseName': exerciseName,
    'sets': sets.map((s) => s.toJson()).toList(),
    'feedback': feedback?.name,
    'skipped': skipped,
    'replacedExerciseId': replacedExerciseId,
  };

  static ExerciseLog fromJson(Map<String, dynamic> j) => ExerciseLog(
    exerciseId: j['exerciseId'] as String,
    exerciseName: (j['exerciseName'] as String?) ?? '',
    sets:
        ((j['sets'] as List?) ?? [])
            .map((e) => SetLog.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
    feedback:
        j['feedback'] == null
            ? null
            : SetFeedback.fromName(j['feedback'] as String),
    skipped: j['skipped'] == true,
    replacedExerciseId: j['replacedExerciseId'] as String?,
  );
}

/// A completed or in-progress workout session.
class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.startedAt,
    required this.labelKey,
    required this.muscleGroups,
    required this.logs,
    this.finishedAt,
    this.isLightSession = false,
    this.isDeload = false,
    this.preCheckNote,
  });

  final int id;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final String labelKey;
  final List<String> muscleGroups;
  final List<ExerciseLog> logs;

  /// True when the session was the reduced "light activity only" option after
  /// the user reported a problem in the pre-workout check.
  final bool isLightSession;
  final bool isDeload;
  final String? preCheckNote;

  bool get isFinished => finishedAt != null;

  Duration get duration => (finishedAt ?? DateTime.now()).difference(startedAt);

  int get totalSets => logs.fold(0, (s, l) => s + l.completedSets);

  double get totalVolume => logs.fold(0.0, (s, l) => s + l.totalVolume);

  Map<String, dynamic> toJson() => {
    'id': id,
    'startedAt': startedAt.toIso8601String(),
    'finishedAt': finishedAt?.toIso8601String(),
    'labelKey': labelKey,
    'muscleGroups': muscleGroups,
    'logs': logs.map((l) => l.toJson()).toList(),
    'isLightSession': isLightSession,
    'isDeload': isDeload,
    'preCheckNote': preCheckNote,
  };

  static WorkoutSession fromJson(Map<String, dynamic> j) => WorkoutSession(
    id: (j['id'] as num?)?.toInt() ?? 0,
    startedAt:
        DateTime.tryParse((j['startedAt'] as String?) ?? '') ?? DateTime.now(),
    finishedAt: DateTime.tryParse((j['finishedAt'] as String?) ?? ''),
    labelKey: (j['labelKey'] as String?) ?? '',
    muscleGroups:
        ((j['muscleGroups'] as List?) ?? []).map((e) => e.toString()).toList(),
    logs:
        ((j['logs'] as List?) ?? [])
            .map(
              (e) => ExerciseLog.fromJson((e as Map).cast<String, dynamic>()),
            )
            .toList(),
    isLightSession: j['isLightSession'] == true,
    isDeload: j['isDeload'] == true,
    preCheckNote: j['preCheckNote'] as String?,
  );
}

/// Result of the pre-workout health check, recorded for every attempt.
class PreWorkoutCheck {
  const PreWorkoutCheck({
    required this.answeredAt,
    required this.hasProblem,
    required this.redFlags,
    required this.outcome,
    this.note,
  });

  final DateTime answeredAt;
  final bool hasProblem;
  final List<String> redFlags;
  final PreWorkoutOutcome outcome;
  final String? note;

  Map<String, dynamic> toJson() => {
    'answeredAt': answeredAt.toIso8601String(),
    'hasProblem': hasProblem,
    'redFlags': redFlags,
    'outcome': outcome.name,
    'note': note,
  };

  static PreWorkoutCheck fromJson(Map<String, dynamic> j) => PreWorkoutCheck(
    answeredAt:
        DateTime.tryParse((j['answeredAt'] as String?) ?? '') ?? DateTime.now(),
    hasProblem: j['hasProblem'] == true,
    redFlags:
        ((j['redFlags'] as List?) ?? []).map((e) => e.toString()).toList(),
    outcome: PreWorkoutOutcome.values.firstWhere(
      (e) => e.name == j['outcome'],
      orElse: () => PreWorkoutOutcome.proceedNormal,
    ),
    note: j['note'] as String?,
  );
}
