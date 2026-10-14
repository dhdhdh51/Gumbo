import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/gen/app_localizations.dart';
import '../providers/app_providers.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'onboarding_screen.dart';

/// Shown instead of the app when the user is under 13.
///
/// There is deliberately no way through this screen. The only action is to
/// correct the age if it was entered wrongly.
class AgeBlockedScreen extends ConsumerWidget {
  const AgeBlockedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final decision = ref.watch(ageDecisionProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Gap.l),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SafetyNotice(
                    title: l10n.ageBlockedTitle,
                    body: decision?.message ?? l10n.ageBlockedBody,
                    icon: Icons.family_restroom,
                  ),
                  Gap.h24,
                  OutlinedButton(
                    onPressed:
                        () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder:
                                (_) => const OnboardingScreen(editing: true),
                          ),
                        ),
                    child: Text(l10n.ageBlockedChangeAge),
                  ),
                  Gap.h24,
                  const DisclaimerBanner(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
