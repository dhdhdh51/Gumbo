import 'package:flutter_test/flutter_test.dart';
import 'package:trainerapp/models/enums.dart';
import 'package:trainerapp/models/exercise.dart';
import 'package:trainerapp/models/workout.dart';
import 'package:trainerapp/services/progression.dart';

import 'support/test_data.dart';

void main() {
  final data = loadGuidelineData();

  final bench = data.exerciseById('barbell_bench_press')!;
  final pushUp = data.exerciseById('push_up')!;
  final plank = data.exerciseById('plank')!;

  ExerciseLog log(
    Exercise ex, {
    required SetFeedback feedback,
    double? weight,
    int reps = 8,
    int sets = 3,
    int? seconds,
    bool allCompleted = true,
  }) => ExerciseLog(
    exerciseId: ex.id,
    exerciseName: ex.name,
    feedback: feedback,
    sets: [
      for (var i = 1; i <= sets; i++)
        SetLog(
          setNumber: i,
          reps: reps,
          weightKg: weight,
          seconds: seconds,
          completed: allCompleted || i < sets,
        ),
    ],
  );

  group('loaded exercises', () {
    final prescription = bench.prescriptionFor(Goal.gain); // 4 x 6-10

    test('too easy adds one plate step of 2.5 kg', () {
      final s =
          Progression.suggest(
            exercise: bench,
            lastLog: log(
              bench,
              feedback: SetFeedback.tooEasy,
              weight: 60,
              reps: 8,
            ),
            prescription: prescription,
          )!;
      expect(s.weightKg, 62.5);
      expect(s.reasonKey, 'progressionTooEasy');
    });

    test('just right below the top of the range adds a rep, not load', () {
      final s =
          Progression.suggest(
            exercise: bench,
            lastLog: log(
              bench,
              feedback: SetFeedback.justRight,
              weight: 60,
              reps: 8,
            ),
            prescription: prescription,
          )!;
      expect(s.weightKg, 60.0);
      expect(s.repsMin, 9);
      expect(s.reasonKey, 'progressionAddRep');
    });

    test('just right at the top of the range adds load and resets reps', () {
      final s =
          Progression.suggest(
            exercise: bench,
            lastLog: log(
              bench,
              feedback: SetFeedback.justRight,
              weight: 60,
              reps: 10,
            ),
            prescription: prescription,
          )!;
      expect(s.weightKg, 62.5);
      expect(s.repsMin, prescription.repsMin);
      expect(s.reasonKey, 'progressionAddLoad');
    });

    test('too hard after completing all sets cuts 5%', () {
      final s =
          Progression.suggest(
            exercise: bench,
            lastLog: log(
              bench,
              feedback: SetFeedback.tooHard,
              weight: 100,
              reps: 6,
              sets: prescription.sets,
            ),
            prescription: prescription,
          )!;
      // 100 kg minus 5% is 95 kg, already on a plate step.
      expect(s.weightKg, 95.0);
      expect(s.reasonKey, 'progressionTooHard');
    });

    test('too hard with unfinished sets cuts the full 10%', () {
      final s =
          Progression.suggest(
            exercise: bench,
            lastLog: log(
              bench,
              feedback: SetFeedback.tooHard,
              weight: 100,
              reps: 6,
              sets: 4,
              allCompleted: false,
            ),
            prescription: prescription,
          )!;
      // 100 kg minus 10% is 90 kg.
      expect(s.weightKg, 90.0);
    });

    test('suggestions always land on a 2.5 kg plate step', () {
      for (final w in [21.0, 37.5, 48.0, 63.3, 87.7]) {
        final s =
            Progression.suggest(
              exercise: bench,
              lastLog: log(bench, feedback: SetFeedback.tooHard, weight: w),
              prescription: prescription,
            )!;
        expect((s.weightKg! / 2.5) % 1, 0, reason: 'from $w kg');
      }
    });

    test('a suggestion is never below one plate step', () {
      final s =
          Progression.suggest(
            exercise: bench,
            lastLog: log(bench, feedback: SetFeedback.tooHard, weight: 2.5),
            prescription: prescription,
          )!;
      expect(s.weightKg, greaterThanOrEqualTo(2.5));
    });

    test('no weight logged means no weight suggested', () {
      final s =
          Progression.suggest(
            exercise: bench,
            lastLog: log(bench, feedback: SetFeedback.tooEasy, weight: null),
            prescription: prescription,
          )!;
      expect(s.weightKg, isNull);
      expect(s.changesWeight, isFalse);
    });

    test('the heaviest completed set drives the next suggestion', () {
      final mixed = ExerciseLog(
        exerciseId: bench.id,
        exerciseName: bench.name,
        feedback: SetFeedback.tooEasy,
        sets: const [
          SetLog(setNumber: 1, reps: 10, weightKg: 50),
          SetLog(setNumber: 2, reps: 8, weightKg: 70),
          // Not completed, so it must be ignored.
          SetLog(setNumber: 3, reps: 2, weightKg: 90, completed: false),
        ],
      );
      final s =
          Progression.suggest(
            exercise: bench,
            lastLog: mixed,
            prescription: prescription,
          )!;
      expect(s.weightKg, 72.5);
    });
  });

  group('bodyweight and timed exercises', () {
    test('a bodyweight exercise progresses by reps, never by weight', () {
      final s =
          Progression.suggest(
            exercise: pushUp,
            lastLog: log(pushUp, feedback: SetFeedback.tooEasy, reps: 12),
            prescription: pushUp.prescriptionFor(Goal.maintain),
          )!;
      expect(s.weightKg, isNull);
      expect(s.repsMin, 13); // one more rep
      expect(s.reasonKey, 'progressionTooEasyReps');
    });

    test('a timed exercise progresses in 5 second steps', () {
      final s =
          Progression.suggest(
            exercise: plank,
            lastLog: log(
              plank,
              feedback: SetFeedback.tooEasy,
              reps: 0,
              seconds: 40,
            ),
            prescription: plank.prescriptionFor(Goal.maintain),
          )!;
      expect(s.repsMin, 45);
    });

    test('too hard on a bodyweight exercise reduces the rep target', () {
      final s =
          Progression.suggest(
            exercise: pushUp,
            lastLog: log(pushUp, feedback: SetFeedback.tooHard, reps: 10),
            prescription: pushUp.prescriptionFor(Goal.maintain),
          )!;
      expect(s.repsMin, 9);
      expect(s.reasonKey, 'progressionTooHardReps');
    });

    test('a rep target never drops below one', () {
      final s =
          Progression.suggest(
            exercise: pushUp,
            lastLog: log(pushUp, feedback: SetFeedback.tooHard, reps: 1),
            prescription: pushUp.prescriptionFor(Goal.maintain),
          )!;
      expect(s.repsMin, greaterThanOrEqualTo(1));
    });
  });

  group('no history and skipped work', () {
    test('an exercise never logged gets no suggestion at all', () {
      expect(
        Progression.suggest(
          exercise: bench,
          lastLog: null,
          prescription: bench.prescriptionFor(Goal.gain),
        ),
        isNull,
      );
    });

    test('a skipped exercise gets no suggestion', () {
      final skipped = ExerciseLog(
        exerciseId: bench.id,
        exerciseName: bench.name,
        sets: const [],
        skipped: true,
      );
      expect(
        Progression.suggest(
          exercise: bench,
          lastLog: skipped,
          prescription: bench.prescriptionFor(Goal.gain),
        ),
        isNull,
      );
    });

    test('missing feedback is treated as just right', () {
      final noFeedback = ExerciseLog(
        exerciseId: bench.id,
        exerciseName: bench.name,
        sets: const [SetLog(setNumber: 1, reps: 8, weightKg: 60)],
      );
      final s =
          Progression.suggest(
            exercise: bench,
            lastLog: noFeedback,
            prescription: bench.prescriptionFor(Goal.gain),
          )!;
      expect(s.reasonKey, 'progressionAddRep');
    });
  });

  group('deload', () {
    test('a deload week drops the load to 60% and removes a set', () {
      final s =
          Progression.suggest(
            exercise: bench,
            lastLog: log(bench, feedback: SetFeedback.tooEasy, weight: 100),
            prescription: bench.prescriptionFor(Goal.gain), // 4 sets
            isDeloadWeek: true,
          )!;
      expect(s.weightKg, 60.0);
      expect(s.sets, 3);
      expect(s.reasonKey, 'progressionDeload');
    });

    test('a deload overrides even a too easy rating', () {
      final s =
          Progression.suggest(
            exercise: bench,
            lastLog: log(bench, feedback: SetFeedback.tooEasy, weight: 80),
            prescription: bench.prescriptionFor(Goal.gain),
            isDeloadWeek: true,
          )!;
      expect(s.weightKg, lessThan(80));
    });

    test('a deload never leaves fewer than one set', () {
      final s =
          Progression.suggest(
            exercise: plank,
            lastLog: log(plank, feedback: SetFeedback.justRight, seconds: 30),
            prescription: const ExercisePrescription(
              sets: 1,
              repsMin: 30,
              repsMax: 45,
              restSec: 40,
            ),
            isDeloadWeek: true,
          )!;
      expect(s.sets, greaterThanOrEqualTo(1));
    });
  });

  group('applying a suggestion', () {
    test('a null suggestion leaves the prescription untouched', () {
      final base = bench.prescriptionFor(Goal.gain);
      expect(Progression.applyTo(base, null), same(base));
    });

    test('an applied suggestion never inverts the rep range', () {
      final base = bench.prescriptionFor(Goal.gain);
      final applied = Progression.applyTo(
        base,
        const ProgressionSuggestion(
          exerciseId: 'barbell_bench_press',
          reasonKey: 'progressionAddRep',
          repsMin: 12,
          repsMax: 8,
        ),
      );
      expect(applied.repsMax, greaterThanOrEqualTo(applied.repsMin));
    });
  });

  group('a full progression cycle behaves sensibly', () {
    test('repeated too easy ratings climb steadily', () {
      var weight = 40.0;
      for (var session = 0; session < 5; session++) {
        final s =
            Progression.suggest(
              exercise: bench,
              lastLog: log(
                bench,
                feedback: SetFeedback.tooEasy,
                weight: weight,
                reps: 8,
              ),
              prescription: bench.prescriptionFor(Goal.gain),
            )!;
        weight = s.weightKg!;
      }
      expect(weight, 52.5); // 40 plus five 2.5 kg steps
    });

    test('a too hard rating walks the weight back down', () {
      final up =
          Progression.suggest(
            exercise: bench,
            lastLog: log(bench, feedback: SetFeedback.tooEasy, weight: 80),
            prescription: bench.prescriptionFor(Goal.gain),
          )!;
      final down =
          Progression.suggest(
            exercise: bench,
            lastLog: log(
              bench,
              feedback: SetFeedback.tooHard,
              weight: up.weightKg!,
            ),
            prescription: bench.prescriptionFor(Goal.gain),
          )!;
      expect(down.weightKg, lessThan(up.weightKg!));
    });
  });
}
