import '../constants.dart';
import '../models/enums.dart';
import '../models/exercise.dart';
import '../models/workout.dart';

/// What to do for an exercise next time, and why.
class ProgressionSuggestion {
  const ProgressionSuggestion({
    required this.exerciseId,
    required this.reasonKey,
    this.weightKg,
    this.repsMin,
    this.repsMax,
    this.sets,
  });

  final String exerciseId;

  /// Localisation key explaining the change, for example `progressionTooEasy`.
  final String reasonKey;

  /// Next working weight, for externally loaded exercises.
  final double? weightKg;

  /// Next rep target, for bodyweight and timed exercises where load cannot
  /// simply be added.
  final int? repsMin;
  final int? repsMax;
  final int? sets;

  bool get changesWeight => weightKg != null;
}

/// Progressive overload driven by the feedback collected after each exercise.
///
/// The rules, in plain terms:
///   Too easy    -> add one plate step (2.5 kg), or one rep for bodyweight
///   Just right  -> add a rep until the top of the range, then add load
///   Too hard    -> cut the working weight by 5 to 10%
///   Deload week -> hold the movement, drop the load to 60%
///
/// Nothing is suggested until the user has actually logged the exercise once,
/// so the app never invents a starting weight.
class Progression {
  const Progression._();

  /// Suggest the next session for [exercise] from the last time it was done.
  static ProgressionSuggestion? suggest({
    required Exercise exercise,
    required ExerciseLog? lastLog,
    required ExercisePrescription prescription,
    bool isDeloadWeek = false,
  }) {
    if (lastLog == null || lastLog.skipped) return null;

    if (isDeloadWeek) {
      final last = lastLog.topWeightKg;
      return ProgressionSuggestion(
        exerciseId: exercise.id,
        reasonKey: 'progressionDeload',
        weightKg:
            last == null
                ? null
                : _round(last * ProgressionConfig.deloadLoadFactor),
        sets: (prescription.sets - 1).clamp(1, 10),
      );
    }

    final feedback = lastLog.feedback ?? SetFeedback.justRight;

    if (exercise.tracksWeight) {
      return _suggestForLoaded(
        exercise: exercise,
        lastLog: lastLog,
        prescription: prescription,
        feedback: feedback,
      );
    }
    return _suggestForUnloaded(
      exercise: exercise,
      lastLog: lastLog,
      prescription: prescription,
      feedback: feedback,
    );
  }

  /// Externally loaded exercises progress mainly by adding weight.
  static ProgressionSuggestion _suggestForLoaded({
    required Exercise exercise,
    required ExerciseLog lastLog,
    required ExercisePrescription prescription,
    required SetFeedback feedback,
  }) {
    final last = lastLog.topWeightKg;

    // No weight was ever recorded, so there is nothing to progress from.
    if (last == null || last <= 0) {
      return ProgressionSuggestion(
        exerciseId: exercise.id,
        reasonKey: switch (feedback) {
          SetFeedback.tooEasy => 'progressionTooEasyReps',
          SetFeedback.tooHard => 'progressionTooHardReps',
          SetFeedback.justRight => 'progressionHold',
        },
      );
    }

    switch (feedback) {
      case SetFeedback.tooEasy:
        return ProgressionSuggestion(
          exerciseId: exercise.id,
          reasonKey: 'progressionTooEasy',
          weightKg: _round(last + ProgressionConfig.barbellIncrementKg),
        );

      case SetFeedback.justRight:
        // Add a rep until the top of the prescribed range, then add load and
        // drop back to the bottom of the range.
        final topSetReps = _repsOnTopSet(lastLog);
        if (topSetReps != null && topSetReps >= prescription.repsMax) {
          return ProgressionSuggestion(
            exerciseId: exercise.id,
            reasonKey: 'progressionAddLoad',
            weightKg: _round(last + ProgressionConfig.barbellIncrementKg),
            repsMin: prescription.repsMin,
            repsMax: prescription.repsMax,
          );
        }
        return ProgressionSuggestion(
          exerciseId: exercise.id,
          reasonKey: 'progressionAddRep',
          weightKg: _round(last),
          repsMin: ((topSetReps ?? prescription.repsMin) + 1).clamp(
            prescription.repsMin,
            prescription.repsMax,
          ),
          repsMax: prescription.repsMax,
        );

      case SetFeedback.tooHard:
        // Cut by 5% when the user still completed the work, 10% when they did
        // not finish the prescribed sets.
        final finished = lastLog.completedSets >= prescription.sets;
        final cut =
            finished
                ? ProgressionConfig.tooHardReductionMin
                : ProgressionConfig.tooHardReductionMax;
        return ProgressionSuggestion(
          exerciseId: exercise.id,
          reasonKey: 'progressionTooHard',
          weightKg: _round(last * (1 - cut)),
        );
    }
  }

  /// Bodyweight and timed exercises progress by reps or seconds instead.
  static ProgressionSuggestion _suggestForUnloaded({
    required Exercise exercise,
    required ExerciseLog lastLog,
    required ExercisePrescription prescription,
    required SetFeedback feedback,
  }) {
    final lastReps = _repsOnTopSet(lastLog) ?? prescription.repsMin;

    switch (feedback) {
      case SetFeedback.tooEasy:
        final step = exercise.isTimed ? 5 : 1;
        return ProgressionSuggestion(
          exerciseId: exercise.id,
          reasonKey: 'progressionTooEasyReps',
          repsMin: lastReps + step,
          repsMax: (lastReps + step * 2).clamp(
            lastReps + step,
            prescription.repsMax + step * 4,
          ),
        );

      case SetFeedback.justRight:
        if (lastReps >= prescription.repsMax) {
          final step = exercise.isTimed ? 5 : 1;
          return ProgressionSuggestion(
            exerciseId: exercise.id,
            reasonKey: 'progressionAddRep',
            repsMin: lastReps + step,
            repsMax: prescription.repsMax + step,
          );
        }
        return ProgressionSuggestion(
          exerciseId: exercise.id,
          reasonKey: 'progressionAddRep',
          repsMin: (lastReps + 1).clamp(
            prescription.repsMin,
            prescription.repsMax,
          ),
          repsMax: prescription.repsMax,
        );

      case SetFeedback.tooHard:
        final step = exercise.isTimed ? 5 : 1;
        final reduced = (lastReps - step).clamp(1, prescription.repsMax);
        return ProgressionSuggestion(
          exerciseId: exercise.id,
          reasonKey: 'progressionTooHardReps',
          repsMin: reduced,
          repsMax: reduced + step,
        );
    }
  }

  /// Reps recorded on the heaviest completed set, which is the set that
  /// decides whether the rep target was met.
  static int? _repsOnTopSet(ExerciseLog log) {
    SetLog? best;
    for (final s in log.sets) {
      if (!s.completed) continue;
      final value = s.seconds ?? s.reps;
      if (value <= 0) continue;
      if (best == null) {
        best = s;
        continue;
      }
      final bw = best.weightKg ?? 0;
      final sw = s.weightKg ?? 0;
      if (sw > bw ||
          (sw == bw && (s.seconds ?? s.reps) > (best.seconds ?? best.reps))) {
        best = s;
      }
    }
    if (best == null) return null;
    return best.seconds ?? best.reps;
  }

  /// Apply a suggestion to a prescription, producing what the user will see.
  static ExercisePrescription applyTo(
    ExercisePrescription base,
    ProgressionSuggestion? suggestion,
  ) {
    if (suggestion == null) return base;
    return base.copyWith(
      sets: suggestion.sets,
      repsMin: suggestion.repsMin,
      repsMax:
          suggestion.repsMax == null
              ? null
              : (suggestion.repsMax! < (suggestion.repsMin ?? base.repsMin)
                  ? (suggestion.repsMin ?? base.repsMin)
                  : suggestion.repsMax),
    );
  }

  /// Round a weight to the smallest plate step the app assumes is available.
  static double _round(double kg) {
    const step = ProgressionConfig.barbellIncrementKg;
    final rounded = (kg / step).round() * step;
    return rounded < step ? step : rounded;
  }
}
