import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainerapp/theme.dart';

/// Guards the button themes against an infinite minimum width.
///
/// `Size.fromHeight(h)` is `Size(double.infinity, h)`. As a theme-wide minimum
/// that is fine wherever the parent constrains width, but a button placed as a
/// non-flex child of a Row gets unbounded constraints, throws "BoxConstraints
/// forces an infinite width", never lays out, and silently fails to paint in a
/// release build. That shipped once and made the onboarding Next button and the
/// rest-timer buttons invisible, so it is pinned here.
void main() {
  for (final brightness in Brightness.values) {
    final theme =
        brightness == Brightness.light ? AppTheme.light() : AppTheme.dark();
    final label = brightness.name;

    group('button themes ($label)', () {
      test('minimum widths are finite', () {
        final filled = theme.filledButtonTheme.style?.minimumSize?.resolve(
          const <WidgetState>{},
        );
        final outlined = theme.outlinedButtonTheme.style?.minimumSize?.resolve(
          const <WidgetState>{},
        );

        expect(filled, isNotNull);
        expect(outlined, isNotNull);
        expect(
          filled!.width.isFinite,
          isTrue,
          reason: 'filled button minimum width is ${filled.width}',
        );
        expect(
          outlined!.width.isFinite,
          isTrue,
          reason: 'outlined button minimum width is ${outlined.width}',
        );
      });

      test('minimum heights still meet the touch target', () {
        final filled =
            theme.filledButtonTheme.style?.minimumSize?.resolve(
              const <WidgetState>{},
            )!;
        final outlined =
            theme.outlinedButtonTheme.style?.minimumSize?.resolve(
              const <WidgetState>{},
            )!;
        expect(filled!.height, greaterThanOrEqualTo(48));
        expect(outlined!.height, greaterThanOrEqualTo(48));
      });

      testWidgets('buttons lay out inside an unbounded Row', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Row(
                // No Expanded and no Spacer-bounded width: this is the exact
                // shape that used to blow up.
                children: [
                  FilledButton(onPressed: () {}, child: const Text('A')),
                  OutlinedButton(onPressed: () {}, child: const Text('B')),
                  const Spacer(),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        for (final finder in [
          find.widgetWithText(FilledButton, 'A'),
          find.widgetWithText(OutlinedButton, 'B'),
        ]) {
          final size = tester.getSize(finder);
          expect(size.width.isFinite, isTrue, reason: 'size is $size');
          expect(size.width, greaterThan(0));
        }
      });

      testWidgets('buttons still fill a stretched Column', (tester) async {
        // The full-width look the app relies on must survive the finite
        // minimum, because it comes from the layout rather than the theme.
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(onPressed: () {}, child: const Text('Wide')),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final width =
            tester.getSize(find.widgetWithText(FilledButton, 'Wide')).width;
        expect(width, tester.getSize(find.byType(Scaffold)).width);
      });
    });
  }
}
