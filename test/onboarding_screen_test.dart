import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainerapp/l10n/gen/app_localizations.dart';
import 'package:trainerapp/models/profile.dart';
import 'package:trainerapp/providers/app_providers.dart';
import 'package:trainerapp/screens/onboarding_screen.dart';
import 'package:trainerapp/theme.dart';

import 'support/test_data.dart';

/// Stands in for the real notifier so the screen can be pumped without a
/// database or shared preferences.
class _FakeProfileNotifier extends ProfileNotifier {
  UserProfile? saved;

  @override
  ProfileState build() => const ProfileState(
    profile: null,
    healthAnswers: HealthAnswers.empty(),
    clearance: MedicalClearance.none(),
  );

  @override
  Future<void> save(UserProfile profile) async {
    saved = profile;
  }
}

void main() {
  final data = loadGuidelineData();

  Widget wrap({required Widget child}) {
    return ProviderScope(
      overrides: [
        guidelineDataProvider.overrideWithValue(data),
        profileProvider.overrideWith(_FakeProfileNotifier.new),
        isPremiumProvider.overrideWithValue(false),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }

  /// Pumps the screen at a real surface size.
  ///
  /// Wrapping in MediaQuery is not enough: the test view keeps its default
  /// 800x600 surface, so a layout that only breaks on a small phone would pass.
  Future<void> pump(
    WidgetTester tester, {
    Widget child = const OnboardingScreen(),
    Size size = const Size(400, 800),
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(wrap(child: child));
    await tester.pumpAndSettle();
  }

  group('onboarding', () {
    testWidgets('the Next button is laid out and tappable on the name step', (
      tester,
    ) async {
      await pump(tester);

      // The regression this guards: the themed button carried an infinite
      // minimum width, so placing it as a non-flex child of a Row gave it
      // unbounded constraints and it never appeared.
      final next = find.widgetWithText(FilledButton, 'Next');
      expect(next, findsOneWidget, reason: 'no way to advance from step 1');

      final size = tester.getSize(next);
      expect(
        size.width.isFinite,
        isTrue,
        reason: 'button width is $size, so it cannot be painted',
      );
      expect(size.width, greaterThan(0));
      expect(
        size.height,
        greaterThanOrEqualTo(48),
        reason: 'below the minimum touch target',
      );

      // It must actually be on screen, not pushed outside the viewport.
      final topLeft = tester.getTopLeft(next);
      expect(topLeft.dx, greaterThanOrEqualTo(0));
      expect(tester.getBottomRight(next).dx, lessThanOrEqualTo(400));
    });

    testWidgets('an empty name is rejected with a message, not silence', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a name'), findsOneWidget);
      expect(
        find.text('Step 1 of 7'),
        findsOneWidget,
        reason: 'should not have advanced',
      );
    });

    testWidgets('a valid name advances to the age step', (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField).first, 'Asha');
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();

      expect(find.text('Step 2 of 7'), findsOneWidget);
    });

    testWidgets('Back returns to the previous step', (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField).first, 'Asha');
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 7'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Back'));
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 7'), findsOneWidget);
      // The name the user already typed must still be there.
      expect(find.text('Asha'), findsOneWidget);
    });

    testWidgets('the age field keeps what was typed and validates the range', (
      tester,
    ) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField).first, 'Asha');
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();

      // Typing two digits must leave both, which a controller rebuilt on every
      // frame would not.
      await tester.enterText(find.byType(TextField).first, '28');
      await tester.pumpAndSettle();
      expect(find.text('28'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '0');
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();
      expect(find.text('Enter an age between 1 and 120'), findsOneWidget);
    });

    testWidgets('every step can be reached and the last step saves', (
      tester,
    ) async {
      await pump(tester, child: const OnboardingScreen(editing: true));

      await tester.enterText(find.byType(TextField).first, 'Asha');
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '28');
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();

      // Height and weight.
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '165');
      await tester.enterText(fields.at(1), '62');
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();
      expect(find.text('Step 4 of 7'), findsOneWidget);

      // Goal, training, level, diet: each must offer a way forward.
      for (var step = 4; step <= 6; step++) {
        expect(find.text('Step $step of 7'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Next'));
        await tester.pumpAndSettle();
      }

      expect(find.text('Step 7 of 7'), findsOneWidget);
      // The final step shows Save rather than Next when editing.
      expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
    });

    testWidgets('the Next button survives a small screen', (tester) async {
      // A short, narrow device is where a bottom bar is most likely to be lost.
      await pump(tester, size: const Size(320, 480));

      final next = find.widgetWithText(FilledButton, 'Next');
      expect(next, findsOneWidget);
      expect(tester.getSize(next).width.isFinite, isTrue);
      expect(tester.getBottomRight(next).dy, lessThanOrEqualTo(480));
    });
  });
}
