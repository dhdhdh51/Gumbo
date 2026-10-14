import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/gen/app_localizations.dart';
import '../models/enums.dart';
import '../models/exercise.dart';
import '../providers/app_providers.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'main_shell.dart';

/// Browse every exercise in the library, with full instructions.
class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  ConsumerState<ExerciseLibraryScreen> createState() =>
      _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends ConsumerState<ExerciseLibraryScreen> {
  String _query = '';
  String _equipment = 'all';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final data = ref.watch(guidelineDataProvider);

    final q = _query.trim().toLowerCase();
    final results =
        data.exercises.where((e) {
          if (_equipment != 'all' && e.equipment != _equipment) return false;
          if (q.isEmpty) return true;
          return e.name.toLowerCase().contains(q) ||
              e.primaryMuscles.any((m) => m.contains(q)) ||
              muscleLabel(
                l10n,
                e.primaryMuscles.first,
              ).toLowerCase().contains(q);
        }).toList();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.libraryTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.m, Gap.s, Gap.m, 0),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      labelText: l10n.librarySearch(data.exercises.length),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  Gap.h8,
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final entry in [
                          ('all', l10n.libraryFilterAll),
                          ('gym', l10n.libraryFilterGym),
                          ('home', l10n.libraryFilterHome),
                          ('bodyweight', l10n.libraryFilterBodyweight),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: Gap.s),
                            child: FilterChip(
                              label: Text(entry.$2),
                              selected: _equipment == entry.$1,
                              onSelected:
                                  (_) => setState(() => _equipment = entry.$1),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child:
                  results.isEmpty
                      ? Padding(
                        padding: const EdgeInsets.all(Gap.m),
                        child: EmptyState(
                          icon: Icons.search_off,
                          message: l10n.librarySearchEmpty,
                        ),
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.only(
                          top: Gap.s,
                          bottom: Gap.xl,
                        ),
                        itemCount: results.length,
                        itemBuilder: (context, i) {
                          final e = results[i];
                          return ListTile(
                            title: Text(e.name),
                            subtitle: Text(
                              '${e.primaryMuscles.map((m) => muscleLabel(l10n, m)).join(', ')}'
                              ' · ${_equipmentLabel(l10n, e.equipment)}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap:
                                () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder:
                                        (_) =>
                                            ExerciseDetailScreen(exercise: e),
                                  ),
                                ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

String _equipmentLabel(AppLocalizations l10n, String equipment) =>
    switch (equipment) {
      'gym' => l10n.libraryFilterGym,
      'home' => l10n.libraryFilterHome,
      _ => l10n.libraryFilterBodyweight,
    };

String _difficultyLabel(AppLocalizations l10n, ExperienceLevel level) =>
    switch (level) {
      ExperienceLevel.beginner => l10n.onboardingExperienceBeginner,
      ExperienceLevel.intermediate => l10n.onboardingExperienceIntermediate,
      ExperienceLevel.advanced => l10n.onboardingExperienceAdvanced,
    };

String _goalLabel(AppLocalizations l10n, Goal goal) => switch (goal) {
  Goal.gain => l10n.onboardingGoalGain,
  Goal.lose => l10n.onboardingGoalLose,
  Goal.maintain => l10n.onboardingGoalMaintain,
};

/// Full detail for one exercise: muscles, equipment, defaults per goal, steps,
/// mistakes and safety. No media area is drawn, because none is bundled.
class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({super.key, required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final data = ref.watch(guidelineDataProvider);

    return Scaffold(
      appBar: AppBar(title: Text(exercise.name)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Gap.m),
          children: [
            Wrap(
              spacing: Gap.s,
              runSpacing: Gap.xs,
              children: [
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(_equipmentLabel(l10n, exercise.equipment)),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(
                    '${l10n.libraryDifficulty}: ${_difficultyLabel(l10n, exercise.difficulty)}',
                  ),
                ),
                if (exercise.lowImpact)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(l10n.splitLightActivity),
                  ),
              ],
            ),
            Gap.h16,

            _Row(
              label: l10n.libraryPrimary,
              value: exercise.primaryMuscles
                  .map((m) => muscleLabel(l10n, m))
                  .join(', '),
            ),
            if (exercise.secondaryMuscles.isNotEmpty)
              _Row(
                label: l10n.librarySecondary,
                value: exercise.secondaryMuscles
                    .map((m) => muscleLabel(l10n, m))
                    .join(', '),
              ),
            _Row(
              label: l10n.workoutEquipmentLabel,
              value: exercise.equipmentDetail,
            ),

            Gap.h16,
            Text(
              l10n.libraryDefaultSets,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            Gap.h8,
            for (final goal in Goal.values)
              Builder(
                builder: (context) {
                  final p = exercise.prescriptionFor(goal);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      l10n.libraryDefaultFor(
                        _goalLabel(l10n, goal),
                        p.sets,
                        p.repsMin,
                        p.repsMax,
                        p.restSec,
                      ),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                },
              ),
            if (exercise.isTimed) ...[
              Gap.h4,
              Text(
                '${l10n.workoutSecondsLabel}: '
                '${exercise.prescriptionFor(Goal.maintain).repsMin}'
                '-${exercise.prescriptionFor(Goal.maintain).repsMax} '
                '${l10n.unitSeconds}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],

            Gap.h24,
            _Block(
              title: l10n.workoutHowToTitle,
              items: exercise.steps,
              numbered: true,
            ),
            _Block(title: l10n.workoutMistakesTitle, items: exercise.mistakes),
            _Block(title: l10n.workoutSafetyTitle, items: exercise.safety),

            Gap.h8,
            Text(
              l10n.workoutNoMediaNote,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Gap.h8,
            Text(
              l10n.sourcesExerciseNote,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            SourceChip(
              sourceId: data.exercises.isEmpty ? null : 'icmr_dgi_2024',
            ),
            Gap.h32,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}

class _Block extends StatelessWidget {
  const _Block({
    required this.title,
    required this.items,
    this.numbered = false,
  });

  final String title;
  final List<String> items;
  final bool numbered;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          Gap.h8,
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 20,
                    child: Text(
                      numbered ? '${i + 1}.' : '\u2022',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      items[i],
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
