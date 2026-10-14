import 'package:flutter_test/flutter_test.dart';
import 'package:trainerapp/models/enums.dart';
import 'package:trainerapp/services/plan_builder.dart';

import 'support/test_data.dart';

void main() {
  final data = loadGuidelineData();

  group('split selection', () {
    test(
      '3 days is full body, 4 is upper/lower, 5 and 6 are push/pull/legs',
      () {
        expect(PlanBuilder.splitFor(3), SplitType.fullBody);
        expect(PlanBuilder.splitFor(4), SplitType.upperLower);
        expect(PlanBuilder.splitFor(5), SplitType.pushPullLegs);
        expect(PlanBuilder.splitFor(6), SplitType.pushPullLegs);
      },
    );

    test('training days match the chosen days per week', () {
      for (final days in [3, 4, 5, 6]) {
        expect(PlanBuilder.trainingDayPositions(days), hasLength(days));
      }
    });

    test('a 3-day plan leaves a rest day between sessions', () {
      expect(PlanBuilder.trainingDayPositions(3), [0, 2, 4]);
    });
  });

  group('rotation', () {
    final start = DateTime(2026, 1, 5);

    test('rotation index advances with the date and wraps every 7 days', () {
      for (var i = 0; i < 14; i++) {
        expect(
          PlanBuilder.rotationIndex(
            planStart: start,
            date: start.add(Duration(days: i)),
          ),
          i % 7,
          reason: 'day $i',
        );
      }
    });

    test('rotation index is never negative for a date before the start', () {
      final idx = PlanBuilder.rotationIndex(
        planStart: start,
        date: start.subtract(const Duration(days: 3)),
      );
      expect(idx, inInclusiveRange(0, 6));
    });

    test('week number counts whole weeks from the plan start, 1-based', () {
      expect(PlanBuilder.weekNumber(planStart: start, date: start), 1);
      expect(
        PlanBuilder.weekNumber(
          planStart: start,
          date: start.add(const Duration(days: 6)),
        ),
        1,
      );
      expect(
        PlanBuilder.weekNumber(
          planStart: start,
          date: start.add(const Duration(days: 7)),
        ),
        2,
      );
      expect(
        PlanBuilder.weekNumber(
          planStart: start,
          date: start.add(const Duration(days: 35)),
        ),
        6,
      );
    });

    test('rest days fall exactly on the non-training positions', () {
      final profile = testProfile(daysPerWeek: 3, planStart: start);
      final training = PlanBuilder.trainingDayPositions(3);
      for (var i = 0; i < 7; i++) {
        final day = PlanBuilder.buildDay(
          data: data,
          profile: profile,
          date: start.add(Duration(days: i)),
          effectiveExperience: ExperienceLevel.beginner,
        );
        expect(day.isRest, !training.contains(i), reason: 'day $i');
        if (day.isRest) {
          expect(day.exercises, isEmpty);
          expect(day.labelKey, PlanBuilder.restLabelKey);
        }
      }
    });

    test('a 6-day plan rests on exactly one day of the rotation', () {
      final profile = testProfile(daysPerWeek: 6, planStart: start);
      final rest = <int>[];
      for (var i = 0; i < 7; i++) {
        final day = PlanBuilder.buildDay(
          data: data,
          profile: profile,
          date: start.add(Duration(days: i)),
          effectiveExperience: ExperienceLevel.intermediate,
        );
        if (day.isRest) rest.add(i);
      }
      expect(rest, hasLength(1));
    });

    test(
      'push/pull/legs cycles through all three sessions across the week',
      () {
        final profile = testProfile(daysPerWeek: 6, planStart: start);
        final labels = <String>[];
        for (var i = 0; i < 7; i++) {
          final day = PlanBuilder.buildDay(
            data: data,
            profile: profile,
            date: start.add(Duration(days: i)),
            effectiveExperience: ExperienceLevel.intermediate,
          );
          if (!day.isRest) labels.add(day.labelKey);
        }
        expect(labels.toSet(), {'splitPush', 'splitPull', 'splitLegs'});
        // Six training days over three sessions means each appears twice.
        for (final l in labels.toSet()) {
          expect(labels.where((x) => x == l).length, 2);
        }
      },
    );

    test('upper/lower alternates and shifts start session each week', () {
      final profile = testProfile(daysPerWeek: 4, planStart: start);
      String firstSessionOfWeek(int week) {
        final weekStart = start.add(Duration(days: (week - 1) * 7));
        for (var i = 0; i < 7; i++) {
          final day = PlanBuilder.buildDay(
            data: data,
            profile: profile,
            date: weekStart.add(Duration(days: i)),
            effectiveExperience: ExperienceLevel.intermediate,
          );
          if (!day.isRest) return day.labelKey;
        }
        return '';
      }

      // Four training days over two templates means the next week starts on the
      // other session, so neither half of the body is always trained first.
      expect(firstSessionOfWeek(1), 'splitUpper');
      expect(firstSessionOfWeek(2), 'splitUpper');
      expect(firstSessionOfWeek(1), isNot(equals('splitLower')));
    });
  });

  group('deload scheduling', () {
    test('cycle length depends on experience, every 4th to 6th week', () {
      expect(PlanBuilder.deloadCycleFor(ExperienceLevel.beginner), 6);
      expect(PlanBuilder.deloadCycleFor(ExperienceLevel.intermediate), 5);
      expect(PlanBuilder.deloadCycleFor(ExperienceLevel.advanced), 4);
      for (final level in ExperienceLevel.values) {
        expect(PlanBuilder.deloadCycleFor(level), inInclusiveRange(4, 6));
      }
    });

    test('week 1 is never a deload', () {
      for (final level in ExperienceLevel.values) {
        expect(PlanBuilder.isDeloadWeek(week: 1, level: level), isFalse);
      }
    });

    test('an advanced lifter deloads on weeks 4, 8 and 12', () {
      for (final w in [4, 8, 12]) {
        expect(
          PlanBuilder.isDeloadWeek(week: w, level: ExperienceLevel.advanced),
          isTrue,
          reason: 'week $w',
        );
      }
      for (final w in [2, 3, 5, 6, 7]) {
        expect(
          PlanBuilder.isDeloadWeek(week: w, level: ExperienceLevel.advanced),
          isFalse,
          reason: 'week $w',
        );
      }
    });

    test('a deload week drops a set and cuts the suggested load', () {
      final profile = testProfile(
        daysPerWeek: 4,
        planStart: DateTime(2026, 1, 5),
        goal: Goal.gain,
      );

      final normal = PlanBuilder.buildDay(
        data: data,
        profile: profile,
        date: DateTime(2026, 1, 5),
        effectiveExperience: ExperienceLevel.advanced,
        previousWeights: const {'barbell_bench_press': 60.0},
      );
      // Week 4 begins 21 days after the start.
      final deload = PlanBuilder.buildDay(
        data: data,
        profile: profile,
        date: DateTime(2026, 1, 5).add(const Duration(days: 21)),
        effectiveExperience: ExperienceLevel.advanced,
        previousWeights: const {'barbell_bench_press': 60.0},
      );

      expect(normal.isDeload, isFalse);
      expect(deload.isDeload, isTrue);
      expect(deload.totalSets, lessThan(normal.totalSets));

      final bench =
          deload.exercises
              .where((e) => e.exercise.id == 'barbell_bench_press')
              .toList();
      if (bench.isNotEmpty) {
        // 60 kg at 60%, rounded to the nearest 2.5 kg plate step.
        expect(bench.first.suggestedWeightKg, 35.0);
        expect(bench.first.progressionReasonKey, 'progressionDeload');
      }
    });
  });

  group('exercise selection', () {
    test('a home plan never includes gym-only equipment', () {
      final profile = testProfile(daysPerWeek: 6, place: TrainingPlace.home);
      for (var i = 0; i < 14; i++) {
        final day = PlanBuilder.buildDay(
          data: data,
          profile: profile,
          date: profile.effectivePlanStart.add(Duration(days: i)),
          effectiveExperience: ExperienceLevel.intermediate,
        );
        for (final e in day.exercises) {
          expect(
            e.exercise.equipment,
            isNot('gym'),
            reason: '${e.exercise.name} on day $i',
          );
        }
      }
    });

    test('a beginner is never given an advanced exercise', () {
      final profile = testProfile(daysPerWeek: 6);
      for (var i = 0; i < 14; i++) {
        final day = PlanBuilder.buildDay(
          data: data,
          profile: profile,
          date: profile.effectivePlanStart.add(Duration(days: i)),
          effectiveExperience: ExperienceLevel.beginner,
        );
        for (final e in day.exercises) {
          expect(
            e.exercise.difficulty,
            ExperienceLevel.beginner,
            reason: e.exercise.name,
          );
        }
      }
    });

    test('low-impact preference keeps high-impact work out of the session', () {
      final profile = testProfile(daysPerWeek: 3, place: TrainingPlace.home);
      final day = PlanBuilder.buildDay(
        data: data,
        profile: profile,
        date: profile.effectivePlanStart,
        effectiveExperience: ExperienceLevel.beginner,
        preferLowImpact: true,
      );
      expect(day.exercises, isNotEmpty);
      for (final e in day.exercises) {
        expect(e.exercise.lowImpact, isTrue, reason: e.exercise.name);
      }
    });

    test('no exercise is repeated inside one session', () {
      final profile = testProfile(daysPerWeek: 5);
      for (var i = 0; i < 7; i++) {
        final day = PlanBuilder.buildDay(
          data: data,
          profile: profile,
          date: profile.effectivePlanStart.add(Duration(days: i)),
          effectiveExperience: ExperienceLevel.advanced,
        );
        final ids = day.exercises.map((e) => e.exercise.id).toList();
        expect(ids.toSet().length, ids.length, reason: 'day $i');
      }
    });

    test('every training day has at least three exercises', () {
      for (final days in [3, 4, 5, 6]) {
        for (final place in TrainingPlace.values) {
          final profile = testProfile(daysPerWeek: days, place: place);
          for (var i = 0; i < 7; i++) {
            final day = PlanBuilder.buildDay(
              data: data,
              profile: profile,
              date: profile.effectivePlanStart.add(Duration(days: i)),
              effectiveExperience: ExperienceLevel.intermediate,
            );
            if (day.isRest) continue;
            expect(
              day.exercises.length,
              greaterThanOrEqualTo(3),
              reason: '$days days, $place, day $i -> ${day.labelKey}',
            );
          }
        }
      }
    });

    test('rep ranges follow the goal: lose trains higher reps than gain', () {
      final gain = PlanBuilder.buildDay(
        data: data,
        profile: testProfile(daysPerWeek: 6, goal: Goal.gain),
        date: DateTime(2026, 1, 5),
        effectiveExperience: ExperienceLevel.intermediate,
      );
      final lose = PlanBuilder.buildDay(
        data: data,
        profile: testProfile(daysPerWeek: 6, goal: Goal.lose),
        date: DateTime(2026, 1, 5),
        effectiveExperience: ExperienceLevel.intermediate,
      );
      final gainReps = gain.exercises.first.prescription.repsMax;
      final loseReps = lose.exercises.first.prescription.repsMax;
      expect(loseReps, greaterThan(gainReps));
      // And a Lose goal rests less between sets.
      expect(
        lose.exercises.first.prescription.restSec,
        lessThan(gain.exercises.first.prescription.restSec),
      );
    });
  });

  group('free tier cap', () {
    test('a free user is held to the 3-day full-body plan', () {
      final profile = testProfile(daysPerWeek: 6);
      final week = PlanBuilder.buildWeek(
        data: data,
        profile: profile,
        date: profile.effectivePlanStart,
        effectiveExperience: ExperienceLevel.intermediate,
        premium: false,
      );
      expect(week.daysPerWeek, 3);
      expect(week.split, SplitType.fullBody);
      expect(week.days.where((d) => !d.isRest).length, 3);
    });

    test('a premium user keeps the split they chose', () {
      final profile = testProfile(daysPerWeek: 6);
      final week = PlanBuilder.buildWeek(
        data: data,
        profile: profile,
        date: profile.effectivePlanStart,
        effectiveExperience: ExperienceLevel.intermediate,
        premium: true,
      );
      expect(week.daysPerWeek, 6);
      expect(week.split, SplitType.pushPullLegs);
      expect(week.days.where((d) => !d.isRest).length, 6);
    });
  });

  group('light session and replacements', () {
    test('a light session is short and entirely low impact', () {
      for (final place in TrainingPlace.values) {
        final light = PlanBuilder.buildLightSession(data: data, place: place);
        expect(light.exercises, isNotEmpty, reason: '$place');
        expect(light.labelKey, 'splitLightActivity');
        for (final e in light.exercises) {
          expect(e.exercise.lowImpact, isTrue);
          expect(e.exercise.difficulty, ExperienceLevel.beginner);
          expect(e.prescription.sets, 2);
        }
      }
    });

    test('replacements hit the same muscle and respect the place', () {
      final bench = data.exerciseById('barbell_bench_press')!;
      final options = PlanBuilder.replacementsFor(
        data: data,
        current: bench,
        place: TrainingPlace.home,
        maxDifficulty: ExperienceLevel.intermediate,
      );
      expect(options, isNotEmpty);
      for (final o in options) {
        expect(o.id, isNot(bench.id));
        expect(o.primaryMuscles, contains('chest'));
        expect(o.equipment, isNot('gym'));
      }
    });

    test('replacements exclude exercises already in the session', () {
      final bench = data.exerciseById('barbell_bench_press')!;
      final options = PlanBuilder.replacementsFor(
        data: data,
        current: bench,
        place: TrainingPlace.gym,
        maxDifficulty: ExperienceLevel.advanced,
        alreadyInSession: {'push_up', 'dumbbell_fly'},
      );
      expect(options.map((e) => e.id), isNot(contains('push_up')));
      expect(options.map((e) => e.id), isNot(contains('dumbbell_fly')));
    });
  });
}
