import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../models/entitlement.dart';
import '../models/enums.dart';
import '../models/profile.dart';

/// A reminder the user configured, with the time of day it fires.
class ReminderSetting {
  const ReminderSetting({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  const ReminderSetting.disabled() : enabled = false, hour = 7, minute = 0;

  final bool enabled;
  final int hour;
  final int minute;

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'hour': hour,
    'minute': minute,
  };

  static ReminderSetting fromJson(Map<String, dynamic> j) => ReminderSetting(
    enabled: j['enabled'] == true,
    hour: (j['hour'] as num?)?.toInt() ?? 7,
    minute: (j['minute'] as num?)?.toInt() ?? 0,
  );
}

/// Small key-value settings and the single user profile.
///
/// Time-series data (sessions, sets, weigh-ins, meals, water, prices) lives in
/// SQLite instead; see [AppDatabase]. Nothing here ever leaves the device.
class PrefsService {
  PrefsService(this._prefs);

  final SharedPreferences _prefs;

  static Future<PrefsService> load() async =>
      PrefsService(await SharedPreferences.getInstance());

  // ------------------------------------------------------------- app settings

  String? get localeCode => _prefs.getString(PrefKeys.localeCode);

  Future<void> setLocaleCode(String? code) async {
    if (code == null) {
      await _prefs.remove(PrefKeys.localeCode);
    } else {
      await _prefs.setString(PrefKeys.localeCode, code);
    }
  }

  ThemeMode get themeMode => switch (_prefs.getString(PrefKeys.themeMode)) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setString(PrefKeys.themeMode, mode.name);

  WeightUnit get weightUnit =>
      WeightUnit.fromName(_prefs.getString(PrefKeys.weightUnit) ?? 'kg');

  Future<void> setWeightUnit(WeightUnit unit) =>
      _prefs.setString(PrefKeys.weightUnit, unit.name);

  // ----------------------------------------------------------------- consent

  bool get consentAccepted => _prefs.getBool(PrefKeys.consentAccepted) ?? false;

  DateTime? get consentAcceptedAt =>
      DateTime.tryParse(_prefs.getString(PrefKeys.consentAcceptedAt) ?? '');

  Future<void> acceptConsent() async {
    await _prefs.setBool(PrefKeys.consentAccepted, true);
    await _prefs.setString(
      PrefKeys.consentAcceptedAt,
      DateTime.now().toIso8601String(),
    );
  }

  // ----------------------------------------------------------------- profile

  bool get onboardingComplete =>
      _prefs.getBool(PrefKeys.onboardingComplete) ?? false;

  UserProfile? get profile {
    final raw = _prefs.getString(PrefKeys.profile);
    if (raw == null) return null;
    try {
      return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return null;
    }
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _prefs.setString(PrefKeys.profile, jsonEncode(profile.toJson()));
    await _prefs.setBool(PrefKeys.onboardingComplete, true);
  }

  HealthAnswers get healthAnswers {
    final raw = _prefs.getString(PrefKeys.healthAnswers);
    if (raw == null) return const HealthAnswers.empty();
    try {
      return HealthAnswers.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return const HealthAnswers.empty();
    }
  }

  Future<void> saveHealthAnswers(HealthAnswers answers) =>
      _prefs.setString(PrefKeys.healthAnswers, jsonEncode(answers.toJson()));

  MedicalClearance get medicalClearance {
    final raw = _prefs.getString(PrefKeys.medicalClearance);
    if (raw == null) return const MedicalClearance.none();
    try {
      return MedicalClearance.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return const MedicalClearance.none();
    }
  }

  Future<void> setMedicalClearance(bool confirmed) => _prefs.setString(
    PrefKeys.medicalClearance,
    jsonEncode(
      MedicalClearance(
        confirmed: confirmed,
        confirmedAt: confirmed ? DateTime.now() : null,
      ).toJson(),
    ),
  );

  // ------------------------------------------------------------- entitlement

  Entitlement get entitlement {
    final raw = _prefs.getString(PrefKeys.entitlement);
    if (raw == null) return const Entitlement.free();
    try {
      return Entitlement.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return const Entitlement.free();
    }
  }

  Future<void> saveEntitlement(Entitlement e) =>
      _prefs.setString(PrefKeys.entitlement, jsonEncode(e.toJson()));

  // --------------------------------------------------------------- reminders

  ReminderSetting get workoutReminder => _reminder(PrefKeys.workoutReminder);

  ReminderSetting get waterReminder => _reminder(PrefKeys.waterReminder);

  ReminderSetting _reminder(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return const ReminderSetting.disabled();
    try {
      return ReminderSetting.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return const ReminderSetting.disabled();
    }
  }

  Future<void> setWorkoutReminder(ReminderSetting r) =>
      _prefs.setString(PrefKeys.workoutReminder, jsonEncode(r.toJson()));

  Future<void> setWaterReminder(ReminderSetting r) =>
      _prefs.setString(PrefKeys.waterReminder, jsonEncode(r.toJson()));

  // --------------------------------------------------------- diet adjustment

  /// True after the user reported a new health problem at a weekly check-in.
  /// Automatic calorie changes stay frozen until they clear it.
  bool get dietChangesPaused =>
      _prefs.getBool(PrefKeys.dietChangesPaused) ?? false;

  Future<void> setDietChangesPaused(bool paused) =>
      _prefs.setBool(PrefKeys.dietChangesPaused, paused);

  /// Accumulated calorie nudge from stalled weekly check-ins.
  double get calorieAdjustment =>
      _prefs.getDouble(PrefKeys.calorieAdjustment) ?? 0;

  Future<void> setCalorieAdjustment(double kcal) =>
      _prefs.setDouble(PrefKeys.calorieAdjustment, kcal);

  // --------------------------------------------------------------- lifecycle

  /// Everything this service holds, for the data export.
  Map<String, dynamic> exportAll() => {
    'localeCode': localeCode,
    'themeMode': themeMode.name,
    'weightUnit': weightUnit.name,
    'consentAccepted': consentAccepted,
    'consentAcceptedAt': consentAcceptedAt?.toIso8601String(),
    'profile': profile?.toJson(),
    'healthAnswers': healthAnswers.toJson(),
    'medicalClearance': medicalClearance.toJson(),
    'workoutReminder': workoutReminder.toJson(),
    'waterReminder': waterReminder.toJson(),
    'dietChangesPaused': dietChangesPaused,
    'calorieAdjustment': calorieAdjustment,
    // The entitlement is intentionally excluded: it is a Play Billing fact,
    // not user health data, and is re-derived from the store on launch.
  };

  /// Wipe everything this service holds. Used by "delete all my data".
  Future<void> clearAll() async {
    for (final key in [
      PrefKeys.profile,
      PrefKeys.healthAnswers,
      PrefKeys.medicalClearance,
      PrefKeys.onboardingComplete,
      PrefKeys.consentAccepted,
      PrefKeys.consentAcceptedAt,
      PrefKeys.workoutReminder,
      PrefKeys.waterReminder,
      PrefKeys.dietChangesPaused,
      PrefKeys.calorieAdjustment,
    ]) {
      await _prefs.remove(key);
    }
  }
}
