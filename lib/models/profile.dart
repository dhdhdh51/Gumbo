import 'enums.dart';

/// Everything the user told the app about themselves during onboarding.
///
/// Stored on the device only. It is never sent anywhere.
class UserProfile {
  const UserProfile({
    required this.name,
    required this.age,
    required this.sex,
    required this.heightCm,
    required this.weightKg,
    required this.goal,
    required this.daysPerWeek,
    required this.place,
    required this.experience,
    required this.dietType,
    required this.activityLevel,
    required this.monthlyFoodBudgetInr,
    required this.createdAt,
    this.planStartDate,
  });

  final String name;
  final int age;
  final Sex sex;
  final double heightCm;
  final double weightKg;
  final Goal goal;

  /// 3 to 6. A free user is capped at 3; the provider enforces that.
  final int daysPerWeek;
  final TrainingPlace place;
  final ExperienceLevel experience;
  final DietType dietType;
  final ActivityLevel activityLevel;

  /// Monthly food budget in Indian rupees. 0 means "no budget set".
  final int monthlyFoodBudgetInr;
  final DateTime createdAt;

  /// Anchor date for split rotation and deload counting. Defaults to [createdAt].
  final DateTime? planStartDate;

  DateTime get effectivePlanStart => planStartDate ?? createdAt;

  /// BMI in kg/m². Returns null for a non-sensical height.
  double? get bmi {
    if (heightCm <= 50) return null;
    final m = heightCm / 100.0;
    return weightKg / (m * m);
  }

  UserProfile copyWith({
    String? name,
    int? age,
    Sex? sex,
    double? heightCm,
    double? weightKg,
    Goal? goal,
    int? daysPerWeek,
    TrainingPlace? place,
    ExperienceLevel? experience,
    DietType? dietType,
    ActivityLevel? activityLevel,
    int? monthlyFoodBudgetInr,
    DateTime? planStartDate,
  }) {
    return UserProfile(
      name: name ?? this.name,
      age: age ?? this.age,
      sex: sex ?? this.sex,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      goal: goal ?? this.goal,
      daysPerWeek: daysPerWeek ?? this.daysPerWeek,
      place: place ?? this.place,
      experience: experience ?? this.experience,
      dietType: dietType ?? this.dietType,
      activityLevel: activityLevel ?? this.activityLevel,
      monthlyFoodBudgetInr: monthlyFoodBudgetInr ?? this.monthlyFoodBudgetInr,
      createdAt: createdAt,
      planStartDate: planStartDate ?? this.planStartDate,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'age': age,
    'sex': sex.name,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'goal': goal.name,
    'daysPerWeek': daysPerWeek,
    'place': place.name,
    'experience': experience.name,
    'dietType': dietType.name,
    'activityLevel': activityLevel.name,
    'monthlyFoodBudgetInr': monthlyFoodBudgetInr,
    'createdAt': createdAt.toIso8601String(),
    'planStartDate': planStartDate?.toIso8601String(),
  };

  static UserProfile fromJson(Map<String, dynamic> j) => UserProfile(
    name: (j['name'] as String?) ?? '',
    age: (j['age'] as num?)?.toInt() ?? 0,
    sex: Sex.fromName((j['sex'] as String?) ?? 'male'),
    heightCm: (j['heightCm'] as num?)?.toDouble() ?? 0,
    weightKg: (j['weightKg'] as num?)?.toDouble() ?? 0,
    goal: Goal.fromName((j['goal'] as String?) ?? 'maintain'),
    daysPerWeek: (j['daysPerWeek'] as num?)?.toInt() ?? 3,
    place: TrainingPlace.fromName((j['place'] as String?) ?? 'home'),
    experience: ExperienceLevel.fromName(
      (j['experience'] as String?) ?? 'beginner',
    ),
    dietType: DietType.fromName((j['dietType'] as String?) ?? 'veg'),
    activityLevel: ActivityLevel.fromName(
      (j['activityLevel'] as String?) ?? 'sedentary',
    ),
    monthlyFoodBudgetInr: (j['monthlyFoodBudgetInr'] as num?)?.toInt() ?? 0,
    createdAt:
        DateTime.tryParse((j['createdAt'] as String?) ?? '') ?? DateTime.now(),
    planStartDate: DateTime.tryParse((j['planStartDate'] as String?) ?? ''),
  );
}

/// Answers to the onboarding pre-exercise screening questionnaire.
class HealthAnswers {
  const HealthAnswers({
    required this.answers,
    required this.notes,
    required this.answeredAt,
  });

  const HealthAnswers.empty()
    : answers = const {},
      notes = '',
      answeredAt = null;

  /// Item id from safety_rules.json -> yes or no.
  final Map<String, bool> answers;

  /// Free-text note for "any other health problem".
  final String notes;
  final DateTime? answeredAt;

  bool get isAnswered => answeredAt != null;

  bool yesFor(String id) => answers[id] ?? false;

  Iterable<String> get yesIds =>
      answers.entries.where((e) => e.value).map((e) => e.key);

  HealthAnswers copyWith({Map<String, bool>? answers, String? notes}) =>
      HealthAnswers(
        answers: answers ?? this.answers,
        notes: notes ?? this.notes,
        answeredAt: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
    'answers': answers,
    'notes': notes,
    'answeredAt': answeredAt?.toIso8601String(),
  };

  static HealthAnswers fromJson(Map<String, dynamic> j) => HealthAnswers(
    answers: ((j['answers'] as Map?) ?? {}).map(
      (k, v) => MapEntry(k.toString(), v == true),
    ),
    notes: (j['notes'] as String?) ?? '',
    answeredAt: DateTime.tryParse((j['answeredAt'] as String?) ?? ''),
  );
}

/// Whether the user has told the app a doctor cleared them to train.
///
/// The app never verifies this. It is a deliberate, explicit confirmation that
/// unlocks weight-loss targets and higher intensity after a screening flag.
class MedicalClearance {
  const MedicalClearance({required this.confirmed, required this.confirmedAt});

  const MedicalClearance.none() : confirmed = false, confirmedAt = null;

  final bool confirmed;
  final DateTime? confirmedAt;

  Map<String, dynamic> toJson() => {
    'confirmed': confirmed,
    'confirmedAt': confirmedAt?.toIso8601String(),
  };

  static MedicalClearance fromJson(Map<String, dynamic> j) => MedicalClearance(
    confirmed: j['confirmed'] == true,
    confirmedAt: DateTime.tryParse((j['confirmedAt'] as String?) ?? ''),
  );
}
