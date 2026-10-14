import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../constants.dart';
import '../models/guideline_data.dart';

/// Loads the bundled reference data once, from local assets only.
///
/// The app makes no network calls at runtime. Nothing here scrapes a website.
class DataRepository {
  DataRepository._(this.data);

  final GuidelineData data;

  static DataRepository? _instance;

  /// The loaded repository. Throws if [load] has not completed yet.
  static DataRepository get instance {
    final i = _instance;
    if (i == null) {
      throw StateError('DataRepository.load() must complete before use');
    }
    return i;
  }

  static Future<DataRepository> load() async {
    if (_instance != null) return _instance!;

    Future<Map<String, dynamic>> read(String path) async {
      final raw = await rootBundle.loadString(path);
      return jsonDecode(raw) as Map<String, dynamic>;
    }

    final results = await Future.wait([
      read(DataAssets.sources),
      read(DataAssets.activityGuidelines),
      read(DataAssets.energyGuidelines),
      read(DataAssets.dietGuidelines),
      read(DataAssets.safetyRules),
      read(DataAssets.exercises),
      read(DataAssets.foods),
    ]);

    final data = GuidelineData.parse({
      'sources': results[0],
      'activity_guidelines': results[1],
      'energy_guidelines': results[2],
      'diet_guidelines': results[3],
      'safety_rules': results[4],
      'exercises': results[5],
      'foods_ifct2017': results[6],
    });

    return _instance = DataRepository._(data);
  }
}
