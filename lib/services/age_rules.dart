import '../models/enums.dart';
import '../models/guideline_data.dart';
import '../models/guidelines.dart';
import '../models/targets.dart';

/// What the app will and will not do for a user of a given age.
class AgeDecision {
  const AgeDecision({
    required this.access,
    required this.rule,
    required this.band,
    required this.allowWeightLossGoal,
    required this.allowCalorieDeficit,
    required this.lighterDefault,
    required this.strongerDoctorNotice,
    this.message,
  });

  final AccessLevel access;
  final AgeRule rule;
  final ActivityBand band;
  final bool allowWeightLossGoal;
  final bool allowCalorieDeficit;

  /// Start the user on lower intensity and prefer low-impact exercises.
  final bool lighterDefault;

  /// Show the louder "talk to your doctor" notice.
  final bool strongerDoctorNotice;
  final String? message;

  bool get isBlocked => access == AccessLevel.blocked;

  /// Goals the user is allowed to pick.
  List<Goal> get allowedGoals =>
      allowWeightLossGoal
          ? const [Goal.gain, Goal.lose, Goal.maintain]
          : const [Goal.gain, Goal.maintain];
}

/// Pure age gating, driven entirely by safety_rules.json.
class AgeRules {
  const AgeRules._();

  /// Resolve the age rules for [age].
  ///
  /// Under 13 the app is blocked outright. From 13 to 17 the user gets activity
  /// guidance only, with no calorie deficit and no weight-loss target. From 18
  /// everything is available. From 60 the defaults get lighter and the
  /// doctor-advice notice gets stronger.
  static AgeDecision decide({
    required GuidelineData data,
    required int age,
    bool bmiBlocksWeightLoss = false,
  }) {
    final rule = data.ruleForAge(age);
    final access = rule.accessLevel;

    // The WHO band is chosen by age, not by the rule, so a 60 to 64 year old
    // still gets the adult band and a 65+ user gets the older-adult band.
    final band = data.bandForAge(age);

    return AgeDecision(
      access: access,
      rule: rule,
      band: band,
      allowWeightLossGoal: rule.allowWeightLossGoal && !bmiBlocksWeightLoss,
      allowCalorieDeficit: rule.allowCalorieDeficit && !bmiBlocksWeightLoss,
      lighterDefault: access == AccessLevel.fullLighterDefault,
      strongerDoctorNotice:
          access == AccessLevel.fullLighterDefault ||
          access == AccessLevel.activityOnly,
      message: rule.message,
    );
  }

  /// Weekly activity target for this age, straight from the WHO band.
  static ActivityTargets activityTargets({
    required GuidelineData data,
    required int age,
  }) {
    final band = data.bandForAge(age);
    return ActivityTargets(
      bandId: band.id,
      bandLabel: band.label,
      aerobicMinutesPerWeek: band.weeklyAerobicTarget,
      aerobicMinutesPerWeekMax: band.aerobicMinutesPerWeekMax,
      strengthDaysPerWeek: band.muscleStrengtheningDaysPerWeek,
      balanceDaysPerWeek: band.balanceAndStrengthDaysPerWeek,
      sourceId: band.sourceId,
    );
  }

  /// Experience level the app will actually plan for.
  ///
  /// A 60+ user who says they are advanced still starts on beginner defaults,
  /// because the age rule caps the starting intensity. They can raise it later
  /// from Settings; this only controls the starting point.
  static ExperienceLevel effectiveExperience({
    required GuidelineData data,
    required int age,
    required ExperienceLevel stated,
  }) {
    final decision = decide(data: data, age: age);
    if (!decision.lighterDefault) return stated;
    return stated.rank > ExperienceLevel.beginner.rank
        ? ExperienceLevel.beginner
        : stated;
  }
}
