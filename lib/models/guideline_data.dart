import 'enums.dart';
import 'exercise.dart';
import 'food.dart';
import 'guidelines.dart';

/// All shipped reference data, parsed once at startup.
///
/// This class is deliberately free of Flutter imports so that the pure logic in
/// `services/` and the unit tests can build it straight from decoded JSON.
class GuidelineData {
  const GuidelineData({
    required this.sources,
    required this.servingSourceLabels,
    required this.activityBands,
    required this.indiaActivityNotes,
    required this.medicalClearanceNotes,
    required this.bmrFormulaSourceId,
    required this.activityEnergy,
    required this.adultProtein,
    required this.adolescentProtein,
    required this.referenceEnergyByAge,
    required this.trainingProteinRange,
    required this.whoProteinPercentEnergy,
    required this.cerealDietProteinGPerKg,
    required this.macroRanges,
    required this.dietLimits,
    required this.dietTargets,
    required this.myPlateGroups,
    required this.bmiCutoffs,
    required this.disclaimer,
    required this.ageRules,
    required this.screeningItems,
    required this.screeningNote,
    required this.redFlagKeys,
    required this.calorieSafety,
    required this.weightSafety,
    required this.stallAdjustment,
    required this.exercises,
    required this.foods,
  });

  final Map<String, DataSource> sources;
  final Map<String, String> servingSourceLabels;

  // Activity
  final List<ActivityBand> activityBands;
  final List<GuidelineNote> indiaActivityNotes;
  final List<GuidelineNote> medicalClearanceNotes;

  // Energy
  final String bmrFormulaSourceId;
  final Map<ActivityLevel, ActivityLevelEnergy> activityEnergy;
  final List<ProteinRequirement> adultProtein;
  final List<ProteinRequirement> adolescentProtein;
  final List<Map<String, dynamic>> referenceEnergyByAge;
  final SourcedRange trainingProteinRange;
  final SourcedRange whoProteinPercentEnergy;
  final SourcedValue cerealDietProteinGPerKg;

  // Diet
  final List<DietTarget> macroRanges;
  final List<DietTarget> dietLimits;
  final List<DietTarget> dietTargets;
  final List<Map<String, dynamic>> myPlateGroups;
  final BmiCutoffs bmiCutoffs;

  // Safety
  final String disclaimer;
  final List<AgeRule> ageRules;
  final List<ScreeningItem> screeningItems;
  final String screeningNote;
  final List<String> redFlagKeys;
  final Map<String, SourcedValue> calorieSafety;
  final Map<String, SourcedValue> weightSafety;

  /// Calorie nudge applied when weight has not moved for two check-ins.
  final ({double min, double max, int weeks}) stallAdjustment;

  // Libraries
  final List<Exercise> exercises;
  final List<Food> foods;

  DataSource? source(String? id) => id == null ? null : sources[id];

  Exercise? exerciseById(String id) {
    for (final e in exercises) {
      if (e.id == id) return e;
    }
    return null;
  }

  Food? foodById(String id) {
    for (final f in foods) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// The WHO age band that covers [age], falling back to the adult band.
  ActivityBand bandForAge(int age) {
    for (final b in activityBands) {
      if (b.matchesAge(age)) return b;
    }
    return activityBands.firstWhere(
      (b) => b.id == 'adult_18_64',
      orElse: () => activityBands.first,
    );
  }

  AgeRule ruleForAge(int age) {
    for (final r in ageRules) {
      if (r.matchesAge(age)) return r;
    }
    // Defensive: treat an unmatched age as blocked rather than as full access.
    return ageRules.firstWhere(
      (r) => r.accessLevel == AccessLevel.blocked,
      orElse: () => ageRules.first,
    );
  }

  DietTarget? dietTargetById(String id) {
    for (final t in [...dietTargets, ...dietLimits, ...macroRanges]) {
      if (t.id == id) return t;
    }
    return null;
  }

  ScreeningItem? screeningItem(String id) {
    for (final i in screeningItems) {
      if (i.id == id) return i;
    }
    return null;
  }

  /// Build from the decoded contents of the seven bundled JSON files, keyed by
  /// dataset name: sources, activity_guidelines, energy_guidelines,
  /// diet_guidelines, safety_rules, exercises, foods_ifct2017.
  static GuidelineData parse(Map<String, Map<String, dynamic>> raw) {
    Map<String, dynamic> need(String key) {
      final v = raw[key];
      if (v == null) throw StateError('missing bundled dataset: $key');
      return v;
    }

    final sourcesJson = need('sources');
    final activityJson = need('activity_guidelines');
    final energyJson = need('energy_guidelines');
    final dietJson = need('diet_guidelines');
    final safetyJson = need('safety_rules');
    final exerciseJson = need('exercises');
    final foodJson = need('foods_ifct2017');

    final sources = <String, DataSource>{};
    for (final s in sourcesJson['sources'] as List) {
      final src = DataSource.fromJson((s as Map).cast<String, dynamic>());
      sources[src.id] = src;
    }

    final servingLabels = <String, String>{};
    for (final s in (sourcesJson['servingSources'] as List? ?? const [])) {
      final m = (s as Map).cast<String, dynamic>();
      servingLabels[m['id'] as String] = m['label'] as String;
    }

    final activityEnergy = <ActivityLevel, ActivityLevelEnergy>{};
    for (final l in energyJson['activityLevels'] as List) {
      final e = ActivityLevelEnergy.fromJson(
        (l as Map).cast<String, dynamic>(),
      );
      activityEnergy[ActivityLevel.fromName(e.id)] = e;
    }

    final proteinJson = (energyJson['protein'] as Map).cast<String, dynamic>();

    List<DietTarget> targets(Object? list) =>
        ((list as List?) ?? const [])
            .map((e) => DietTarget.fromJson((e as Map).cast<String, dynamic>()))
            .toList();

    Map<String, SourcedValue> sourcedMap(Map<String, dynamic> m) {
      final out = <String, SourcedValue>{};
      for (final e in m.entries) {
        final v = e.value;
        if (v is Map && v['value'] is num) {
          out[e.key] = SourcedValue.fromJson(v.cast<String, dynamic>());
        }
      }
      return out;
    }

    final calorieSafetyJson =
        (safetyJson['calorieSafety'] as Map).cast<String, dynamic>();
    final weightSafetyJson =
        (safetyJson['weightChangeSafety'] as Map).cast<String, dynamic>();
    final stallJson =
        (calorieSafetyJson['stallAdjustmentKcal'] as Map)
            .cast<String, dynamic>();

    final questionnaire =
        (safetyJson['questionnaire'] as Map).cast<String, dynamic>();
    final dailyCheck =
        (safetyJson['dailyCheck'] as Map).cast<String, dynamic>();

    return GuidelineData(
      sources: sources,
      servingSourceLabels: servingLabels,
      activityBands:
          (activityJson['ageBands'] as List)
              .map(
                (e) =>
                    ActivityBand.fromJson((e as Map).cast<String, dynamic>()),
              )
              .toList(),
      indiaActivityNotes: const [],
      medicalClearanceNotes:
          (activityJson['medicalClearanceNotes'] as List)
              .map(
                (e) =>
                    GuidelineNote.fromJson((e as Map).cast<String, dynamic>()),
              )
              .toList(),
      bmrFormulaSourceId:
          (energyJson['bmrEquation'] as Map)['sourceId'] as String,
      activityEnergy: activityEnergy,
      adultProtein:
          (proteinJson['adults'] as List)
              .map(
                (e) => ProteinRequirement.fromJson(
                  (e as Map).cast<String, dynamic>(),
                ),
              )
              .toList(),
      adolescentProtein:
          (proteinJson['adolescents'] as List)
              .map(
                (e) => ProteinRequirement.fromJson(
                  (e as Map).cast<String, dynamic>(),
                ),
              )
              .toList(),
      referenceEnergyByAge:
          ((energyJson['referenceEnergyByAge'] as List?) ?? const [])
              .map((e) => (e as Map).cast<String, dynamic>())
              .toList(),
      trainingProteinRange: SourcedRange.fromJson(
        (proteinJson['trainingAdultsGPerKg'] as Map).cast<String, dynamic>(),
      ),
      whoProteinPercentEnergy: SourcedRange(
        min:
            ((proteinJson['whoEnergyShare'] as Map)['minPercentEnergy'] as num)
                .toDouble(),
        max:
            ((proteinJson['whoEnergyShare'] as Map)['maxPercentEnergy'] as num)
                .toDouble(),
        sourceId: (proteinJson['whoEnergyShare'] as Map)['sourceId'] as String,
        note: (proteinJson['whoEnergyShare'] as Map)['note'] as String?,
      ),
      cerealDietProteinGPerKg: SourcedValue.fromJson(
        (proteinJson['cerealBasedDietGPerKg'] as Map).cast<String, dynamic>(),
      ),
      macroRanges: targets(dietJson['macronutrientRanges']),
      dietLimits: targets(dietJson['limits']),
      dietTargets: targets(dietJson['targets']),
      myPlateGroups:
          (((dietJson['myPlate2000Kcal'] as Map)['groups'] as List?) ??
                  const [])
              .map((e) => (e as Map).cast<String, dynamic>())
              .toList(),
      bmiCutoffs: BmiCutoffs.fromJson(
        (dietJson['bmiCutoffs'] as Map).cast<String, dynamic>(),
      ),
      disclaimer: (safetyJson['disclaimer'] as Map)['text'] as String,
      ageRules:
          (safetyJson['ageRules'] as List)
              .map((e) => AgeRule.fromJson((e as Map).cast<String, dynamic>()))
              .toList(),
      screeningItems:
          (questionnaire['items'] as List)
              .map(
                (e) =>
                    ScreeningItem.fromJson((e as Map).cast<String, dynamic>()),
              )
              .toList(),
      screeningNote: (questionnaire['note'] as String?) ?? '',
      redFlagKeys:
          ((dailyCheck['redFlags'] as List?) ?? const [])
              .map((e) => ((e as Map)['id']).toString())
              .toList(),
      calorieSafety: sourcedMap(calorieSafetyJson),
      weightSafety: sourcedMap(weightSafetyJson),
      stallAdjustment: (
        min: (stallJson['min'] as num).toDouble(),
        max: (stallJson['max'] as num).toDouble(),
        weeks: (stallJson['weeksBeforeAdjust'] as num).toInt(),
      ),
      exercises:
          (exerciseJson['exercises'] as List)
              .map((e) => Exercise.fromJson((e as Map).cast<String, dynamic>()))
              .toList(),
      foods:
          (foodJson['foods'] as List)
              .map((e) => Food.fromJson((e as Map).cast<String, dynamic>()))
              .toList(),
    );
  }
}
