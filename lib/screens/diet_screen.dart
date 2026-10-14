import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/gen/app_localizations.dart';
import '../models/diet.dart';
import '../models/enums.dart';
import '../models/targets.dart';
import '../providers/app_providers.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'food_prices_screen.dart';
import 'food_search_screen.dart';
import 'paywall_screen.dart';

/// Daily calorie and protein targets, the budget meal plan, meal logging and
/// the water tracker.
class DietScreen extends ConsumerWidget {
  const DietScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final targets = ref.watch(targetsProvider);
    final premium = ref.watch(isPremiumProvider);
    final adjustment = ref.watch(dietAdjustmentProvider);
    final decision = ref.watch(ageDecisionProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dietTitle),
        actions: [
          IconButton(
            tooltip: l10n.dietPricesTitle,
            icon: const Icon(Icons.currency_rupee),
            onPressed:
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const FoodPricesScreen(),
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

                  if (decision?.access == AccessLevel.activityOnly) ...[
                    SafetyNotice(
                      title: l10n.ageTeenNoticeTitle,
                      body: decision!.message ?? l10n.ageTeenNoticeBody,
                      icon: Icons.school_outlined,
                    ),
                    Gap.h16,
                  ],

                  if (adjustment.paused) ...[
                    SafetyNotice(
                      title: l10n.progressCheckInHealthQuestion,
                      body: l10n.dietPausedNotice,
                      icon: Icons.pause_circle_outline,
                    ),
                    Gap.h16,
                  ],

                  if (targets == null)
                    const SizedBox.shrink()
                  else ...[
                    _TargetsCard(targets: targets),
                    Gap.h24,
                    const _WaterCard(),
                    Gap.h24,

                    // Budget meal planning and the full diet tooling are
                    // Premium; the water tracker and logging stay free.
                    SectionHeader(title: l10n.dietMealPlanHeading),
                    if (!premium)
                      PremiumLock(
                        onUpgrade:
                            () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const PaywallScreen(),
                              ),
                            ),
                      )
                    else
                      const _MealPlanCard(),

                    Gap.h24,
                    const _FoodLogCard(),
                    Gap.h24,
                    _LimitsCard(targets: targets),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Today's targets plus an honest, citable explanation of where they come from.
class _TargetsCard extends ConsumerWidget {
  const _TargetsCard({required this.targets});

  final NutritionTargets targets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final totals = ref.watch(todayTotalsProvider).value;

    String kcal(double v) => v.round().toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: l10n.dietTargetsHeading),
        Row(
          children: [
            Expanded(
              child: StatTile(
                icon: Icons.local_fire_department_outlined,
                label: l10n.dietCalorieTarget,
                value: '${targets.targetKcal}',
                caption: l10n.unitKcal,
                progress:
                    totals != null && totals.hasData
                        ? totals.kcal / targets.targetKcal
                        : null,
              ),
            ),
            Gap.w8,
            Expanded(
              child: StatTile(
                icon: Icons.egg_outlined,
                label: l10n.dietProteinTarget,
                value: '${targets.proteinG}',
                caption: l10n.unitGram,
                progress:
                    totals != null && totals.hasData
                        ? totals.proteinG / targets.proteinG
                        : null,
              ),
            ),
          ],
        ),
        Gap.h16,
        Card(
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            title: Text(
              l10n.dietHowCalculated,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, Gap.m),
            children: [
              _Line(
                l10n.dietBmrLine(kcal(targets.bmrKcal)),
                sourceId: 'mifflin_st_jeor_1990',
              ),
              _Line(
                l10n.dietMaintenanceLine(kcal(targets.maintenanceKcal)),
                sourceId: 'icmr_rda_2020',
                derived: true,
              ),
              _Line(l10n.dietGoalLine('${targets.targetKcal}')),
              if (targets.icmrReferenceKcal != null)
                _Line(
                  l10n.dietIcmrReferenceLine('${targets.icmrReferenceKcal}'),
                  sourceId: 'icmr_rda_2020',
                ),
              if (targets.weeklyChangeKg != null &&
                  targets.weeklyChangeKg!.abs() > 0.01)
                _Line(
                  l10n.dietWeeklyChangeLine(
                    targets.weeklyChangeKg!.toStringAsFixed(2),
                  ),
                ),
              _Line(
                '${l10n.dietProteinTarget}: '
                '${targets.proteinMinG}-${targets.proteinMaxG} ${l10n.unitGram}',
                sourceId: 'acsm_and_dc_2016',
              ),
              if (targets.wasClamped) ...[
                Gap.h8,
                Text(
                  l10n.dietClampHeading,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Gap.h4,
                for (final clamp in targets.clamps)
                  _Line(
                    _clampText(l10n, clamp),
                    sourceId: _clampSource(clamp),
                    appRule: _clampSource(clamp) == null,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _clampText(AppLocalizations l10n, TargetClamp c) => switch (c) {
    TargetClamp.bmrFloor => l10n.dietClampBmrFloor,
    TargetClamp.icmrFloor => l10n.dietClampIcmrFloor,
    TargetClamp.maxDeficit => l10n.dietClampMaxDeficit,
    TargetClamp.maxWeeklyLoss => l10n.dietClampMaxWeeklyLoss,
    TargetClamp.underweightNoLoss => l10n.dietClampUnderweight,
    TargetClamp.minorNoDeficit => l10n.dietClampMinor,
  };

  /// Null where the rule is this app's own conservative guard rather than a
  /// published figure, so the UI can label it accordingly.
  String? _clampSource(TargetClamp c) => switch (c) {
    TargetClamp.icmrFloor => 'icmr_dgi_2024',
    TargetClamp.maxDeficit => 'icmr_dgi_2024',
    TargetClamp.maxWeeklyLoss => 'icmr_dgi_2024',
    TargetClamp.underweightNoLoss => 'icmr_dgi_2024',
    TargetClamp.bmrFloor => null,
    TargetClamp.minorNoDeficit => null,
  };
}

class _Line extends StatelessWidget {
  const _Line(
    this.text, {
    this.sourceId,
    this.derived = false,
    this.appRule = false,
  });

  final String text;
  final String? sourceId;
  final bool derived;
  final bool appRule;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          Row(
            children: [
              if (sourceId != null) SourceChip(sourceId: sourceId),
              if (derived)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    l10n.labelDerived,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (appRule) const AppRuleChip(),
            ],
          ),
        ],
      ),
    );
  }
}

/// Water tracker. Free for everyone, because hydration is not a premium idea.
class _WaterCard extends ConsumerWidget {
  const _WaterCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final targets = ref.watch(targetsProvider);
    final water = ref.watch(todayWaterProvider);
    final db = ref.watch(servicesProvider).db;

    if (targets == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: l10n.dietWaterHeading),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                water.when(
                  loading: () => const LinearProgressIndicator(minHeight: 6),
                  error:
                      (_, _) => ErrorRetry(
                        onRetry: () => ref.invalidate(todayWaterProvider),
                      ),
                  data:
                      (ml) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.dietWaterProgress(ml, targets.waterMl),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Gap.h8,
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (ml / targets.waterMl).clamp(0, 1),
                              minHeight: 8,
                            ),
                          ),
                          Gap.h16,
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.tonalIcon(
                                  icon: const Icon(Icons.add, size: 18),
                                  onPressed: () async {
                                    await db.addWater(DateTime.now(), 250);
                                    ref.invalidate(todayWaterProvider);
                                  },
                                  label: Text(l10n.dietWaterGlass),
                                ),
                              ),
                              Gap.w8,
                              IconButton.outlined(
                                tooltip: l10n.dietWaterRemove,
                                icon: const Icon(Icons.remove),
                                onPressed:
                                    ml <= 0
                                        ? null
                                        : () async {
                                          await db.addWater(
                                            DateTime.now(),
                                            -250,
                                          );
                                          ref.invalidate(todayWaterProvider);
                                        },
                              ),
                            ],
                          ),
                        ],
                      ),
                ),
                Gap.h8,
                Text(
                  l10n.dietWaterNote,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SourceChip(sourceId: 'icmr_dgi_2024'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The budget meal plan, with honest reporting when it cannot be met.
class _MealPlanCard extends ConsumerWidget {
  const _MealPlanCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final plan = ref.watch(mealPlanProvider);
    final db = ref.watch(servicesProvider).db;

    return plan.when(
      loading:
          () => const Card(
            child: Padding(
              padding: EdgeInsets.all(Gap.l),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      error:
          (_, _) => ErrorRetry(onRetry: () => ref.invalidate(mealPlanProvider)),
      data: (p) {
        if (p == null || p.isEmpty) {
          return EmptyState(
            icon: Icons.restaurant_menu_outlined,
            message: l10n.dietMealPlanNoPrices,
            action: OutlinedButton(
              onPressed:
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const FoodPricesScreen(),
                    ),
                  ),
              child: Text(l10n.dietPricesTitle),
            ),
          );
        }

        final cost = p.totalCostInr;
        final budget = p.dailyBudgetInr;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (p.shortfalls.contains(MealPlanShortfall.noPrices))
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.s),
                child: EmptyState(
                  icon: Icons.currency_rupee,
                  message: l10n.dietMealPlanNoPrices,
                  action: OutlinedButton(
                    onPressed:
                        () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const FoodPricesScreen(),
                          ),
                        ),
                    child: Text(l10n.dietPricesTitle),
                  ),
                ),
              ),
            if (p.shortfalls.contains(MealPlanShortfall.budgetTooLow) &&
                cost != null &&
                budget != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.s),
                child: SafetyNotice(
                  icon: Icons.account_balance_wallet_outlined,
                  title: l10n.onboardingBudget,
                  body: l10n.dietMealPlanBudgetTooLow(
                    cost.toStringAsFixed(0),
                    budget.toStringAsFixed(0),
                  ),
                ),
              ),
            if (p.shortfalls.contains(MealPlanShortfall.proteinUnreachable))
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.s),
                child: EmptyState(
                  icon: Icons.info_outline,
                  message: l10n.dietMealPlanProteinShort,
                ),
              ),
            if (p.shortfalls.contains(MealPlanShortfall.caloriesUnreachable))
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.s),
                child: EmptyState(
                  icon: Icons.info_outline,
                  message: l10n.dietMealPlanCalorieShort,
                ),
              ),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(Gap.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${p.totalKcal.round()} ${l10n.unitKcal} · '
                            '${p.totalProteinG.round()} ${l10n.unitGram} '
                            '${l10n.dietNutrientProtein}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        if (cost != null)
                          Text(
                            l10n.dietMealPlanCost(cost.toStringAsFixed(0)),
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                      ],
                    ),
                    if (budget != null) ...[
                      Gap.h4,
                      Text(
                        l10n.dietMealPlanBudget(budget.toStringAsFixed(0)),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const Divider(height: Gap.l),
                    for (final meal in p.meals) ...[
                      Text(
                        _slotLabel(l10n, meal.slot),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Gap.h4,
                      for (final item in meal.items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.foodName} · '
                                  '${item.grams.round()} ${l10n.unitGram}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              Text(
                                '${item.kcal.round()} ${l10n.unitKcal}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      Gap.h8,
                      OutlinedButton(
                        onPressed: () async {
                          for (final item in meal.items) {
                            await db.logFood(slot: meal.slot, item: item);
                          }
                          ref.invalidate(todayTotalsProvider);
                          ref.invalidate(todayFoodLogProvider);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.dietMealLogged)),
                          );
                        },
                        child: Text(l10n.dietLogThisMeal),
                      ),
                      const Divider(height: Gap.l),
                    ],
                    const SourceChip(sourceId: 'ifct_2017'),
                    const SourceChip(
                      sourceId: 'icmr_dgi_2024',
                      prefix: 'My Plate',
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

String _slotLabel(AppLocalizations l10n, MealSlot slot) => switch (slot) {
  MealSlot.breakfast => l10n.dietMealBreakfast,
  MealSlot.lunch => l10n.dietMealLunch,
  MealSlot.snack => l10n.dietMealSnack,
  MealSlot.dinner => l10n.dietMealDinner,
};

/// What the user actually ate today.
class _FoodLogCard extends ConsumerWidget {
  const _FoodLogCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final logs = ref.watch(todayFoodLogProvider);
    final db = ref.watch(servicesProvider).db;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.dietLogHeading,
          trailing: TextButton.icon(
            icon: const Icon(Icons.add, size: 18),
            onPressed:
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const FoodSearchScreen(),
                  ),
                ),
            label: Text(l10n.dietAddFood),
          ),
        ),
        logs.when(
          loading: () => const SizedBox(height: 4),
          error:
              (_, _) => ErrorRetry(
                onRetry: () => ref.invalidate(todayFoodLogProvider),
              ),
          data: (entries) {
            if (entries.isEmpty) {
              return EmptyState(
                icon: Icons.no_food_outlined,
                message: l10n.dietLogEmpty,
              );
            }
            return Card(
              child: Column(
                children: [
                  for (final e in entries)
                    ListTile(
                      dense: true,
                      title: Text(e.item.foodName),
                      subtitle: Text(
                        '${_slotLabel(l10n, e.slot)} · '
                        '${e.item.grams.round()} ${l10n.unitGram} · '
                        '${e.item.kcal.round()} ${l10n.unitKcal} · '
                        '${e.item.proteinG.round()} ${l10n.unitGram} '
                        '${l10n.dietNutrientProtein}',
                      ),
                      trailing: IconButton(
                        tooltip: l10n.actionDelete,
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () async {
                          await db.deleteFoodLog(e.id);
                          ref.invalidate(todayTotalsProvider);
                          ref.invalidate(todayFoodLogProvider);
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// The published daily limits the user should stay inside.
class _LimitsCard extends StatelessWidget {
  const _LimitsCard({required this.targets});

  final NutritionTargets targets;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final lines = <({String text, String source})>[
      if (targets.saltLimitG != null)
        (
          text: l10n.dietLimitSalt(targets.saltLimitG!.toStringAsFixed(0)),
          source: 'who_healthy_diet',
        ),
      if (targets.addedSugarLimitG != null)
        (
          text: l10n.dietLimitSugar(
            targets.addedSugarLimitG!.toStringAsFixed(0),
          ),
          source: 'icmr_dgi_2024',
        ),
      if (targets.visibleFatLimitG != null)
        (
          text: l10n.dietLimitOil(targets.visibleFatLimitG!.toStringAsFixed(0)),
          source: 'icmr_dgi_2024',
        ),
      if (targets.fibreMinG != null)
        (
          text: l10n.dietTargetFibre(targets.fibreMinG!.toStringAsFixed(0)),
          source: 'who_healthy_diet',
        ),
    ];

    if (lines.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: l10n.dietLimitsHeading),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in lines) ...[
                  Text(
                    line.text,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  SourceChip(sourceId: line.source),
                  Gap.h8,
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
