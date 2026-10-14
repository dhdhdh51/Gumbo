import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/gen/app_localizations.dart';
import 'models/enums.dart';
import 'providers/app_providers.dart';
import 'screens/age_blocked_screen.dart';
import 'screens/consent_screen.dart';
import 'screens/language_screen.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';

class TrainerApp extends ConsumerWidget {
  const TrainerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'TrainerApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      locale: settings.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const _StartupGate(),
    );
  }
}

/// Decides which screen the user lands on, in a fixed order:
/// splash, then language, then disclaimer and consent, then onboarding, then
/// the age gate, then the app itself.
class _StartupGate extends ConsumerStatefulWidget {
  const _StartupGate();

  @override
  ConsumerState<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends ConsumerState<_StartupGate> {
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    // A brief splash, long enough to read the name and not long enough to
    // annoy anyone.
    Future<void>.delayed(const Duration(milliseconds: 900)).then((_) {
      if (mounted) setState(() => _splashDone = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) return const SplashScreen();

    final settings = ref.watch(settingsProvider);

    // 1. Language selection, before anything else so every notice is readable.
    if (settings.locale == null) return const LanguageScreen();

    // 2. Full-screen disclaimer and privacy consent.
    if (!settings.consentAccepted) return const ConsentScreen();

    // 3. Onboarding, including the health questionnaire.
    final profileState = ref.watch(profileProvider);
    if (!profileState.hasProfile) return const OnboardingScreen();

    // 4. Age gate. Under 13 the app does not open.
    final decision = ref.watch(ageDecisionProvider);
    if (decision != null && decision.access == AccessLevel.blocked) {
      return const AgeBlockedScreen();
    }

    return const MainShell();
  }
}
