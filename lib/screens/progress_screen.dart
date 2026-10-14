import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';
import '../models/enums.dart';
import '../models/progress.dart';
import '../providers/app_providers.dart';
import '../services/calculations.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'main_shell.dart';
import 'paywall_screen.dart';

/// Weekly check-in, weight chart, workout history, personal records and body
/// measurements. Everything shown here is the user's own recorded data; there
/// is no sample data anywhere.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final premium = ref.watch(isPremiumProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.progressTitle)),
      body: RefreshIndicator(
        onRefresh: () async => invalidateRecords(ref),
        child: ListView(
          children: [
            PagePadding(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _CheckInCard(),
                  Gap.h24,
                  const _WeightSection(),
                  Gap.h24,
                  const _BmiCard(),
                  Gap.h24,
                  const _ActivityTargetCard(),
                  Gap.h24,
                  const _HistorySection(),
                  Gap.h24,
                  SectionHeader(title: l10n.progressRecordsHeading),
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
                    const _RecordsSection(),
                  Gap.h24,
                  const _MeasurementsSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Weekly check-in: weight plus the mandatory health question.
class _CheckInCard extends ConsumerStatefulWidget {
  const _CheckInCard();

  @override
  ConsumerState<_CheckInCard> createState() => _CheckInCardState();
}

class _CheckInCardState extends ConsumerState<_CheckInCard> {
  final _weightController = TextEditingController();
  bool? _newProblem;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _weightController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final unit = ref.read(settingsProvider).weightUnit;
    final raw = double.tryParse(_weightController.text.trim());
    if (raw == null || raw <= 0) return;
    final kg = unit.toKg(raw);
    if (kg < 25 || kg > 300) return;

    final hasProblem = _newProblem ?? false;
    final services = ref.read(servicesProvider);

    await services.db.addWeighIn(
      weightKg: kg,
      newHealthProblem: hasProblem,
      note:
          _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
    );

    // Keep the profile weight in step so targets follow real measurements.
    final profile = ref.read(profileProvider).profile;
    if (profile != null) {
      await ref
          .read(profileProvider.notifier)
          .save(profile.copyWith(weightKg: kg));
    }

    // A new health problem pauses automatic diet changes until cleared.
    await ref.read(dietAdjustmentProvider.notifier).setPaused(hasProblem);

    ref.invalidate(weighInsProvider);
    ref.invalidate(weightTrendProvider);

    // Apply the stall nudge, but only while diet changes are not paused.
    if (!hasProblem && profile != null) {
      final weighIns = await services.db.weighIns();
      final data = ref.read(guidelineDataProvider);
      final trend = Calculations.weightTrend(
        weighIns: weighIns,
        goal: profile.goal,
        weeksRequired: data.stallAdjustment.weeks,
      );
      final nudge = Calculations.stallAdjustment(
        data: data,
        trend: trend,
        goal: profile.goal,
      );
      if (nudge != 0) {
        await ref.read(dietAdjustmentProvider.notifier).applyNudge(nudge);
      }
    }

    if (!mounted) return;
    _weightController.clear();
    _noteController.clear();
    setState(() => _newProblem = null);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.progressCheckInSaved)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unit = ref.watch(settingsProvider).weightUnit;
    final adjustment = ref.watch(dietAdjustmentProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: l10n.progressCheckInTitle),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.progressCheckInWeight,
                    suffixText:
                        unit == WeightUnit.kg ? l10n.unitKg : l10n.unitLb,
                  ),
                ),
                Gap.h16,
                Text(
                  l10n.progressCheckInHealthQuestion,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Gap.h8,
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: false, label: Text(l10n.actionNo)),
                    ButtonSegment(value: true, label: Text(l10n.actionYes)),
                  ],
                  selected: {_newProblem ?? false},
                  onSelectionChanged:
                      (s) => setState(() => _newProblem = s.first),
                ),
                if (_newProblem ?? false) ...[
                  Gap.h8,
                  Text(
                    l10n.progressCheckInHealthYesNote,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  Gap.h8,
                  TextField(
                    controller: _noteController,
                    maxLines: 2,
                    decoration: InputDecoration(hintText: l10n.checkNoteHint),
                  ),
                ],
                Gap.h16,
                FilledButton(
                  onPressed: _save,
                  child: Text(l10n.progressCheckInSave),
                ),
                if (adjustment.paused) ...[
                  Gap.h8,
                  OutlinedButton(
                    onPressed:
                        () => ref
                            .read(dietAdjustmentProvider.notifier)
                            .setPaused(false),
                    child: Text(l10n.progressResumeDiet),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Weight chart plus the trend message.
class _WeightSection extends ConsumerWidget {
  const _WeightSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final unit = ref.watch(settingsProvider).weightUnit;
    final weighIns = ref.watch(weighInsProvider);
    final trend = ref.watch(weightTrendProvider);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: l10n.progressWeightHeading),
        weighIns.when(
          loading: () => const SizedBox(height: 4),
          error:
              (_, _) =>
                  ErrorRetry(onRetry: () => ref.invalidate(weighInsProvider)),
          data: (list) {
            if (list.isEmpty) {
              return EmptyState(
                icon: Icons.monitor_weight_outlined,
                message: l10n.progressWeightEmpty,
              );
            }

            // Oldest first for the chart.
            final points = list.reversed.toList();
            final spots = <FlSpot>[
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), unit.fromKg(points[i].weightKg)),
            ];
            final values = spots.map((s) => s.y);
            final minY = values.reduce((a, b) => a < b ? a : b);
            final maxY = values.reduce((a, b) => a > b ? a : b);
            final pad = ((maxY - minY) * 0.2).clamp(0.5, 5.0);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Gap.s,
                      Gap.m,
                      Gap.m,
                      Gap.s,
                    ),
                    child: SizedBox(
                      height: 200,
                      child:
                          spots.length < 2
                              // A single point is shown as a value, not as a chart
                              // with an invented second point.
                              ? Center(
                                child: Text(
                                  '${spots.first.y.toStringAsFixed(1)} '
                                  '${unit == WeightUnit.kg ? l10n.unitKg : l10n.unitLb}',
                                  style:
                                      Theme.of(
                                        context,
                                      ).textTheme.headlineMedium,
                                ),
                              )
                              : LineChart(
                                LineChartData(
                                  minY: minY - pad,
                                  maxY: maxY + pad,
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    getDrawingHorizontalLine:
                                        (v) => FlLine(
                                          color: scheme.outlineVariant,
                                          strokeWidth: 1,
                                        ),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  titlesData: FlTitlesData(
                                    topTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    rightTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 40,
                                        getTitlesWidget:
                                            (value, meta) => Text(
                                              value.toStringAsFixed(0),
                                              style:
                                                  Theme.of(
                                                    context,
                                                  ).textTheme.labelSmall,
                                            ),
                                      ),
                                    ),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 28,
                                        interval:
                                            (points.length / 4).ceilToDouble(),
                                        getTitlesWidget: (value, meta) {
                                          final i = value.round();
                                          if (i < 0 || i >= points.length) {
                                            return const SizedBox.shrink();
                                          }
                                          return Text(
                                            DateFormat.Md(
                                              Localizations.localeOf(
                                                context,
                                              ).toString(),
                                            ).format(points[i].recordedAt),
                                            style:
                                                Theme.of(
                                                  context,
                                                ).textTheme.labelSmall,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: spots,
                                      isCurved: false,
                                      barWidth: 3,
                                      color: scheme.primary,
                                      dotData: const FlDotData(show: true),
                                      belowBarData: BarAreaData(
                                        show: true,
                                        color: scheme.primary.withValues(
                                          alpha: 0.12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                    ),
                  ),
                ),
                Gap.h8,
                trend.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (t) {
                    if (t.weeksObserved == 0) {
                      return Text(
                        l10n.progressTrendNotEnough,
                        style: Theme.of(context).textTheme.bodySmall,
                      );
                    }
                    final adjustment = ref.watch(dietAdjustmentProvider);
                    if (t.stalled) {
                      return Text(
                        l10n.progressTrendStalled(
                          adjustment.kcal.round().toString(),
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      );
                    }
                    return Text(
                      l10n.progressTrendMoving(
                        unit.fromKg(t.changeKg).toStringAsFixed(1),
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    );
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _BmiCard extends ConsumerWidget {
  const _BmiCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(profileProvider).profile;
    final data = ref.watch(guidelineDataProvider);
    if (profile == null) return const SizedBox.shrink();

    final bmi = profile.bmi;
    if (bmi == null) return const SizedBox.shrink();

    final category = data.bmiCutoffs.categoryFor(bmi);
    final label = switch (category) {
      'underweight' => l10n.bmiUnderweight,
      'normal' => l10n.bmiNormal,
      'overweight' => l10n.bmiOverweight,
      _ => l10n.bmiObese,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: l10n.progressBmiHeading),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.progressBmiValue(bmi.toStringAsFixed(1), label),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (data.bmiCutoffs.note != null) ...[
                  Gap.h8,
                  Text(
                    data.bmiCutoffs.note!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                SourceChip(sourceId: data.bmiCutoffs.sourceId),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// WHO weekly activity target for the user's age band.
class _ActivityTargetCard extends ConsumerWidget {
  const _ActivityTargetCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final targets = ref.watch(activityTargetsProvider);
    final data = ref.watch(guidelineDataProvider);
    if (targets == null) return const SizedBox.shrink();

    final band =
        data.activityBands.where((b) => b.id == targets.bandId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.progressActivityHeading,
          subtitle: targets.bandLabel,
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (band?.aerobicMinutesPerDayAverage != null)
                  Text(
                    l10n.progressActivityAerobicDaily(
                      band!.aerobicMinutesPerDayAverage!,
                    ),
                  )
                else if (targets.aerobicMinutesPerWeekMax != null)
                  Text(
                    l10n.progressActivityAerobic(
                      targets.aerobicMinutesPerWeek,
                      targets.aerobicMinutesPerWeekMax!,
                    ),
                  )
                else
                  Text('${targets.aerobicMinutesPerWeek} ${l10n.unitMinutes}'),
                Gap.h4,
                Text(
                  l10n.progressActivityStrength(targets.strengthDaysPerWeek),
                ),
                if (targets.balanceDaysPerWeek != null) ...[
                  Gap.h4,
                  Text(
                    l10n.progressActivityBalance(targets.balanceDaysPerWeek!),
                  ),
                ],
                SourceChip(sourceId: targets.sourceId),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HistorySection extends ConsumerWidget {
  const _HistorySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final history = ref.watch(sessionHistoryProvider);
    final locale = Localizations.localeOf(context).toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: l10n.progressHistoryHeading),
        history.when(
          loading: () => const SizedBox(height: 4),
          error:
              (_, _) => ErrorRetry(
                onRetry: () => ref.invalidate(sessionHistoryProvider),
              ),
          data: (sessions) {
            if (sessions.isEmpty) {
              return EmptyState(
                icon: Icons.history,
                message: l10n.progressHistoryEmpty,
              );
            }
            return Card(
              child: Column(
                children: [
                  for (final s in sessions.take(20))
                    ListTile(
                      dense: true,
                      leading: Icon(
                        s.isLightSession
                            ? Icons.healing_outlined
                            : Icons.fitness_center,
                        size: 18,
                      ),
                      title: Text(splitLabel(l10n, s.labelKey)),
                      subtitle: Text(
                        '${DateFormat.yMMMd(locale).format(s.startedAt)} · '
                        '${l10n.progressHistoryEntry(s.totalSets, s.duration.inMinutes)}',
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

class _RecordsSection extends ConsumerWidget {
  const _RecordsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final records = ref.watch(personalRecordsProvider);
    final unit = ref.watch(settingsProvider).weightUnit;

    return records.when(
      loading: () => const SizedBox(height: 4),
      error:
          (_, _) => ErrorRetry(
            onRetry: () => ref.invalidate(personalRecordsProvider),
          ),
      data: (list) {
        if (list.isEmpty) {
          return EmptyState(
            icon: Icons.emoji_events_outlined,
            message: l10n.progressRecordsEmpty,
          );
        }
        return Card(
          child: Column(
            children: [
              for (final r in list.take(25))
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.emoji_events_outlined, size: 18),
                  title: Text(r.exerciseName),
                  subtitle: Text(_recordLabel(l10n, r, unit)),
                ),
            ],
          ),
        );
      },
    );
  }

  String _recordLabel(
    AppLocalizations l10n,
    PersonalRecord r,
    WeightUnit unit,
  ) {
    final w = r.bestWeightKg;
    if (w != null && w > 0) {
      final value = unit.fromKg(w);
      final suffix = unit == WeightUnit.kg ? l10n.unitKg : l10n.unitLb;
      return l10n.progressRecordWeight(
        '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)} $suffix',
        r.bestReps ?? 0,
      );
    }
    final seconds = r.bestSeconds;
    if (seconds != null && seconds > 0) {
      return l10n.progressRecordSeconds(seconds);
    }
    return l10n.progressRecordReps(r.bestReps ?? 0);
  }
}

class _MeasurementsSection extends ConsumerWidget {
  const _MeasurementsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final measurements = ref.watch(measurementsProvider);
    final locale = Localizations.localeOf(context).toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.progressMeasurementsHeading,
          trailing: TextButton.icon(
            icon: const Icon(Icons.add, size: 18),
            onPressed: () => _addMeasurement(context, ref),
            label: Text(l10n.actionAdd),
          ),
        ),
        measurements.when(
          loading: () => const SizedBox(height: 4),
          error:
              (_, _) => ErrorRetry(
                onRetry: () => ref.invalidate(measurementsProvider),
              ),
          data: (list) {
            if (list.isEmpty) {
              return EmptyState(
                icon: Icons.straighten,
                message: l10n.progressMeasurementsEmpty,
                action: OutlinedButton(
                  onPressed: () => _addMeasurement(context, ref),
                  child: Text(l10n.progressAddMeasurement),
                ),
              );
            }
            return Card(
              child: Column(
                children: [
                  for (final m in list.take(20))
                    ListTile(
                      dense: true,
                      title: Text(
                        DateFormat.yMMMd(locale).format(m.recordedAt),
                      ),
                      subtitle: Text(_summary(l10n, m)),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  String _summary(AppLocalizations l10n, BodyMeasurement m) {
    final parts = <String>[];
    void add(String label, double? v) {
      if (v != null) parts.add('$label ${v.toStringAsFixed(1)} ${l10n.unitCm}');
    }

    add(l10n.progressMeasurementWaist, m.waistCm);
    add(l10n.progressMeasurementChest, m.chestCm);
    add(l10n.progressMeasurementHip, m.hipCm);
    add(l10n.progressMeasurementArm, m.armCm);
    add(l10n.progressMeasurementThigh, m.thighCm);
    add(l10n.progressMeasurementNeck, m.neckCm);
    return parts.join(' · ');
  }

  Future<void> _addMeasurement(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final controllers = {
      'waist': TextEditingController(),
      'chest': TextEditingController(),
      'hip': TextEditingController(),
      'arm': TextEditingController(),
      'thigh': TextEditingController(),
      'neck': TextEditingController(),
    };

    final labels = {
      'waist': l10n.progressMeasurementWaist,
      'chest': l10n.progressMeasurementChest,
      'hip': l10n.progressMeasurementHip,
      'arm': l10n.progressMeasurementArm,
      'thigh': l10n.progressMeasurementThigh,
      'neck': l10n.progressMeasurementNeck,
    };

    final saved = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, Gap.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.progressAddMeasurement,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Gap.h16,
                    for (final key in controllers.keys)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Gap.s),
                        child: TextField(
                          controller: controllers[key],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: labels[key],
                            suffixText: l10n.unitCm,
                          ),
                        ),
                      ),
                    Gap.h8,
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(l10n.actionSave),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );

    double? value(String key) => double.tryParse(controllers[key]!.text.trim());

    if (saved ?? false) {
      final measurement = BodyMeasurement(
        id: 0,
        recordedAt: DateTime.now(),
        waistCm: value('waist'),
        chestCm: value('chest'),
        hipCm: value('hip'),
        armCm: value('arm'),
        thighCm: value('thigh'),
        neckCm: value('neck'),
      );

      if (measurement.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.progressMeasurementNeedOne)),
          );
        }
      } else {
        await ref.read(servicesProvider).db.addMeasurement(measurement);
        ref.invalidate(measurementsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.progressMeasurementSaved)),
          );
        }
      }
    }

    for (final c in controllers.values) {
      c.dispose();
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
