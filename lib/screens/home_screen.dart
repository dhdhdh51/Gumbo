import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/gen/app_localizations.dart';
import '../models/workout.dart';
import '../providers/app_providers.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'main_shell.dart';
import 'paywall_screen.dart';
import 'pre_workout_check_screen.dart';
import 'sources_screen.dart';

/// Today's session, the Start Workout button, the streak and today's targets.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(profileProvider).profile;
    final decision = ref.watch(ageDecisionProvider);
    final screening = ref.watch(screeningResultProvider);
    final targets = ref.watch(targetsProvider);
    final premium = ref.watch(isPremiumProvider);

    final todayPlan = ref.watch(todayPlanProvider);
    final streak = ref.watch(weeklyStreakProvider);
    final totals = ref.watch(todayTotalsProvider);
    final water = ref.watch(todayWaterProvider);

    if (profile == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.homeGreeting(profile.name)),
        actions: [
          if (premium)
            Padding(
              padding: const EdgeInsets.only(right: Gap.s),
              child: Chip(
                label: Text(l10n.paywallPremiumBadge),
                visualDensity: VisualDensity.compact,
              ),
            ),
          IconButton(
            tooltip: l10n.sourcesTitle,
            icon: const Icon(Icons.menu_book_outlined),
            onPressed:
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SourcesScreen(),
                  ),
                ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => invalidateRecords(ref),
        child: ListView(
          children: [
            PagePadding(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const DisclaimerBanner(compact: true),
                  Gap.h16,

                  // A serious screening answer is repeated here, because it
                  // changes what the app will do for the user.
                  if (screening.blocksHighIntensity) ...[
                    SafetyNotice(
                      title: l10n.screeningDoctorTitle,
                      body: l10n.screeningDoctorBody,
                    ),
                    Gap.h16,
                  ] else if (decision?.lighterDefault ?? false) ...[
                    SafetyNotice(
                      title: l10n.ageOlderNoticeTitle,
                      body: decision!.message ?? l10n.ageOlderNoticeBody,
                      icon: Icons.favorite_outline,
                    ),
                    Gap.h16,
                  ],

                  todayPlan.when(
                    loading:
                        () => const Card(
                          child: Padding(
                            padding: EdgeInsets.all(Gap.l),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                    error:
                        (_, _) => ErrorRetry(
                          onRetry: () => ref.invalidate(todayPlanProvider),
                        ),
                    data: (plan) => _TodayCard(plan: plan),
                  ),

                  Gap.h24,
                  SectionHeader(title: l10n.homeStreakTitle),
                  streak.when(
                    loading: () => const SizedBox(height: 4),
                    error: (_, _) => const SizedBox.shrink(),
                    data:
                        (weeks) =>
                            weeks == 0
                                ? EmptyState(
                                  icon: Icons.local_fire_department_outlined,
                                  message: l10n.homeStreakEmpty,
                                )
                                : StatTile(
                                  icon: Icons.local_fire_department,
                                  label: l10n.homeStreakTitle,
                                  value: l10n.homeStreakWeeks(weeks),
                                ),
                  ),

                  Gap.h24,
                  SectionHeader(title: l10n.dietTargetsHeading),
                  if (targets == null)
                    const SizedBox.shrink()
                  else ...[
                    totals.when(
                      loading: () => const SizedBox(height: 4),
                      error:
                          (_, _) => ErrorRetry(
                            onRetry: () => ref.invalidate(todayTotalsProvider),
                          ),
                      data:
                          (t) => Column(
                            children: [
                              StatTile(
                                icon: Icons.local_fire_department_outlined,
                                label: l10n.homeCaloriesTitle,
                                value:
                                    t.hasData
                                        ? l10n.homeTargetProgress(
                                          '${t.kcal.round()}',
                                          '${targets.targetKcal}',
                                        )
                                        : '${targets.targetKcal} ${l10n.unitKcal}',
                                caption:
                                    t.hasData
                                        ? null
                                        : l10n.homeNothingLoggedYet,
                                progress:
                                    t.hasData
                                        ? t.kcal / targets.targetKcal
                                        : null,
                              ),
                              Gap.h8,
                              StatTile(
                                icon: Icons.egg_outlined,
                                label: l10n.homeProteinTitle,
                                value:
                                    t.hasData
                                        ? l10n.homeTargetProgress(
                                          '${t.proteinG.round()} ${l10n.unitGram}',
                                          '${targets.proteinG} ${l10n.unitGram}',
                                        )
                                        : '${targets.proteinG} ${l10n.unitGram}',
                                caption:
                                    t.hasData
                                        ? null
                                        : l10n.homeNothingLoggedYet,
                                progress:
                                    t.hasData
                                        ? t.proteinG / targets.proteinG
                                        : null,
                              ),
                            ],
                          ),
                    ),
                    Gap.h8,
                    water.when(
                      loading: () => const SizedBox(height: 4),
                      error: (_, _) => const SizedBox.shrink(),
                      data:
                          (ml) => StatTile(
                            icon: Icons.water_drop_outlined,
                            label: l10n.homeWaterTitle,
                            value: l10n.dietWaterProgress(ml, targets.waterMl),
                            progress: ml / targets.waterMl,
                          ),
                    ),
                  ],

                  Gap.h24,
                  const _WeekStrip(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Today's session card with the Start Workout button.
class _TodayCard extends ConsumerWidget {
  const _TodayCard({required this.plan});

  final PlannedDay? plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final day = plan;

    if (day == null) return const SizedBox.shrink();

    if (day.isRest) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(Gap.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.self_improvement, color: scheme.primary),
                  Gap.w8,
                  Text(
                    l10n.homeTodayLabel(l10n.homeRestDayTitle),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              Gap.h8,
              Text(
                l10n.homeRestDayBody,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    final muscles = day.muscleGroups
        .map((m) => muscleLabel(l10n, m))
        .take(3)
        .join(' + ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.homeTodayLabel(
                muscles.isEmpty ? splitLabel(l10n, day.labelKey) : muscles,
              ),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            Gap.h4,
            Text(
              '${splitLabel(l10n, day.labelKey)} · '
              '${l10n.homeExerciseCount(day.exercises.length)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (day.isDeload) ...[
              Gap.h8,
              Row(
                children: [
                  Icon(Icons.trending_down, size: 16, color: scheme.tertiary),
                  Gap.w8,
                  Expanded(
                    child: Text(
                      l10n.homeDeloadWeek,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            Gap.h16,
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              // Every Start Workout tap goes through the health check first.
              onPressed:
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PreWorkoutCheckScreen(plan: day),
                    ),
                  ),
              label: Text(l10n.homeStartWorkout),
            ),
          ],
        ),
      ),
    );
  }
}

/// The seven-day rotation, so the user can see the week at a glance.
class _WeekStrip extends ConsumerWidget {
  const _WeekStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final week = ref.watch(weekPlanProvider);
    final premium = ref.watch(isPremiumProvider);
    final profile = ref.watch(profileProvider).profile;

    return week.when(
      loading: () => const SizedBox(height: 4),
      error: (_, _) => const SizedBox.shrink(),
      data: (plan) {
        if (plan == null) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(title: l10n.homeThisWeek),
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < plan.days.length; i++)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        plan.days[i].isRest
                            ? Icons.bedtime_outlined
                            : Icons.fitness_center,
                        size: 18,
                      ),
                      title: Text(splitLabel(l10n, plan.days[i].labelKey)),
                      subtitle:
                          plan.days[i].isRest
                              ? null
                              : Text(
                                l10n.homeExerciseCount(
                                  plan.days[i].exercises.length,
                                ),
                              ),
                    ),
                ],
              ),
            ),
            // A free user who asked for more days is told plainly why the plan
            // is only three days, rather than silently getting less.
            if (!premium &&
                profile != null &&
                profile.daysPerWeek > plan.daysPerWeek) ...[
              Gap.h8,
              PremiumLock(
                onUpgrade:
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PaywallScreen(),
                      ),
                    ),
              ),
            ],
          ],
        );
      },
    );
  }
}
