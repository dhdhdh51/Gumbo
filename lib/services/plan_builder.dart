import '../models/enums.dart';
import '../models/exercise.dart';
import '../models/guideline_data.dart';
import '../models/profile.dart';
import '../models/workout.dart';
import '../constants.dart';

/// One slot in a session template: which muscle group and how many exercises.
typedef SessionSlot = ({String muscle, int count, bool compoundFirst});

/// A session template: a localisation key, the muscles it hits and its slots.
class SessionTemplate {
  const SessionTemplate({
    required this.labelKey,
    required this.muscles,
    required this.slots,
  });

  final String labelKey;
  final List<String> muscles;
  final List<SessionSlot> slots;
}

/// Builds the weekly plan: which split, which day, which exercises.
///
/// Split selection follows the days the user committed to:
///   3 days      -> full body
///   4 days      -> upper / lower
///   5 or 6 days -> push / pull / legs
///
/// Rest days are spread through the week rather than bunched at the end, so a
/// 3-day plan trains on days 0, 2 and 4 of the rotation.
class PlanBuilder {
  const PlanBuilder._();

  static const String restLabelKey = 'splitRest';

  /// Pick the split for a number of training days per week.
  static SplitType splitFor(int daysPerWeek) {
    if (daysPerWeek <= 3) return SplitType.fullBody;
    if (daysPerWeek == 4) return SplitType.upperLower;
    return SplitType.pushPullLegs;
  }

  /// Which rotation positions are training days for [daysPerWeek].
  ///
  /// Spreading the days keeps at least one rest day between most sessions.
  static List<int> trainingDayPositions(int daysPerWeek) =>
      switch (daysPerWeek) {
        3 => const [0, 2, 4],
        4 => const [0, 1, 3, 4],
        5 => const [0, 1, 2, 4, 5],
        6 => const [0, 1, 2, 3, 4, 5],
        _ => const [0, 2, 4],
      };

  /// Session templates for a split, in the order they rotate.
  static List<SessionTemplate> templatesFor(SplitType split) => switch (split) {
    SplitType.fullBody => const [
      SessionTemplate(
        labelKey: 'splitFullBodyA',
        muscles: ['quads', 'chest', 'back', 'core'],
        slots: [
          (muscle: 'quads', count: 1, compoundFirst: true),
          (muscle: 'chest', count: 1, compoundFirst: true),
          (muscle: 'back', count: 1, compoundFirst: true),
          (muscle: 'shoulders', count: 1, compoundFirst: false),
          (muscle: 'core', count: 1, compoundFirst: false),
        ],
      ),
      SessionTemplate(
        labelKey: 'splitFullBodyB',
        muscles: ['hamstrings', 'glutes', 'lats', 'shoulders'],
        slots: [
          (muscle: 'hamstrings', count: 1, compoundFirst: true),
          (muscle: 'lats', count: 1, compoundFirst: true),
          (muscle: 'shoulders', count: 1, compoundFirst: true),
          (muscle: 'glutes', count: 1, compoundFirst: false),
          (muscle: 'core', count: 1, compoundFirst: false),
        ],
      ),
      SessionTemplate(
        labelKey: 'splitFullBodyC',
        muscles: ['glutes', 'chest', 'back', 'calves'],
        slots: [
          (muscle: 'glutes', count: 1, compoundFirst: true),
          (muscle: 'chest', count: 1, compoundFirst: true),
          (muscle: 'back', count: 1, compoundFirst: true),
          (muscle: 'biceps', count: 1, compoundFirst: false),
          (muscle: 'triceps', count: 1, compoundFirst: false),
          (muscle: 'calves', count: 1, compoundFirst: false),
        ],
      ),
    ],
    SplitType.upperLower => const [
      SessionTemplate(
        labelKey: 'splitUpper',
        muscles: ['chest', 'back', 'shoulders', 'biceps', 'triceps'],
        slots: [
          (muscle: 'chest', count: 2, compoundFirst: true),
          (muscle: 'back', count: 2, compoundFirst: true),
          (muscle: 'shoulders', count: 1, compoundFirst: false),
          (muscle: 'biceps', count: 1, compoundFirst: false),
          (muscle: 'triceps', count: 1, compoundFirst: false),
        ],
      ),
      SessionTemplate(
        labelKey: 'splitLower',
        muscles: ['quads', 'hamstrings', 'glutes', 'calves', 'core'],
        slots: [
          (muscle: 'quads', count: 2, compoundFirst: true),
          (muscle: 'hamstrings', count: 1, compoundFirst: true),
          (muscle: 'glutes', count: 1, compoundFirst: false),
          (muscle: 'calves', count: 1, compoundFirst: false),
          (muscle: 'core', count: 1, compoundFirst: false),
        ],
      ),
    ],
    SplitType.pushPullLegs => const [
      SessionTemplate(
        labelKey: 'splitPush',
        muscles: ['chest', 'shoulders', 'triceps'],
        slots: [
          (muscle: 'chest', count: 2, compoundFirst: true),
          (muscle: 'shoulders', count: 2, compoundFirst: true),
          (muscle: 'triceps', count: 2, compoundFirst: false),
        ],
      ),
      SessionTemplate(
        labelKey: 'splitPull',
        muscles: ['back', 'lats', 'biceps'],
        slots: [
          (muscle: 'back', count: 2, compoundFirst: true),
          (muscle: 'lats', count: 1, compoundFirst: true),
          (muscle: 'rear_delts', count: 1, compoundFirst: false),
          (muscle: 'biceps', count: 2, compoundFirst: false),
        ],
      ),
      SessionTemplate(
        labelKey: 'splitLegs',
        muscles: ['quads', 'hamstrings', 'glutes', 'calves'],
        slots: [
          (muscle: 'quads', count: 2, compoundFirst: true),
          (muscle: 'hamstrings', count: 2, compoundFirst: true),
          (muscle: 'glutes', count: 1, compoundFirst: false),
          (muscle: 'calves', count: 1, compoundFirst: false),
        ],
      ),
    ],
  };

  /// Which rotation position [date] falls on, counting whole days from the
  /// plan start. The rotation length is always seven so the plan lines up with
  /// the calendar week.
  static int rotationIndex({
    required DateTime planStart,
    required DateTime date,
  }) {
    final a = DateTime(planStart.year, planStart.month, planStart.day);
    final b = DateTime(date.year, date.month, date.day);
    final days = b.difference(a).inDays;
    return ((days % 7) + 7) % 7;
  }

  /// 1-based training week number for [date].
  static int weekNumber({required DateTime planStart, required DateTime date}) {
    final a = DateTime(planStart.year, planStart.month, planStart.day);
    final b = DateTime(date.year, date.month, date.day);
    final days = b.difference(a).inDays;
    if (days < 0) return 1;
    return (days ~/ 7) + 1;
  }

  /// How many training weeks pass before a deload, by experience level.
  static int deloadCycleFor(ExperienceLevel level) => switch (level) {
    ExperienceLevel.beginner => ProgressionConfig.deloadEveryWeeksBeginner,
    ExperienceLevel.intermediate =>
      ProgressionConfig.deloadEveryWeeksIntermediate,
    ExperienceLevel.advanced => ProgressionConfig.deloadEveryWeeksAdvanced,
  };

  /// True when [week] is a scheduled deload week.
  static bool isDeloadWeek({
    required int week,
    required ExperienceLevel level,
  }) {
    final cycle = deloadCycleFor(level);
    return week > 1 && week % cycle == 0;
  }

  /// Candidate exercises for one muscle, filtered by place and experience and
  /// ordered so the most appropriate choice comes first.
  static List<Exercise> candidatesFor({
    required GuidelineData data,
    required String muscle,
    required TrainingPlace place,
    required ExperienceLevel maxDifficulty,
    bool preferLowImpact = false,
    bool compoundFirst = true,
    Set<String> exclude = const {},
  }) {
    final list =
        data.exercises.where((e) {
          if (exclude.contains(e.id)) return false;
          if (!e.availableAt(place)) return false;
          if (e.difficulty.rank > maxDifficulty.rank) return false;
          if (preferLowImpact && !e.lowImpact) return false;
          return e.primaryMuscles.contains(muscle);
        }).toList();

    list.sort((a, b) {
      // Compound movements first (or last) depending on the slot.
      if (a.isCompound != b.isCompound) {
        final aFirst = a.isCompound == compoundFirst;
        return aFirst ? -1 : 1;
      }
      // Then the exercise closest to the user's level without exceeding it.
      final byLevel = b.difficulty.rank.compareTo(a.difficulty.rank);
      if (byLevel != 0) return byLevel;
      return a.name.compareTo(b.name);
    });

    return list;
  }

  /// Build the plan for one specific date.
  ///
  /// [previousWeights] maps exercise id to the weight the progression engine
  /// recommends. Exercises with no history simply carry no suggestion, and the
  /// UI asks the user rather than inventing a starting weight.
  static PlannedDay buildDay({
    required GuidelineData data,
    required UserProfile profile,
    required DateTime date,
    required ExperienceLevel effectiveExperience,
    bool preferLowImpact = false,
    bool premium = true,
    Map<String, double> previousWeights = const {},
    Map<String, String> progressionReasons = const {},
  }) {
    // A free user is capped at the 3-day full-body plan.
    final days =
        premium
            ? profile.daysPerWeek.clamp(3, 6)
            : profile.daysPerWeek.clamp(3, Entitlements.freeMaxDaysPerWeek);

    final split = splitFor(days);
    final positions = trainingDayPositions(days);
    final index = rotationIndex(
      planStart: profile.effectivePlanStart,
      date: date,
    );
    final week = weekNumber(planStart: profile.effectivePlanStart, date: date);
    final deload = isDeloadWeek(week: week, level: effectiveExperience);

    final slotInRotation = positions.indexOf(index);
    if (slotInRotation < 0) {
      return PlannedDay(
        dayIndex: index,
        isRest: true,
        labelKey: restLabelKey,
        muscleGroups: const [],
        exercises: const [],
        isDeload: deload,
      );
    }

    final templates = templatesFor(split);
    // Keep rotating through templates across weeks so a 4-day upper/lower plan
    // does not always start on the same session.
    final templateIndex =
        (slotInRotation + (week - 1) * positions.length) % templates.length;
    final template = templates[templateIndex];

    final chosen = <PlannedExercise>[];
    final used = <String>{};

    for (final slot in template.slots) {
      var candidates = candidatesFor(
        data: data,
        muscle: slot.muscle,
        place: profile.place,
        maxDifficulty: effectiveExperience,
        preferLowImpact: preferLowImpact,
        compoundFirst: slot.compoundFirst,
        exclude: used,
      );

      // If the low-impact filter left nothing, fall back to the unfiltered set
      // rather than dropping the muscle group from the session entirely.
      if (candidates.isEmpty && preferLowImpact) {
        candidates = candidatesFor(
          data: data,
          muscle: slot.muscle,
          place: profile.place,
          maxDifficulty: effectiveExperience,
          compoundFirst: slot.compoundFirst,
          exclude: used,
        );
      }

      for (var i = 0; i < slot.count && i < candidates.length; i++) {
        final ex = candidates[i];
        used.add(ex.id);

        var prescription = ex.prescriptionFor(profile.goal);
        if (deload) {
          // A deload week keeps the movement but cuts the work.
          prescription = prescription.copyWith(
            sets: (prescription.sets - 1).clamp(1, 10),
          );
        }

        final suggested = previousWeights[ex.id];
        chosen.add(
          PlannedExercise(
            exercise: ex,
            prescription: prescription,
            suggestedWeightKg:
                deload && suggested != null
                    ? _roundToIncrement(
                      suggested * ProgressionConfig.deloadLoadFactor,
                    )
                    : suggested,
            progressionReasonKey:
                deload ? 'progressionDeload' : progressionReasons[ex.id],
          ),
        );
      }
    }

    return PlannedDay(
      dayIndex: index,
      isRest: false,
      labelKey: template.labelKey,
      muscleGroups: template.muscles,
      exercises: chosen,
      isDeload: deload,
    );
  }

  /// Build the whole seven-day rotation that contains [date].
  static WeeklyPlan buildWeek({
    required GuidelineData data,
    required UserProfile profile,
    required DateTime date,
    required ExperienceLevel effectiveExperience,
    bool preferLowImpact = false,
    bool premium = true,
    Map<String, double> previousWeights = const {},
  }) {
    final days =
        premium
            ? profile.daysPerWeek.clamp(3, 6)
            : profile.daysPerWeek.clamp(3, Entitlements.freeMaxDaysPerWeek);
    final week = weekNumber(planStart: profile.effectivePlanStart, date: date);
    final index = rotationIndex(
      planStart: profile.effectivePlanStart,
      date: date,
    );
    final weekStart = date.subtract(Duration(days: index));

    return WeeklyPlan(
      split: splitFor(days),
      daysPerWeek: days,
      weekNumber: week,
      isDeloadWeek: isDeloadWeek(week: week, level: effectiveExperience),
      days: [
        for (var i = 0; i < 7; i++)
          buildDay(
            data: data,
            profile: profile,
            date: weekStart.add(Duration(days: i)),
            effectiveExperience: effectiveExperience,
            preferLowImpact: preferLowImpact,
            premium: premium,
            previousWeights: previousWeights,
          ),
      ],
    );
  }

  /// A reduced session offered after the user reports a problem today.
  ///
  /// Only low-impact work, fewer sets, no advanced movements. This is offered
  /// instead of the planned session, never in addition to it.
  static PlannedDay buildLightSession({
    required GuidelineData data,
    required TrainingPlace place,
  }) {
    final picks = <Exercise>[];
    for (final muscle in ['full_body', 'core', 'glutes']) {
      final candidates = candidatesFor(
        data: data,
        muscle: muscle,
        place: place,
        maxDifficulty: ExperienceLevel.beginner,
        preferLowImpact: true,
        compoundFirst: false,
        exclude: picks.map((e) => e.id).toSet(),
      );
      if (candidates.isNotEmpty) picks.add(candidates.first);
    }

    return PlannedDay(
      dayIndex: -1,
      isRest: false,
      labelKey: 'splitLightActivity',
      muscleGroups: const ['full_body'],
      exercises: [
        for (final e in picks)
          PlannedExercise(
            exercise: e,
            // Two easy sets, nothing near a limit.
            prescription: e.prescriptionFor(Goal.maintain).copyWith(sets: 2),
          ),
      ],
    );
  }

  /// Alternatives for the Replace button: same muscle, same place, not already
  /// in today's session.
  static List<Exercise> replacementsFor({
    required GuidelineData data,
    required Exercise current,
    required TrainingPlace place,
    required ExperienceLevel maxDifficulty,
    Set<String> alreadyInSession = const {},
  }) {
    final muscle =
        current.primaryMuscles.isEmpty ? '' : current.primaryMuscles.first;
    return candidatesFor(
      data: data,
      muscle: muscle,
      place: place,
      maxDifficulty: maxDifficulty,
      compoundFirst: current.isCompound,
      exclude: {...alreadyInSession, current.id},
    );
  }

  static double _roundToIncrement(double kg) {
    const step = ProgressionConfig.barbellIncrementKg;
    return (kg / step).round() * step;
  }
}
