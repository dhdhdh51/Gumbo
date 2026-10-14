import 'package:flutter_test/flutter_test.dart';
import 'package:trainerapp/models/enums.dart';
import 'package:trainerapp/models/profile.dart';
import 'package:trainerapp/services/health_safety.dart';

import 'support/test_data.dart';

void main() {
  final data = loadGuidelineData();

  HealthAnswers answers(Map<String, bool> a, {String notes = ''}) =>
      HealthAnswers(answers: a, notes: notes, answeredAt: DateTime(2026, 1, 1));

  group('onboarding screening', () {
    test('no flags means no notice and no restrictions', () {
      final r = HealthSafety.evaluateScreening(
        data: data,
        answers: answers({for (final i in data.screeningItems) i.id: false}),
        clearance: const MedicalClearance.none(),
      );
      expect(r.hasAnyFlag, isFalse);
      expect(r.requiresDoctorNotice, isFalse);
      expect(r.blocksWeightLoss, isFalse);
      expect(r.blocksHighIntensity, isFalse);
    });

    test('any serious yes blocks weight loss and high intensity', () {
      for (final item in data.screeningItems.where((i) => i.isSerious)) {
        final r = HealthSafety.evaluateScreening(
          data: data,
          answers: answers({item.id: true}),
          clearance: const MedicalClearance.none(),
        );
        expect(r.seriousFlags, contains(item.id));
        expect(r.requiresDoctorNotice, isTrue, reason: item.id);
        expect(r.blocksWeightLoss, isTrue, reason: item.id);
        expect(r.blocksHighIntensity, isTrue, reason: item.id);
      }
    });

    test('a caution yes advises a doctor but does not block features', () {
      for (final item in data.screeningItems.where((i) => !i.isSerious)) {
        final r = HealthSafety.evaluateScreening(
          data: data,
          answers: answers({item.id: true}),
          clearance: const MedicalClearance.none(),
        );
        expect(r.cautionFlags, contains(item.id));
        expect(r.requiresDoctorNotice, isTrue, reason: item.id);
        expect(r.blocksWeightLoss, isFalse, reason: item.id);
        expect(r.blocksHighIntensity, isFalse, reason: item.id);
      }
    });

    test(
      'confirmed medical clearance lifts the blocks but keeps the notice',
      () {
        final r = HealthSafety.evaluateScreening(
          data: data,
          answers: answers({'heart_condition': true}),
          clearance: MedicalClearance(
            confirmed: true,
            confirmedAt: DateTime(2026, 2, 1),
          ),
        );
        expect(r.seriousFlags, contains('heart_condition'));
        expect(r.requiresDoctorNotice, isTrue);
        expect(r.blocksWeightLoss, isFalse);
        expect(r.blocksHighIntensity, isFalse);
      },
    );

    test('an unknown answer key is ignored rather than crashing', () {
      final r = HealthSafety.evaluateScreening(
        data: data,
        answers: answers({'not_a_real_item': true}),
        clearance: const MedicalClearance.none(),
      );
      expect(r.hasAnyFlag, isFalse);
    });

    test('mixed answers collect both lists', () {
      final r = HealthSafety.evaluateScreening(
        data: data,
        answers: answers({
          'diabetes': true,
          'thyroid': true,
          'joint_back_injury': true,
          'asthma': false,
        }),
        clearance: const MedicalClearance.none(),
      );
      expect(r.seriousFlags, ['diabetes']);
      expect(r.cautionFlags, containsAll(['thyroid', 'joint_back_injury']));
    });
  });

  group('pre-workout check, asked before every single workout', () {
    test('no problem today runs the planned session', () {
      final d = HealthSafety.evaluateDailyCheck(
        hasProblem: false,
        redFlags: const {},
      );
      expect(d.outcome, PreWorkoutOutcome.proceedNormal);
      expect(d.allowNormalPlan, isTrue);
      expect(d.isEmergency, isFalse);
    });

    test('a reported problem withholds the normal plan', () {
      final d = HealthSafety.evaluateDailyCheck(
        hasProblem: true,
        redFlags: const {},
      );
      expect(d.outcome, PreWorkoutOutcome.lightActivityOnly);
      expect(d.allowNormalPlan, isFalse);
      expect(d.offerLightActivity, isTrue);
    });

    test('each red flag stops everything and sends the user for help', () {
      for (final flag in data.redFlagKeys) {
        final d = HealthSafety.evaluateDailyCheck(
          hasProblem: true,
          redFlags: {flag},
        );
        expect(d.outcome, PreWorkoutOutcome.seekHelpNow, reason: flag);
        expect(d.isEmergency, isTrue, reason: flag);
        expect(d.allowNormalPlan, isFalse, reason: flag);
        expect(d.offerLightActivity, isFalse, reason: flag);
      }
    });

    test('a red flag overrides a "no problem" answer', () {
      // Ticking chest pain while answering no is still an emergency.
      final d = HealthSafety.evaluateDailyCheck(
        hasProblem: false,
        redFlags: const {'chest_pain_today'},
      );
      expect(d.outcome, PreWorkoutOutcome.seekHelpNow);
      expect(d.allowNormalPlan, isFalse);
    });

    test('the check is recorded with its outcome and optional note', () {
      final d = HealthSafety.evaluateDailyCheck(
        hasProblem: true,
        redFlags: const {},
      );
      final record = HealthSafety.recordFor(
        decision: d,
        hasProblem: true,
        note: '  sore left knee  ',
        chosen: PreWorkoutOutcome.skipToday,
      );
      expect(record.hasProblem, isTrue);
      expect(record.outcome, PreWorkoutOutcome.skipToday);
      expect(record.note, 'sore left knee');
      expect(record.toJson()['outcome'], 'skipToday');
    });

    test('a blank note is stored as nothing rather than an empty string', () {
      final d = HealthSafety.evaluateDailyCheck(
        hasProblem: false,
        redFlags: const {},
      );
      expect(
        HealthSafety.recordFor(
          decision: d,
          hasProblem: false,
          note: '   ',
        ).note,
        isNull,
      );
    });
  });

  group('weekly check-in', () {
    test('a new health problem pauses automatic diet changes', () {
      expect(
        HealthSafety.shouldPauseDietChanges(newHealthProblemReported: true),
        isTrue,
      );
      expect(
        HealthSafety.shouldPauseDietChanges(newHealthProblemReported: false),
        isFalse,
      );
    });
  });
}
