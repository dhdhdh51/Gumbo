import '../models/enums.dart';
import '../models/guideline_data.dart';
import '../models/profile.dart';
import '../models/workout.dart';

/// What the onboarding screening told us.
class ScreeningResult {
  const ScreeningResult({
    required this.seriousFlags,
    required this.cautionFlags,
    required this.requiresDoctorNotice,
    required this.blocksWeightLoss,
    required this.blocksHighIntensity,
  });

  static const ScreeningResult clear = ScreeningResult(
    seriousFlags: [],
    cautionFlags: [],
    requiresDoctorNotice: false,
    blocksWeightLoss: false,
    blocksHighIntensity: false,
  );

  /// Ids of serious items answered yes.
  final List<String> seriousFlags;

  /// Ids of caution items answered yes.
  final List<String> cautionFlags;

  /// Show the "please consult a doctor first" notice.
  final bool requiresDoctorNotice;

  /// Weight-loss targets are withheld until medical clearance is confirmed.
  final bool blocksWeightLoss;

  /// High-intensity and advanced exercises are withheld until clearance.
  final bool blocksHighIntensity;

  bool get hasAnyFlag => seriousFlags.isNotEmpty || cautionFlags.isNotEmpty;
}

/// The decision made from the pre-workout check.
class PreWorkoutDecision {
  const PreWorkoutDecision({
    required this.outcome,
    required this.redFlags,
    required this.allowNormalPlan,
    required this.offerLightActivity,
  });

  final PreWorkoutOutcome outcome;
  final List<String> redFlags;

  /// Only ever true when the user reported no problem at all today.
  final bool allowNormalPlan;
  final bool offerLightActivity;

  bool get isEmergency => outcome == PreWorkoutOutcome.seekHelpNow;
}

/// Pure health-screening logic. Nothing here diagnoses anything; it only
/// decides what the app is willing to do.
class HealthSafety {
  const HealthSafety._();

  /// Evaluate the onboarding questionnaire.
  ///
  /// Any serious item answered yes shows a clear notice to see a doctor and
  /// withholds weight-loss targets and high-intensity plans until the user
  /// confirms they have medical clearance. Caution items only show the notice.
  static ScreeningResult evaluateScreening({
    required GuidelineData data,
    required HealthAnswers answers,
    required MedicalClearance clearance,
  }) {
    final serious = <String>[];
    final caution = <String>[];

    for (final id in answers.yesIds) {
      final item = data.screeningItem(id);
      if (item == null) continue;
      if (item.isSerious) {
        serious.add(id);
      } else {
        caution.add(id);
      }
    }

    final cleared = clearance.confirmed;

    return ScreeningResult(
      seriousFlags: serious,
      cautionFlags: caution,
      requiresDoctorNotice: serious.isNotEmpty || caution.isNotEmpty,
      blocksWeightLoss: serious.isNotEmpty && !cleared,
      blocksHighIntensity: serious.isNotEmpty && !cleared,
    );
  }

  /// Evaluate the check shown every single time the user taps Start Workout.
  ///
  /// Red flags (chest pain, fainting, severe breathlessness) stop everything
  /// and tell the user to seek medical help now. Any other reported problem
  /// means the normal plan is not offered; the user gets light activity only or
  /// can skip the day.
  static PreWorkoutDecision evaluateDailyCheck({
    required bool hasProblem,
    required Set<String> redFlags,
  }) {
    if (redFlags.isNotEmpty) {
      return PreWorkoutDecision(
        outcome: PreWorkoutOutcome.seekHelpNow,
        redFlags: redFlags.toList(),
        allowNormalPlan: false,
        offerLightActivity: false,
      );
    }

    if (hasProblem) {
      return const PreWorkoutDecision(
        outcome: PreWorkoutOutcome.lightActivityOnly,
        redFlags: [],
        allowNormalPlan: false,
        offerLightActivity: true,
      );
    }

    return const PreWorkoutDecision(
      outcome: PreWorkoutOutcome.proceedNormal,
      redFlags: [],
      allowNormalPlan: true,
      offerLightActivity: false,
    );
  }

  /// Build the record that gets stored for every pre-workout check, so the
  /// history shows that the question was asked and what was answered.
  static PreWorkoutCheck recordFor({
    required PreWorkoutDecision decision,
    required bool hasProblem,
    String? note,
    PreWorkoutOutcome? chosen,
  }) => PreWorkoutCheck(
    answeredAt: DateTime.now(),
    hasProblem: hasProblem,
    redFlags: decision.redFlags,
    outcome: chosen ?? decision.outcome,
    note: (note == null || note.trim().isEmpty) ? null : note.trim(),
  );

  /// Whether automatic diet changes should be paused.
  ///
  /// A yes to "any new health problem or medication change?" at a weekly
  /// check-in pauses them until the user explicitly clears it.
  static bool shouldPauseDietChanges({
    required bool newHealthProblemReported,
  }) => newHealthProblemReported;
}
