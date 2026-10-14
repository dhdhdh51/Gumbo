import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/gen/app_localizations.dart';
import '../models/enums.dart';
import '../models/workout.dart';
import '../providers/app_providers.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'main_shell.dart';

/// Finish screen shown after a session.
///
/// Everything here is computed from the sets the user actually logged. When
/// nothing was logged it says so instead of showing zeroes as achievements.
class WorkoutSummaryScreen extends ConsumerWidget {
  const WorkoutSummaryScreen({super.key, required this.session});

  final WorkoutSession? session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final unit = ref.watch(settingsProvider).weightUnit;
    final s = session;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.summaryTitle),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Gap.m),
          children: [
            if (s == null)
              EmptyState(
                icon: Icons.info_outline,
                message: l10n.summaryNothingLogged,
              )
            else ...[
              Text(
                splitLabel(l10n, s.labelKey),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Gap.h16,
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      icon: Icons.timer_outlined,
                      label: l10n.summaryDuration,
                      value: '${s.duration.inMinutes} ${l10n.unitMinutes}',
                    ),
                  ),
                  Gap.w8,
                  Expanded(
                    child: StatTile(
                      icon: Icons.repeat,
                      label: l10n.summarySets,
                      value: '${s.totalSets}',
                    ),
                  ),
                ],
              ),
              Gap.h8,
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      icon: Icons.fitness_center,
                      label: l10n.summaryExercises,
                      value: '${s.logs.where((l) => !l.skipped).length}',
                    ),
                  ),
                  Gap.w8,
                  if (s.totalVolume > 0)
                    Expanded(
                      child: StatTile(
                        icon: Icons.scale_outlined,
                        label: l10n.summaryVolume,
                        value:
                            '${unit.fromKg(s.totalVolume).round()} '
                            '${unit == WeightUnit.kg ? l10n.unitKg : l10n.unitLb}',
                      ),
                    )
                  else
                    const Expanded(child: SizedBox.shrink()),
                ],
              ),
              Gap.h24,
              SectionHeader(title: l10n.summaryExercises),
              Card(
                child: Column(
                  children: [
                    for (final log in s.logs)
                      ListTile(
                        dense: true,
                        leading: Icon(
                          log.skipped
                              ? Icons.remove_circle_outline
                              : Icons.check_circle_outline,
                          size: 18,
                        ),
                        title: Text(log.exerciseName),
                        subtitle:
                            log.skipped
                                ? Text(l10n.actionSkip)
                                : Text(_setSummary(log, unit, l10n)),
                        trailing:
                            log.feedback == null
                                ? null
                                : Text(
                                  _feedbackLabel(l10n, log.feedback!),
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                      ),
                  ],
                ),
              ),
            ],
            Gap.h24,
            FilledButton(
              onPressed:
                  () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
              child: Text(l10n.summaryBackHome),
            ),
            Gap.h32,
          ],
        ),
      ),
    );
  }

  String _setSummary(ExerciseLog log, WeightUnit unit, AppLocalizations l10n) {
    final parts = log.sets.map((set) {
      final w = set.weightKg;
      final reps = set.seconds ?? set.reps;
      if (w == null) return '$reps';
      return '$reps x ${unit.fromKg(w).round()}';
    });
    return parts.join(', ');
  }

  String _feedbackLabel(AppLocalizations l10n, SetFeedback f) => switch (f) {
    SetFeedback.tooEasy => l10n.feedbackTooEasy,
    SetFeedback.justRight => l10n.feedbackJustRight,
    SetFeedback.tooHard => l10n.feedbackTooHard,
  };
}
