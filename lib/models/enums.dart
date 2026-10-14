/// Shared enumerations. Every enum serialises by its [name] so stored data
/// stays readable in the JSON export.
library;

enum Sex {
  male,
  female;

  static Sex fromName(String v) =>
      Sex.values.firstWhere((e) => e.name == v, orElse: () => Sex.male);
}

enum Goal {
  gain,
  lose,
  maintain;

  static Goal fromName(String v) =>
      Goal.values.firstWhere((e) => e.name == v, orElse: () => Goal.maintain);
}

enum TrainingPlace {
  gym,
  home;

  static TrainingPlace fromName(String v) => TrainingPlace.values.firstWhere(
    (e) => e.name == v,
    orElse: () => TrainingPlace.home,
  );
}

enum ExperienceLevel {
  beginner,
  intermediate,
  advanced;

  static ExperienceLevel fromName(String v) => ExperienceLevel.values
      .firstWhere((e) => e.name == v, orElse: () => ExperienceLevel.beginner);

  /// Ordering helper so a plan can include anything at or below the user's level.
  int get rank => switch (this) {
    ExperienceLevel.beginner => 0,
    ExperienceLevel.intermediate => 1,
    ExperienceLevel.advanced => 2,
  };
}

enum DietType {
  veg,
  egg,
  nonVeg;

  static DietType fromName(String v) => DietType.values.firstWhere(
    (e) => e.name == v,
    orElse: () => DietType.veg,
  );

  /// Which food diet tags this diet type is allowed to eat.
  Set<String> get allowedFoodTags => switch (this) {
    DietType.veg => const {'veg'},
    DietType.egg => const {'veg', 'egg'},
    DietType.nonVeg => const {'veg', 'egg', 'nonveg'},
  };
}

/// Activity levels exactly as published by ICMR-NIN (2020): sedentary,
/// moderate and heavy work. No extra levels are invented.
enum ActivityLevel {
  sedentary,
  moderate,
  heavy;

  static ActivityLevel fromName(String v) => ActivityLevel.values.firstWhere(
    (e) => e.name == v,
    orElse: () => ActivityLevel.sedentary,
  );
}

/// How an exercise felt, collected after every exercise. Drives overload.
enum SetFeedback {
  tooEasy,
  justRight,
  tooHard;

  static SetFeedback fromName(String v) => SetFeedback.values.firstWhere(
    (e) => e.name == v,
    orElse: () => SetFeedback.justRight,
  );
}

enum WeightUnit {
  kg,
  lb;

  static WeightUnit fromName(String v) => WeightUnit.values.firstWhere(
    (e) => e.name == v,
    orElse: () => WeightUnit.kg,
  );

  static const double _lbPerKg = 2.20462262;

  double fromKg(double kg) => this == WeightUnit.kg ? kg : kg * _lbPerKg;

  double toKg(double value) => this == WeightUnit.kg ? value : value / _lbPerKg;
}

/// What the app is allowed to do for this user, decided purely by age.
enum AccessLevel {
  /// Under 13: the app is blocked with a message to involve a parent and doctor.
  blocked,

  /// 13 to 17: activity guidance only. No calorie deficit, no weight-loss target.
  activityOnly,

  /// 18 to 59: all features.
  full,

  /// 60 and over: all features, but lighter default intensity and a stronger
  /// notice to speak to a doctor.
  fullLighterDefault;

  bool get isUsable => this != AccessLevel.blocked;

  bool get allowsCalorieDeficit =>
      this == AccessLevel.full || this == AccessLevel.fullLighterDefault;
}

/// A day in a generated week: either a training day with a label, or rest.
enum SplitType {
  fullBody,
  upperLower,
  pushPullLegs;

  static SplitType fromName(String v) => SplitType.values.firstWhere(
    (e) => e.name == v,
    orElse: () => SplitType.fullBody,
  );
}

enum MealSlot {
  breakfast,
  lunch,
  snack,
  dinner;

  static MealSlot fromName(String v) => MealSlot.values.firstWhere(
    (e) => e.name == v,
    orElse: () => MealSlot.breakfast,
  );
}

/// Outcome of the pre-workout health check.
enum PreWorkoutOutcome {
  /// No problems reported: run the planned session.
  proceedNormal,

  /// Something reported: only light activity is offered.
  lightActivityOnly,

  /// User chose to skip today.
  skipToday,

  /// A red flag was reported: stop and seek medical help now.
  seekHelpNow,
}

enum PurchaseUiState {
  idle,
  loadingProducts,
  productsUnavailable,
  pending,
  purchased,
  restored,
  canceled,
  error,
}
