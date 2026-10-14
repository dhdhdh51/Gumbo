import 'dart:convert';
import 'dart:io';

import 'package:trainerapp/models/enums.dart';
import 'package:trainerapp/models/guideline_data.dart';
import 'package:trainerapp/models/profile.dart';

/// Loads the real bundled data files straight off disk.
///
/// The tests deliberately run against the shipped assets rather than fixtures,
/// so a bad number or a broken schema in assets/data fails the build.
GuidelineData loadGuidelineData() {
  Map<String, dynamic> read(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  return GuidelineData.parse({
    'sources': read('assets/data/sources.json'),
    'activity_guidelines': read('assets/data/activity_guidelines.json'),
    'energy_guidelines': read('assets/data/energy_guidelines.json'),
    'diet_guidelines': read('assets/data/diet_guidelines.json'),
    'safety_rules': read('assets/data/safety_rules.json'),
    'exercises': read('assets/data/exercises.json'),
    'foods_ifct2017': read('assets/data/foods_ifct2017.json'),
  });
}

/// A plain adult profile that individual tests tweak with copyWith.
UserProfile testProfile({
  int age = 30,
  Sex sex = Sex.male,
  double heightCm = 175,
  double weightKg = 70,
  Goal goal = Goal.maintain,
  int daysPerWeek = 3,
  TrainingPlace place = TrainingPlace.gym,
  ExperienceLevel experience = ExperienceLevel.beginner,
  DietType dietType = DietType.veg,
  ActivityLevel activityLevel = ActivityLevel.sedentary,
  int budget = 0,
  DateTime? planStart,
}) {
  final start = planStart ?? DateTime(2026, 1, 5); // a Monday
  return UserProfile(
    name: 'Test',
    age: age,
    sex: sex,
    heightCm: heightCm,
    weightKg: weightKg,
    goal: goal,
    daysPerWeek: daysPerWeek,
    place: place,
    experience: experience,
    dietType: dietType,
    activityLevel: activityLevel,
    monthlyFoodBudgetInr: budget,
    createdAt: start,
    planStartDate: start,
  );
}
