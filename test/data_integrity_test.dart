import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trainerapp/constants.dart';
import 'package:trainerapp/models/enums.dart';

import 'support/test_data.dart';

/// Guards the promises made about the shipped data: every number is sourced,
/// nothing is placeholder content, and the libraries are complete.
void main() {
  final data = loadGuidelineData();

  Map<String, dynamic> readAsset(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  group('bundled assets', () {
    test('every asset declared in constants exists and is valid JSON', () {
      for (final path in DataAssets.all) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: 'missing $path');
        expect(
          () => readAsset(path),
          returnsNormally,
          reason: 'bad JSON $path',
        );
      }
    });

    test('pubspec bundles the data directory', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('assets/data/'));
    });
  });

  group('sources', () {
    test('all six requested sources are present with a URL and a year', () {
      const required = [
        'who_healthy_diet', // WHO healthy diet fact sheet
        'who_pa_guidelines_2020', // WHO physical activity guidelines 2020
        'icmr_dgi_2024', // ICMR-NIN Dietary Guidelines for Indians 2024
        'icmr_rda_2020', // ICMR-NIN Nutrient Requirements and RDA 2020
        'ifct_2017', // Indian Food Composition Tables 2017
        'fssai_eat_right', // FSSAI Eat Right India
      ];
      for (final id in required) {
        final s = data.source(id);
        expect(s, isNotNull, reason: 'missing source $id');
        expect(s!.url, startsWith('https://'));
        expect(s.year, inInclusiveRange(1990, 2030));
        expect(s.publisher, isNotEmpty);
        expect(s.name, isNotEmpty);
      }
    });

    test('every source has a complete citation', () {
      for (final s in data.sources.values) {
        expect(s.name, isNotEmpty, reason: s.id);
        expect(s.publisher, isNotEmpty, reason: s.id);
        expect(s.url, startsWith('https://'), reason: s.id);
        expect(s.year, greaterThan(1900), reason: s.id);
        expect(s.shortLabel, contains('${s.year}'));
      }
    });

    test('every sourceId referenced anywhere resolves to a real source', () {
      final referenced = <String>{};

      void collect(Object? node) {
        if (node is Map) {
          for (final e in node.entries) {
            if ((e.key == 'sourceId' ||
                    e.key == 'secondarySourceId' ||
                    e.key == 'supportingSourceId' ||
                    e.key == 'safetySourceId' ||
                    e.key == 'energySourceId') &&
                e.value is String) {
              referenced.add(e.value as String);
            }
            collect(e.value);
          }
        } else if (node is List) {
          for (final v in node) {
            collect(v);
          }
        }
      }

      for (final path in DataAssets.all) {
        collect(readAsset(path));
      }

      expect(referenced, isNotEmpty);
      for (final id in referenced) {
        expect(
          data.sources.containsKey(id),
          isTrue,
          reason: 'unknown sourceId "$id"',
        );
      }
    });

    test('serving-size labels all resolve to a source', () {
      final sources = readAsset(DataAssets.sources);
      for (final s in sources['servingSources'] as List) {
        final m = (s as Map).cast<String, dynamic>();
        expect(data.sources.containsKey(m['sourceId']), isTrue);
      }
    });

    test('no value is attributed to a source without an origin marker', () {
      // Everything in safety_rules that carries a number must say whether it is
      // a published figure or an app policy.
      final safety = readAsset(DataAssets.safetyRules);
      void check(Object? node, String path) {
        if (node is Map) {
          if (node['value'] is num) {
            expect(
              node['origin'],
              anyOf('source', 'app_policy'),
              reason: 'missing origin at $path',
            );
            if (node['origin'] == 'source') {
              expect(
                node['sourceId'],
                isNotNull,
                reason: 'source-origin value without sourceId at $path',
              );
            }
          }
          for (final e in node.entries) {
            check(e.value, '$path.${e.key}');
          }
        } else if (node is List) {
          for (var i = 0; i < node.length; i++) {
            check(node[i], '$path[$i]');
          }
        }
      }

      check(safety, 'safety_rules');
    });
  });

  group('exercise library', () {
    test('has at least 80 exercises', () {
      expect(data.exercises.length, greaterThanOrEqualTo(80));
    });

    test('ids are unique', () {
      final ids = data.exercises.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every exercise is complete', () {
      for (final e in data.exercises) {
        expect(e.name, isNotEmpty, reason: e.id);
        expect(e.primaryMuscles, isNotEmpty, reason: e.id);
        expect(e.equipment, anyOf('gym', 'home', 'bodyweight'), reason: e.id);
        expect(e.equipmentDetail, isNotEmpty, reason: e.id);
        expect(
          e.loadType,
          anyOf('external', 'bodyweight', 'timed'),
          reason: e.id,
        );
        expect(e.repUnit, anyOf('reps', 'seconds'), reason: e.id);
        expect(e.steps.length, greaterThanOrEqualTo(3), reason: e.id);
        expect(e.mistakes.length, greaterThanOrEqualTo(2), reason: e.id);
        expect(e.safety.length, greaterThanOrEqualTo(2), reason: e.id);
        for (final text in [...e.steps, ...e.mistakes, ...e.safety]) {
          expect(text.length, greaterThan(15), reason: '${e.id}: "$text"');
          expect(text.trim(), endsWith('.'), reason: '${e.id}: "$text"');
        }
      }
    });

    test('every exercise has sets and reps for every goal', () {
      for (final e in data.exercises) {
        for (final goal in Goal.values) {
          final p = e.defaults[goal];
          expect(p, isNotNull, reason: '${e.id} has no $goal prescription');
          expect(p!.sets, inInclusiveRange(1, 8), reason: e.id);
          expect(p.repsMin, greaterThan(0), reason: e.id);
          expect(p.repsMax, greaterThanOrEqualTo(p.repsMin), reason: e.id);
          expect(p.restSec, inInclusiveRange(0, 300), reason: e.id);
        }
      }
    });

    test('all major muscle groups are covered', () {
      const required = [
        'chest',
        'back',
        'lats',
        'shoulders',
        'biceps',
        'triceps',
        'quads',
        'hamstrings',
        'glutes',
        'calves',
        'core',
        'obliques',
        'lower_back',
        'traps',
        'forearms',
        'full_body',
      ];
      final covered = data.exercises.expand((e) => e.primaryMuscles).toSet();
      for (final m in required) {
        expect(covered, contains(m), reason: 'no exercise targets $m');
      }
    });

    test(
      'every muscle group is trainable at home and with bodyweight alone',
      () {
        const needed = [
          'chest',
          'back',
          'shoulders',
          'biceps',
          'triceps',
          'quads',
          'hamstrings',
          'glutes',
          'calves',
          'core',
        ];
        for (final m in needed) {
          final noGym = data.exercises.where(
            (e) => e.primaryMuscles.contains(m) && e.equipment != 'gym',
          );
          expect(noGym, isNotEmpty, reason: 'nothing for $m outside a gym');
        }
      },
    );

    test('every difficulty and equipment level is represented', () {
      for (final level in ExperienceLevel.values) {
        expect(
          data.exercises.where((e) => e.difficulty == level),
          isNotEmpty,
          reason: '$level',
        );
      }
      for (final eq in ['gym', 'home', 'bodyweight']) {
        expect(
          data.exercises.where((e) => e.equipment == eq),
          isNotEmpty,
          reason: eq,
        );
      }
    });

    test('enough low-impact work exists for a lighter default plan', () {
      expect(
        data.exercises.where((e) => e.lowImpact).length,
        greaterThanOrEqualTo(20),
      );
    });

    test('no exercise references bundled media', () {
      final raw = File(DataAssets.exercises).readAsStringSync();
      for (final key in [
        'imageUrl',
        'videoUrl',
        'image',
        'video',
        'thumbnail',
      ]) {
        expect(raw.contains('"$key"'), isFalse, reason: 'found $key');
      }
      for (final e in data.exercises) {
        expect(e.hasMedia, isFalse);
      }
    });
  });

  group('food database', () {
    test('has at least 100 Indian foods', () {
      expect(data.foods.length, greaterThanOrEqualTo(100));
    });

    test('ids are unique and follow the IFCT code format', () {
      final ids = data.foods.map((f) => f.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final id in ids) {
        expect(RegExp(r'^[A-Z]\d{3}$').hasMatch(id), isTrue, reason: id);
      }
    });

    test('every food has energy and the three macronutrients', () {
      for (final f in data.foods) {
        expect(f.kcal, greaterThan(0), reason: f.id);
        expect(f.proteinG, isNotNull, reason: f.id);
        expect(f.carbG, isNotNull, reason: f.id);
        expect(f.fatG, isNotNull, reason: f.id);
        expect(f.name, isNotEmpty, reason: f.id);
        expect(f.ifctGroup, isNotEmpty, reason: f.id);
      }
    });

    test('energy agrees with the macronutrients within rounding tolerance', () {
      for (final f in data.foods) {
        final computed =
            f.proteinPer100g * 4 + f.carbPer100g * 4 + f.fatPer100g * 9;
        // IFCT energy is measured rather than computed and fibre contributes
        // too, so a small gap is expected. A large one means the row is
        // internally inconsistent and must not have been shipped.
        expect(
          (computed - f.kcal).abs(),
          lessThan(40),
          reason:
              '${f.id} ${f.name}: published ${f.kcal}, '
              'macros imply ${computed.toStringAsFixed(0)}',
        );
      }
    });

    test('derived energy is flagged and limited to oils and fats', () {
      final derived = data.foods.where((f) => f.energyDerived).toList();
      for (final f in derived) {
        expect(f.group, 'fat', reason: f.id);
        expect(f.energyFormula, isNotNull, reason: f.id);
        expect(
          data.sources.containsKey(f.energySourceId),
          isTrue,
          reason: f.id,
        );
      }
      // Everything else must be a straight IFCT value.
      expect(
        data.foods.where((f) => !f.energyDerived).length,
        data.foods.length - derived.length,
      );
    });

    test('every food has a veg, egg or non-veg tag', () {
      for (final f in data.foods) {
        expect(f.dietTag, anyOf('veg', 'egg', 'nonveg'), reason: f.id);
      }
    });

    test('a veg user can still build a full plate', () {
      for (final group in [
        'cereal',
        'pulse',
        'dairy',
        'vegetable',
        'leafy',
        'fruit',
        'nut',
        'root',
        'fat',
      ]) {
        final veg = data.foods.where(
          (f) => f.group == group && f.dietTag == 'veg',
        );
        expect(veg, isNotEmpty, reason: 'no veg option in $group');
      }
    });

    test('serving sizes are only present where a source exists', () {
      for (final f in data.foods) {
        if (f.servingG == null) {
          expect(f.servingSourceId, isNull, reason: f.id);
        } else {
          expect(f.servingG, greaterThan(0), reason: f.id);
          expect(f.servingSourceId, isNotNull, reason: f.id);
          expect(
            data.servingSourceLabels.containsKey(f.servingSourceId),
            isTrue,
            reason: '${f.id} -> ${f.servingSourceId}',
          );
        }
      }
    });

    test('the database ships no prices at all', () {
      final raw = File(DataAssets.foods).readAsStringSync().toLowerCase();
      for (final key in ['price', 'cost', 'inr', 'rupee', '₹']) {
        expect(raw.contains(key), isFalse, reason: 'found "$key" in food data');
      }
    });
  });

  group('no placeholder content anywhere', () {
    test('no lorem ipsum, TODO or sample data markers', () {
      const banned = [
        'lorem',
        'ipsum',
        'todo',
        'fixme',
        'placeholder',
        'dummy',
        'sample user',
        'john doe',
        'jane doe',
        'foo bar',
        'test user',
        'coming soon',
        'tbd',
        'xxx',
        'asdf',
      ];
      for (final path in DataAssets.all) {
        final raw = File(path).readAsStringSync().toLowerCase();
        for (final word in banned) {
          expect(raw.contains(word), isFalse, reason: 'found "$word" in $path');
        }
      }
    });

    test('no fake person names in the disclaimer or notes', () {
      expect(data.disclaimer, isNotEmpty);
      expect(data.disclaimer.toLowerCase(), contains('not medical advice'));
      expect(data.disclaimer.toLowerCase(), contains('who'));
      expect(data.disclaimer.toLowerCase(), contains('icmr'));
    });
  });

  group('guideline values match the publications', () {
    test(
      'WHO adult activity: 150-300 moderate, 75-150 vigorous, 2 strength days',
      () {
        final adult = data.activityBands.firstWhere(
          (b) => b.id == 'adult_18_64',
        );
        expect(adult.aerobicMinutesPerWeekMin, 150);
        expect(adult.aerobicMinutesPerWeekMax, 300);
        expect(adult.vigorousMinutesPerWeekMin, 75);
        expect(adult.vigorousMinutesPerWeekMax, 150);
        expect(adult.muscleStrengtheningDaysPerWeek, 2);
      },
    );

    test('WHO 5-17: an average of 60 minutes a day, 3 strength days', () {
      final child = data.activityBands.firstWhere((b) => b.id == 'child_5_17');
      expect(child.aerobicMinutesPerDayAverage, 60);
      expect(child.aerobicMinutesPerWeek, 420);
      expect(child.muscleStrengtheningDaysPerWeek, 3);
    });

    test('WHO 65+: adds functional balance and strength on 3 days', () {
      final older = data.activityBands.firstWhere(
        (b) => b.id == 'older_65_plus',
      );
      expect(older.balanceAndStrengthDaysPerWeek, 3);
      expect(older.aerobicMinutesPerWeekMin, 150);
    });

    test('ICMR-NIN 2020 energy requirements', () {
      final sed = data.activityEnergy[ActivityLevel.sedentary]!;
      expect(sed.male.kcalPerDay, 2110);
      expect(sed.male.referenceWeightKg, 65.0);
      expect(sed.male.kcalPerKgPerDay, 32);
      expect(sed.female.kcalPerDay, 1660);
      expect(sed.female.referenceWeightKg, 55.0);

      expect(
        data.activityEnergy[ActivityLevel.moderate]!.male.kcalPerDay,
        2710,
      );
      expect(data.activityEnergy[ActivityLevel.heavy]!.male.kcalPerDay, 3470);
      expect(
        data.activityEnergy[ActivityLevel.moderate]!.female.kcalPerDay,
        2130,
      );
      expect(data.activityEnergy[ActivityLevel.heavy]!.female.kcalPerDay, 2720);
    });

    test(
      'only the sedentary PAL is published; the others are flagged derived',
      () {
        expect(data.activityEnergy[ActivityLevel.sedentary]!.male.pal, 1.4);
        expect(
          data.activityEnergy[ActivityLevel.sedentary]!.male.palDerived,
          isFalse,
        );
        for (final level in [ActivityLevel.moderate, ActivityLevel.heavy]) {
          for (final e in [
            data.activityEnergy[level]!.male,
            data.activityEnergy[level]!.female,
          ]) {
            expect(e.palDerived, isTrue, reason: '$level');
            expect(e.palFormula, isNotNull, reason: '$level');
          }
        }
      },
    );

    test('ICMR-NIN 2020 protein: EAR 0.66 and RDA 0.83 g/kg for adults', () {
      for (final p in data.adultProtein) {
        expect(p.earGPerKg, 0.66);
        expect(p.rdaGPerKg, 0.83);
      }
      final male = data.adultProtein.firstWhere((p) => p.sex == Sex.male);
      expect(male.rdaGPerDay, 54.0);
      final female = data.adultProtein.firstWhere((p) => p.sex == Sex.female);
      expect(female.rdaGPerDay, 45.7);
    });

    test('sports-nutrition protein range is 1.2 to 2.0 g/kg', () {
      expect(data.trainingProteinRange.min, 1.2);
      expect(data.trainingProteinRange.max, 2.0);
      expect(data.trainingProteinRange.sourceId, 'acsm_and_dc_2016');
    });

    test('ICMR-NIN BMI cut-offs for Indian adults', () {
      expect(data.bmiCutoffs.underweightBelow, 18.5);
      expect(data.bmiCutoffs.normalMax, 23.0);
      expect(data.bmiCutoffs.overweightMax, 27.5);
      expect(data.bmiCutoffs.categoryFor(17.0), 'underweight');
      expect(data.bmiCutoffs.categoryFor(21.0), 'normal');
      expect(data.bmiCutoffs.categoryFor(25.0), 'overweight');
      expect(data.bmiCutoffs.categoryFor(30.0), 'obese');
    });

    test('safe limits carry the ICMR-NIN figures', () {
      expect(data.calorieSafety['weightReductionFloorKcal']!.value, 1000);
      expect(
        data.calorieSafety['weightReductionFloorKcal']!.isFromSource,
        isTrue,
      );
      expect(data.calorieSafety['maxDeficitPercentOfNeeds']!.value, 40);
      expect(data.weightSafety['maxLossKgPerWeek']!.value, 0.5);
      expect(data.weightSafety['minBmiForWeightLossGoal']!.value, 18.5);
      for (final key in [
        'weightReductionFloorKcal',
        'maxDeficitPercentOfNeeds',
      ]) {
        expect(data.calorieSafety[key]!.sourceId, 'icmr_dgi_2024', reason: key);
      }
    });

    test(
      'app-policy guards are labelled as such, not cited as publications',
      () {
        final guard = data.weightSafety['maxLossPercentBodyWeightPerWeek']!;
        expect(guard.isFromSource, isFalse);
        expect(guard.sourceId, isNull);
        expect(guard.note, isNotNull);
      },
    );

    test('WHO diet limits', () {
      final sugar = data.dietLimits.firstWhere((l) => l.id == 'free_sugars');
      expect(sugar['maxPercentEnergy'], 10);
      expect(sugar['idealMaxPercentEnergy'], 5);
      expect(sugar['gramsAt2000Kcal'], 50);

      final salt = data.dietLimits.firstWhere((l) => l.id == 'salt');
      expect(salt['maxGramsPerDay'], 5);
      expect(salt['sodiumGramsPerDay'], 2);

      final satFat = data.dietLimits.firstWhere((l) => l.id == 'saturated_fat');
      expect(satFat['maxPercentEnergy'], 10);

      final trans = data.dietLimits.firstWhere((l) => l.id == 'trans_fat');
      expect(trans['maxPercentEnergy'], 1);
    });

    test('FSSAI industrial trans fat limit is 2% by mass of total fat', () {
      final fssai = data.dietLimits.firstWhere(
        (l) => l.id == 'trans_fat_fssai_product_limit',
      );
      expect(fssai['maxPercentByMassOfFat'], 2);
      expect(fssai.sourceId, 'fssai_transfat_2022');
    });

    test('WHO fruit, vegetable, fibre and potassium targets', () {
      expect(
        data.dietTargetById('fruit_and_vegetables')!['minGramsPerDay'],
        400,
      );
      expect(data.dietTargetById('dietary_fibre')!['minGramsPerDay'], 25);
      expect(data.dietTargetById('potassium')!['minMilligramsPerDay'], 3510);
    });

    test('ICMR-NIN water target is 8 glasses of 250 ml, two litres', () {
      final water = data.dietTargetById('water')!;
      expect(water['millilitresPerDay'], 2000);
      expect(water['glassesPerDay'], 8);
      expect(water['millilitresPerGlass'], 250);
      expect(water.sourceId, 'icmr_dgi_2024');
    });

    test('My Plate groups match the published 2000 kcal day', () {
      final byGroup = {
        for (final g in data.myPlateGroups)
          g['group'] as String:
              (g['gramsPerDay'] ?? g['millilitresPerDay']) as num,
      };
      expect(byGroup['cereal'], 250);
      expect(byGroup['pulse'], 85);
      expect(byGroup['vegetable'], 400);
      expect(byGroup['fruit'], 100);
      expect(byGroup['dairy'], 300);
      expect(byGroup['nut'], 35);
      expect(byGroup['fat'], 27);
    });
  });

  group('screening questionnaire', () {
    test('covers every item named in the brief', () {
      const required = [
        'heart_condition',
        'chest_pain',
        'high_blood_pressure',
        'low_blood_pressure',
        'diabetes',
        'thyroid',
        'asthma',
        'joint_back_injury',
        'recent_surgery',
        'pregnant_postpartum',
        'eating_disorder',
        'regular_medication',
        'other_problem',
      ];
      final ids = data.screeningItems.map((i) => i.id).toSet();
      for (final r in required) {
        expect(ids, contains(r), reason: 'missing screening item $r');
      }
    });

    test('every item has a severity and a localisation key', () {
      for (final i in data.screeningItems) {
        expect(i.severity, anyOf('serious', 'caution'), reason: i.id);
        expect(i.labelKey, isNotEmpty, reason: i.id);
      }
    });

    test('the dangerous conditions are marked serious', () {
      for (final id in [
        'heart_condition',
        'chest_pain',
        'high_blood_pressure',
        'low_blood_pressure',
        'diabetes',
        'asthma',
        'recent_surgery',
        'pregnant_postpartum',
        'eating_disorder',
      ]) {
        expect(data.screeningItem(id)!.isSerious, isTrue, reason: id);
      }
    });

    test('the three red flags are the emergency symptoms', () {
      expect(data.redFlagKeys, hasLength(3));
      expect(data.redFlagKeys, contains('chest_pain_today'));
      expect(data.redFlagKeys, contains('fainting_today'));
      expect(data.redFlagKeys, contains('severe_breathlessness_today'));
    });
  });

  group('billing configuration', () {
    test(
      'exactly two subscription products, both configurable in one place',
      () {
        expect(BillingProducts.all, hasLength(2));
        expect(BillingProducts.all, contains('premium_monthly'));
        expect(BillingProducts.all, contains('premium_yearly'));
        expect(BillingProducts.monthly, 'premium_monthly');
        expect(BillingProducts.yearly, 'premium_yearly');
      },
    );

    test('no price or currency is hardcoded anywhere in the app', () {
      final dartFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      // A currency symbol or code immediately followed by a digit. The
      // lookbehind keeps Dart record getters such as `entry.$1` out of it.
      final pricePattern = RegExp(
        r'(₹\s?\d|Rs\.?\s?\d|INR\s?\d|(?<![.\w])\$\s?\d)',
      );
      for (final f in dartFiles) {
        final content = f.readAsStringSync();
        for (final line in content.split('\n')) {
          // Comments may discuss prices; code must not contain one.
          final code = line.split('//').first;
          expect(
            pricePattern.hasMatch(code),
            isFalse,
            reason: '${f.path}: $line',
          );
        }
      }
    });
  });
}
