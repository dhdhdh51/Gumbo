import 'package:flutter/material.dart' show ThemeMode, Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/diet.dart';
import '../models/entitlement.dart';
import '../models/enums.dart';
import '../models/food.dart';
import '../models/guideline_data.dart';
import '../models/profile.dart';
import '../models/progress.dart';
import '../models/targets.dart';
import '../models/workout.dart';
import '../services/age_rules.dart';
import '../services/billing_service.dart';
import '../services/calculations.dart';
import '../services/data_repository.dart';
import '../services/database.dart';
import '../services/entitlement_service.dart';
import '../services/export_service.dart';
import '../services/health_safety.dart';
import '../services/meal_planner.dart';
import '../services/notification_service.dart';
import '../services/plan_builder.dart';
import '../services/prefs_service.dart';
import '../services/progression.dart';

/// Everything initialised once at startup and handed to the provider tree.
class AppServices {
  const AppServices({
    required this.repository,
    required this.prefs,
    required this.db,
    required this.notifications,
    required this.entitlements,
    required this.billing,
    required this.export,
  });

  final DataRepository repository;
  final PrefsService prefs;
  final AppDatabase db;
  final NotificationService notifications;
  final EntitlementService entitlements;
  final BillingService billing;
  final ExportService export;

  GuidelineData get data => repository.data;
}

/// Overridden in main() once startup has finished.
final servicesProvider = Provider<AppServices>(
  (ref) => throw StateError('servicesProvider must be overridden in main()'),
);

final guidelineDataProvider = Provider<GuidelineData>(
  (ref) => ref.watch(servicesProvider).data,
);

// ---------------------------------------------------------------- settings

class AppSettings {
  const AppSettings({
    required this.locale,
    required this.themeMode,
    required this.weightUnit,
    required this.consentAccepted,
  });

  /// Null means the user has not chosen yet, so the language screen is shown.
  final Locale? locale;
  final ThemeMode themeMode;
  final WeightUnit weightUnit;
  final bool consentAccepted;

  AppSettings copyWith({
    Locale? locale,
    ThemeMode? themeMode,
    WeightUnit? weightUnit,
    bool? consentAccepted,
  }) => AppSettings(
    locale: locale ?? this.locale,
    themeMode: themeMode ?? this.themeMode,
    weightUnit: weightUnit ?? this.weightUnit,
    consentAccepted: consentAccepted ?? this.consentAccepted,
  );
}

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final prefs = ref.watch(servicesProvider).prefs;
    final code = prefs.localeCode;
    return AppSettings(
      locale: code == null ? null : Locale(code),
      themeMode: prefs.themeMode,
      weightUnit: prefs.weightUnit,
      consentAccepted: prefs.consentAccepted,
    );
  }

  PrefsService get _prefs => ref.read(servicesProvider).prefs;

  Future<void> setLocale(Locale locale) async {
    await _prefs.setLocaleCode(locale.languageCode);
    state = state.copyWith(locale: locale);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setThemeMode(mode);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setWeightUnit(WeightUnit unit) async {
    await _prefs.setWeightUnit(unit);
    state = state.copyWith(weightUnit: unit);
  }

  Future<void> acceptConsent() async {
    await _prefs.acceptConsent();
    state = state.copyWith(consentAccepted: true);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

// ----------------------------------------------------------------- profile

/// Profile plus the health screening that goes with it.
class ProfileState {
  const ProfileState({
    required this.profile,
    required this.healthAnswers,
    required this.clearance,
  });

  final UserProfile? profile;
  final HealthAnswers healthAnswers;
  final MedicalClearance clearance;

  bool get hasProfile => profile != null;
}

class ProfileNotifier extends Notifier<ProfileState> {
  @override
  ProfileState build() {
    final prefs = ref.watch(servicesProvider).prefs;
    return ProfileState(
      profile: prefs.onboardingComplete ? prefs.profile : null,
      healthAnswers: prefs.healthAnswers,
      clearance: prefs.medicalClearance,
    );
  }

  PrefsService get _prefs => ref.read(servicesProvider).prefs;

  Future<void> save(UserProfile profile) async {
    await _prefs.saveProfile(profile);
    state = ProfileState(
      profile: profile,
      healthAnswers: state.healthAnswers,
      clearance: state.clearance,
    );
  }

  Future<void> saveHealthAnswers(HealthAnswers answers) async {
    await _prefs.saveHealthAnswers(answers);
    state = ProfileState(
      profile: state.profile,
      healthAnswers: answers,
      clearance: state.clearance,
    );
  }

  Future<void> setMedicalClearance(bool confirmed) async {
    await _prefs.setMedicalClearance(confirmed);
    state = ProfileState(
      profile: state.profile,
      healthAnswers: state.healthAnswers,
      clearance: _prefs.medicalClearance,
    );
  }

  /// Reset after "delete all my data".
  void clear() {
    state = const ProfileState(
      profile: null,
      healthAnswers: HealthAnswers.empty(),
      clearance: MedicalClearance.none(),
    );
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, ProfileState>(
  ProfileNotifier.new,
);

// ------------------------------------------------------------ derived rules

/// Age gating for the current profile. Null until onboarding is done.
final ageDecisionProvider = Provider<AgeDecision?>((ref) {
  final data = ref.watch(guidelineDataProvider);
  final profile = ref.watch(profileProvider).profile;
  if (profile == null) return null;
  return AgeRules.decide(
    data: data,
    age: profile.age,
    bmiBlocksWeightLoss: Calculations.weightLossBlockedByBmi(
      data: data,
      weightKg: profile.weightKg,
      heightCm: profile.heightCm,
    ),
  );
});

final screeningResultProvider = Provider<ScreeningResult>((ref) {
  final data = ref.watch(guidelineDataProvider);
  final p = ref.watch(profileProvider);
  if (!p.healthAnswers.isAnswered) return ScreeningResult.clear;
  return HealthSafety.evaluateScreening(
    data: data,
    answers: p.healthAnswers,
    clearance: p.clearance,
  );
});

final activityTargetsProvider = Provider<ActivityTargets?>((ref) {
  final profile = ref.watch(profileProvider).profile;
  if (profile == null) return null;
  return AgeRules.activityTargets(
    data: ref.watch(guidelineDataProvider),
    age: profile.age,
  );
});

/// Experience level the plan actually uses, after the 60+ cap.
final effectiveExperienceProvider = Provider<ExperienceLevel>((ref) {
  final profile = ref.watch(profileProvider).profile;
  if (profile == null) return ExperienceLevel.beginner;
  return AgeRules.effectiveExperience(
    data: ref.watch(guidelineDataProvider),
    age: profile.age,
    stated: profile.experience,
  );
});

// -------------------------------------------------------------- entitlement

final billingStateProvider = StreamProvider<BillingState>((ref) {
  final billing = ref.watch(servicesProvider).billing;
  return billing.states;
});

/// The one flag the rest of the app reads to decide Premium access.
final isPremiumProvider = Provider<bool>((ref) {
  final services = ref.watch(servicesProvider);
  final live = ref.watch(billingStateProvider).value;
  return live?.isPremium ?? services.entitlements.isPremium;
});

final entitlementProvider = Provider<Entitlement>((ref) {
  final services = ref.watch(servicesProvider);
  return ref.watch(billingStateProvider).value?.entitlement ??
      services.entitlements.current;
});

// ------------------------------------------------------------------ targets

/// Accumulated calorie nudge and whether diet changes are frozen.
class DietAdjustment {
  const DietAdjustment({required this.kcal, required this.paused});

  final double kcal;
  final bool paused;
}

class DietAdjustmentNotifier extends Notifier<DietAdjustment> {
  @override
  DietAdjustment build() {
    final prefs = ref.watch(servicesProvider).prefs;
    return DietAdjustment(
      kcal: prefs.calorieAdjustment,
      paused: prefs.dietChangesPaused,
    );
  }

  Future<void> setPaused(bool paused) async {
    await ref.read(servicesProvider).prefs.setDietChangesPaused(paused);
    state = DietAdjustment(kcal: state.kcal, paused: paused);
  }

  Future<void> applyNudge(double deltaKcal) async {
    final next = state.kcal + deltaKcal;
    await ref.read(servicesProvider).prefs.setCalorieAdjustment(next);
    state = DietAdjustment(kcal: next, paused: state.paused);
  }

  Future<void> reset() async {
    await ref.read(servicesProvider).prefs.setCalorieAdjustment(0);
    state = DietAdjustment(kcal: 0, paused: state.paused);
  }
}

final dietAdjustmentProvider =
    NotifierProvider<DietAdjustmentNotifier, DietAdjustment>(
      DietAdjustmentNotifier.new,
    );

/// The daily nutrition target, with every safe limit already applied.
final targetsProvider = Provider<NutritionTargets?>((ref) {
  final data = ref.watch(guidelineDataProvider);
  final profile = ref.watch(profileProvider).profile;
  final decision = ref.watch(ageDecisionProvider);
  if (profile == null || decision == null) return null;

  final screening = ref.watch(screeningResultProvider);
  final adjustment = ref.watch(dietAdjustmentProvider);

  return Calculations.nutritionTargets(
    data: data,
    profile: profile,
    access: decision.access,
    weightTrendAdjustmentKcal: adjustment.kcal,
    dietChangesPaused: adjustment.paused,
    medicalClearance: !screening.blocksWeightLoss,
  );
});

// --------------------------------------------------------------- today plan

/// Latest log for every exercise, used to carry weights forward.
final latestLogsProvider = FutureProvider<Map<String, ExerciseLog>>(
  (ref) => ref.watch(servicesProvider).db.latestLogsByExercise(),
);

/// Today's session, or a rest day.
final todayPlanProvider = FutureProvider<PlannedDay?>((ref) async {
  final data = ref.watch(guidelineDataProvider);
  final profile = ref.watch(profileProvider).profile;
  final decision = ref.watch(ageDecisionProvider);
  if (profile == null || decision == null) return null;

  final premium = ref.watch(isPremiumProvider);
  final experience = ref.watch(effectiveExperienceProvider);
  final screening = ref.watch(screeningResultProvider);
  final logs = await ref.watch(latestLogsProvider.future);

  final today = DateTime.now();
  final week = PlanBuilder.weekNumber(
    planStart: profile.effectivePlanStart,
    date: today,
  );
  final isDeload = PlanBuilder.isDeloadWeek(week: week, level: experience);

  // Carry weights forward only where the user has actually logged the lift.
  final weights = <String, double>{};
  final reasons = <String, String>{};
  for (final exercise in data.exercises) {
    final suggestion = Progression.suggest(
      exercise: exercise,
      lastLog: logs[exercise.id],
      prescription: exercise.prescriptionFor(profile.goal),
      isDeloadWeek: isDeload,
    );
    if (suggestion == null) continue;
    final w = suggestion.weightKg;
    if (w != null) weights[exercise.id] = w;
    reasons[exercise.id] = suggestion.reasonKey;
  }

  return PlanBuilder.buildDay(
    data: data,
    profile: profile,
    date: today,
    effectiveExperience: experience,
    // Lighter defaults for 60+, and no high intensity while a serious
    // screening flag is outstanding.
    preferLowImpact: decision.lighterDefault || screening.blocksHighIntensity,
    premium: premium,
    previousWeights: weights,
    progressionReasons: reasons,
  );
});

/// The whole seven-day rotation, for the week strip on Home.
final weekPlanProvider = FutureProvider<WeeklyPlan?>((ref) async {
  final data = ref.watch(guidelineDataProvider);
  final profile = ref.watch(profileProvider).profile;
  final decision = ref.watch(ageDecisionProvider);
  if (profile == null || decision == null) return null;

  return PlanBuilder.buildWeek(
    data: data,
    profile: profile,
    date: DateTime.now(),
    effectiveExperience: ref.watch(effectiveExperienceProvider),
    preferLowImpact: decision.lighterDefault,
    premium: ref.watch(isPremiumProvider),
  );
});

// ------------------------------------------------------------------ history

final sessionHistoryProvider = FutureProvider<List<WorkoutSession>>(
  (ref) => ref.watch(servicesProvider).db.sessionHistory(),
);

final personalRecordsProvider = FutureProvider<List<PersonalRecord>>(
  (ref) => ref.watch(servicesProvider).db.personalRecords(),
);

final weighInsProvider = FutureProvider<List<WeighIn>>(
  (ref) => ref.watch(servicesProvider).db.weighIns(),
);

final measurementsProvider = FutureProvider<List<BodyMeasurement>>(
  (ref) => ref.watch(servicesProvider).db.measurements(),
);

final completedDaysProvider = FutureProvider<Set<DateTime>>(
  (ref) => ref.watch(servicesProvider).db.completedSessionDays(),
);

/// Current streak of consecutive weeks containing at least one session.
final weeklyStreakProvider = FutureProvider<int>((ref) async {
  final days = await ref.watch(completedDaysProvider.future);
  if (days.isEmpty) return 0;

  DateTime startOfWeek(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  final weeks = days.map(startOfWeek).toSet();
  var streak = 0;
  var cursor = startOfWeek(DateTime.now());
  while (weeks.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 7));
  }
  return streak;
});

/// Weight trend over the last check-ins, and the nudge it implies.
final weightTrendProvider = FutureProvider<WeightTrend>((ref) async {
  final profile = ref.watch(profileProvider).profile;
  if (profile == null) return WeightTrend.none;
  final weighIns = await ref.watch(weighInsProvider.future);
  return Calculations.weightTrend(
    weighIns: weighIns,
    goal: profile.goal,
    weeksRequired: ref.watch(guidelineDataProvider).stallAdjustment.weeks,
  );
});

// --------------------------------------------------------------------- diet

final foodPricesProvider = FutureProvider<Map<String, FoodPrice>>(
  (ref) => ref.watch(servicesProvider).db.foodPrices(),
);

final todayTotalsProvider = FutureProvider<DayNutritionTotals>(
  (ref) => ref.watch(servicesProvider).db.totalsForDay(DateTime.now()),
);

final todayFoodLogProvider = FutureProvider<List<FoodLogEntry>>(
  (ref) => ref.watch(servicesProvider).db.foodLogsForDay(DateTime.now()),
);

final todayWaterProvider = FutureProvider<int>(
  (ref) => ref.watch(servicesProvider).db.waterForDay(DateTime.now()),
);

/// The budget meal plan for today.
final mealPlanProvider = FutureProvider<DayMealPlan?>((ref) async {
  final profile = ref.watch(profileProvider).profile;
  final targets = ref.watch(targetsProvider);
  if (profile == null || targets == null) return null;

  final prices = await ref.watch(foodPricesProvider.future);

  return MealPlanner.plan(
    data: ref.watch(guidelineDataProvider),
    dietType: profile.dietType,
    targetKcal: targets.targetKcal,
    targetProteinG: targets.proteinG,
    monthlyBudgetInr: profile.monthlyFoodBudgetInr,
    prices: prices,
  );
});

/// Refresh everything that depends on stored records.
void invalidateRecords(WidgetRef ref) {
  ref.invalidate(latestLogsProvider);
  ref.invalidate(sessionHistoryProvider);
  ref.invalidate(personalRecordsProvider);
  ref.invalidate(weighInsProvider);
  ref.invalidate(measurementsProvider);
  ref.invalidate(completedDaysProvider);
  ref.invalidate(todayTotalsProvider);
  ref.invalidate(todayFoodLogProvider);
  ref.invalidate(todayWaterProvider);
  ref.invalidate(foodPricesProvider);
  ref.invalidate(todayPlanProvider);
  ref.invalidate(weekPlanProvider);
}
