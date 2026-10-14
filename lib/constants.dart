/// App-wide constants.
///
/// Anything that an operator may legitimately want to change without touching
/// logic lives here: Play Billing product IDs, asset paths and storage keys.
library;

/// Google Play Billing product identifiers.
///
/// These must match the subscription product IDs created in the Play Console.
/// Prices and titles are never hardcoded; they are always read from the store
/// at runtime via [BillingService].
class BillingProducts {
  const BillingProducts._();

  static const String monthly = 'premium_monthly';
  static const String yearly = 'premium_yearly';

  /// Every product the app queries from the store.
  static const Set<String> all = {monthly, yearly};

  /// Play Console subscription page the user is sent to in order to cancel.
  static const String playSubscriptionsUrl =
      'https://play.google.com/store/account/subscriptions';

  /// Deep link to the management page for one subscription of this app.
  static String manageUrl(String productId, String packageName) =>
      '$playSubscriptionsUrl?sku=$productId&package=$packageName';
}

/// Bundled data files. Nothing is fetched over the network at runtime.
class DataAssets {
  const DataAssets._();

  static const String sources = 'assets/data/sources.json';
  static const String exercises = 'assets/data/exercises.json';
  static const String foods = 'assets/data/foods_ifct2017.json';
  static const String activityGuidelines =
      'assets/data/activity_guidelines.json';
  static const String energyGuidelines = 'assets/data/energy_guidelines.json';
  static const String dietGuidelines = 'assets/data/diet_guidelines.json';
  static const String safetyRules = 'assets/data/safety_rules.json';

  static const List<String> all = [
    sources,
    exercises,
    foods,
    activityGuidelines,
    energyGuidelines,
    dietGuidelines,
    safetyRules,
  ];
}

/// Keys used in [SharedPreferences]. Changing one of these orphans existing
/// data, so they are collected here where that is obvious.
class PrefKeys {
  const PrefKeys._();

  static const String localeCode = 'locale_code';
  static const String themeMode = 'theme_mode';
  static const String weightUnit = 'weight_unit';
  static const String consentAccepted = 'consent_accepted_v1';
  static const String consentAcceptedAt = 'consent_accepted_at_v1';
  static const String profile = 'profile_v1';
  static const String healthAnswers = 'health_answers_v1';
  static const String medicalClearance = 'medical_clearance_v1';
  static const String entitlement = 'entitlement_v1';
  static const String workoutReminder = 'workout_reminder_v1';
  static const String waterReminder = 'water_reminder_v1';
  static const String dietChangesPaused = 'diet_changes_paused_v1';
  static const String calorieAdjustment = 'calorie_adjustment_v1';
  static const String onboardingComplete = 'onboarding_complete_v1';
}

/// Free versus Premium capability gates.
class Entitlements {
  const Entitlements._();

  /// Days per week a free user can plan. Free users get the 3-day full-body
  /// plan; 4 to 6 day splits are a Premium feature.
  static const int freeMaxDaysPerWeek = 3;

  /// Notification ids kept stable so reminders can be replaced, not stacked.
  static const int workoutNotificationId = 1001;
  static const int waterNotificationIdBase = 2000;

  /// Number of water reminders spread across the user's chosen window.
  static const int waterReminderCount = 6;
}

/// Rest-timer behaviour.
class TimerConfig {
  const TimerConfig._();

  /// Vibrate this many seconds before the rest timer reaches zero.
  static const int warnAtSecondsRemaining = 3;

  /// Minimum and maximum rest a user can dial in manually.
  static const int minRestSeconds = 15;
  static const int maxRestSeconds = 300;
}

/// Deload scheduling. ICMR-NIN advises increasing training load gradually; a
/// planned lighter week every fourth to sixth week keeps that gradual.
class ProgressionConfig {
  const ProgressionConfig._();

  /// Smallest plate jump assumed to be available, in kilograms.
  static const double barbellIncrementKg = 2.5;

  /// Percentage the working weight is cut when an exercise felt too hard.
  static const double tooHardReductionMin = 0.05;
  static const double tooHardReductionMax = 0.10;

  /// A deload week is scheduled every [deloadEveryWeeks] training weeks.
  static const int deloadEveryWeeksBeginner = 6;
  static const int deloadEveryWeeksIntermediate = 5;
  static const int deloadEveryWeeksAdvanced = 4;

  /// Load and volume multiplier applied during a deload week.
  static const double deloadLoadFactor = 0.6;
}
