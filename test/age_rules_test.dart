import 'package:flutter_test/flutter_test.dart';
import 'package:trainerapp/models/enums.dart';
import 'package:trainerapp/services/age_rules.dart';

import 'support/test_data.dart';

void main() {
  final data = loadGuidelineData();

  group('age gating', () {
    test('under 13 is blocked with a message about a parent and doctor', () {
      for (final age in [5, 9, 12]) {
        final d = AgeRules.decide(data: data, age: age);
        expect(d.access, AccessLevel.blocked, reason: 'age $age');
        expect(d.isBlocked, isTrue);
        expect(d.message, isNotNull);
        expect(d.message!.toLowerCase(), contains('parent'));
        expect(d.message!.toLowerCase(), contains('doctor'));
      }
    });

    test(
      '13 to 17 gets activity guidance only, with no deficit or loss goal',
      () {
        for (final age in [13, 15, 17]) {
          final d = AgeRules.decide(data: data, age: age);
          expect(d.access, AccessLevel.activityOnly, reason: 'age $age');
          expect(d.allowCalorieDeficit, isFalse);
          expect(d.allowWeightLossGoal, isFalse);
          expect(d.allowedGoals, isNot(contains(Goal.lose)));
          expect(d.strongerDoctorNotice, isTrue);
        }
      },
    );

    test('18 to 59 gets full access', () {
      for (final age in [18, 30, 59]) {
        final d = AgeRules.decide(data: data, age: age);
        expect(d.access, AccessLevel.full, reason: 'age $age');
        expect(d.allowCalorieDeficit, isTrue);
        expect(d.allowWeightLossGoal, isTrue);
        expect(d.allowedGoals, contains(Goal.lose));
        expect(d.lighterDefault, isFalse);
      }
    });

    test('60 and over keeps full access but gets lighter defaults', () {
      for (final age in [60, 68, 85]) {
        final d = AgeRules.decide(data: data, age: age);
        expect(d.access, AccessLevel.fullLighterDefault, reason: 'age $age');
        expect(d.allowCalorieDeficit, isTrue);
        expect(d.lighterDefault, isTrue);
        expect(d.strongerDoctorNotice, isTrue);
        expect(d.message, isNotNull);
        expect(d.message!.toLowerCase(), contains('doctor'));
      }
    });

    test('a low BMI removes the weight-loss goal at any adult age', () {
      final d = AgeRules.decide(data: data, age: 35, bmiBlocksWeightLoss: true);
      expect(d.allowWeightLossGoal, isFalse);
      expect(d.allowCalorieDeficit, isFalse);
      expect(d.allowedGoals, isNot(contains(Goal.lose)));
    });

    test('every age from 0 to 100 resolves to exactly one rule', () {
      for (var age = 0; age <= 100; age++) {
        final matching = data.ageRules.where((r) => r.matchesAge(age)).toList();
        expect(matching, hasLength(1), reason: 'age $age matched $matching');
      }
    });
  });

  group('WHO activity bands', () {
    test(
      'a teenager gets the 5-17 band: 60 minutes a day, 3 strength days',
      () {
        final t = AgeRules.activityTargets(data: data, age: 15);
        expect(t.bandId, 'child_5_17');
        expect(
          t.aerobicMinutesPerWeek,
          420,
        ); // 60 minutes a day across the week
        expect(t.strengthDaysPerWeek, 3);
      },
    );

    test('an adult gets 150-300 minutes a week and 2 strength days', () {
      final t = AgeRules.activityTargets(data: data, age: 30);
      expect(t.bandId, 'adult_18_64');
      expect(t.aerobicMinutesPerWeek, 150);
      expect(t.aerobicMinutesPerWeekMax, 300);
      expect(t.strengthDaysPerWeek, 2);
      expect(t.balanceDaysPerWeek, isNull);
    });

    test('a 60 year old is still in the adult band, as WHO defines it', () {
      // The app treats 60+ as elderly for defaults, following ICMR-NIN, but
      // WHO's older-adult recommendations begin at 65, so the band must not
      // shift early.
      final t = AgeRules.activityTargets(data: data, age: 62);
      expect(t.bandId, 'adult_18_64');
      expect(t.balanceDaysPerWeek, isNull);
    });

    test('65 and over adds balance and strength work on 3 days', () {
      final t = AgeRules.activityTargets(data: data, age: 70);
      expect(t.bandId, 'older_65_plus');
      expect(t.aerobicMinutesPerWeek, 150);
      expect(t.strengthDaysPerWeek, 2);
      expect(t.balanceDaysPerWeek, 3);
    });

    test('every band cites the WHO 2020 guidelines', () {
      for (final band in data.activityBands) {
        expect(band.sourceId, 'who_pa_guidelines_2020');
        expect(data.source(band.sourceId), isNotNull);
      }
    });
  });

  group('effective experience', () {
    test('an older user starts on beginner defaults whatever they claim', () {
      expect(
        AgeRules.effectiveExperience(
          data: data,
          age: 65,
          stated: ExperienceLevel.advanced,
        ),
        ExperienceLevel.beginner,
      );
    });

    test('an adult keeps the level they chose', () {
      expect(
        AgeRules.effectiveExperience(
          data: data,
          age: 30,
          stated: ExperienceLevel.advanced,
        ),
        ExperienceLevel.advanced,
      );
      expect(
        AgeRules.effectiveExperience(
          data: data,
          age: 30,
          stated: ExperienceLevel.beginner,
        ),
        ExperienceLevel.beginner,
      );
    });
  });
}
