import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/gen/app_localizations.dart';
import 'diet_screen.dart';
import 'exercise_library_screen.dart';
import 'home_screen.dart';
import 'progress_screen.dart';
import 'settings_screen.dart';

/// Bottom-navigation shell holding the five main destinations.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  static const List<Widget> _pages = [
    HomeScreen(),
    DietScreen(),
    ProgressScreen(),
    ExerciseLibraryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.restaurant_outlined),
            selectedIcon: const Icon(Icons.restaurant),
            label: l10n.navDiet,
          ),
          NavigationDestination(
            icon: const Icon(Icons.show_chart_outlined),
            selectedIcon: const Icon(Icons.show_chart),
            label: l10n.navProgress,
          ),
          NavigationDestination(
            icon: const Icon(Icons.list_alt_outlined),
            selectedIcon: const Icon(Icons.list_alt),
            label: l10n.navLibrary,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.navSettings,
          ),
        ],
      ),
    );
  }
}

/// Shared helper so every screen names a split the same way.
String splitLabel(AppLocalizations l10n, String labelKey) => switch (labelKey) {
  'splitRest' => l10n.splitRest,
  'splitFullBodyA' => l10n.splitFullBodyA,
  'splitFullBodyB' => l10n.splitFullBodyB,
  'splitFullBodyC' => l10n.splitFullBodyC,
  'splitUpper' => l10n.splitUpper,
  'splitLower' => l10n.splitLower,
  'splitPush' => l10n.splitPush,
  'splitPull' => l10n.splitPull,
  'splitLegs' => l10n.splitLegs,
  'splitLightActivity' => l10n.splitLightActivity,
  _ => labelKey,
};

/// Shared helper for muscle names.
String muscleLabel(AppLocalizations l10n, String muscle) => switch (muscle) {
  'chest' => l10n.muscleChest,
  'back' => l10n.muscleBack,
  'lats' => l10n.muscleLats,
  'shoulders' => l10n.muscleShoulders,
  'rear_delts' => l10n.muscleRearDelts,
  'biceps' => l10n.muscleBiceps,
  'triceps' => l10n.muscleTriceps,
  'forearms' => l10n.muscleForearms,
  'traps' => l10n.muscleTraps,
  'core' => l10n.muscleCore,
  'obliques' => l10n.muscleObliques,
  'lower_back' => l10n.muscleLowerBack,
  'quads' => l10n.muscleQuads,
  'hamstrings' => l10n.muscleHamstrings,
  'glutes' => l10n.muscleGlutes,
  'calves' => l10n.muscleCalves,
  'full_body' => l10n.muscleFullBody,
  _ => muscle,
};

/// Shared helper for the progression explanation shown next to a suggestion.
String progressionLabel(AppLocalizations l10n, String key) => switch (key) {
  'progressionTooEasy' => l10n.progressionTooEasy,
  'progressionTooEasyReps' => l10n.progressionTooEasyReps,
  'progressionAddRep' => l10n.progressionAddRep,
  'progressionAddLoad' => l10n.progressionAddLoad,
  'progressionTooHard' => l10n.progressionTooHard,
  'progressionTooHardReps' => l10n.progressionTooHardReps,
  'progressionHold' => l10n.progressionHold,
  'progressionDeload' => l10n.progressionDeload,
  _ => '',
};
