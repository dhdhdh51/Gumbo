import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';

import '../constants.dart';
import '../l10n/gen/app_localizations.dart';
import '../models/enums.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import '../providers/app_providers.dart';
import '../services/plan_builder.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'main_shell.dart';
import 'workout_summary_screen.dart';

/// The session itself: one exercise at a time, with sets, target reps, weight
/// input, a rest timer, and Next, Skip and Replace.
class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({
    super.key,
    required this.plan,
    this.isLight = false,
    this.note,
  });

  final PlannedDay plan;

  /// True when this is the reduced session offered after a health problem.
  final bool isLight;
  final String? note;

  @override
  ConsumerState<ActiveWorkoutScreen> createState() =>
      _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  late List<PlannedExercise> _exercises;
  final Map<int, List<SetLog>> _logged = {};
  final Map<int, SetFeedback> _feedback = {};
  final Map<int, String> _replacedFrom = {};
  final Set<int> _skipped = {};

  int _index = 0;
  int? _sessionId;
  bool _finishing = false;

  // Rest timer
  Timer? _timer;
  int _restRemaining = 0;
  bool _resting = false;

  final _repsController = TextEditingController();
  final _weightController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _exercises = List.of(widget.plan.exercises);
    _prefillInputs();
    _openSession();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _repsController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _openSession() async {
    final id = await ref
        .read(servicesProvider)
        .db
        .startSession(
          labelKey: widget.plan.labelKey,
          muscleGroups: widget.plan.muscleGroups,
          isLight: widget.isLight,
          isDeload: widget.plan.isDeload,
          preCheckNote: widget.note,
        );
    if (mounted) setState(() => _sessionId = id);
  }

  PlannedExercise get _current => _exercises[_index];

  Exercise get _exercise => _current.exercise;

  List<SetLog> get _currentSets => _logged[_index] ?? const [];

  int get _nextSetNumber => _currentSets.length + 1;

  bool get _currentDone => _currentSets.length >= _current.prescription.sets;

  void _prefillInputs() {
    final p = _current.prescription;
    _repsController.text = p.repsMin.toString();
    final w = _current.suggestedWeightKg;
    _weightController.text = w == null ? '' : _formatWeight(w);
  }

  String _formatWeight(double kg) {
    final unit = ref.read(settingsProvider).weightUnit;
    final value = unit.fromKg(kg);
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  // ------------------------------------------------------------ rest timer

  void _startRest(int seconds) {
    _timer?.cancel();
    setState(() {
      _resting = true;
      _restRemaining = seconds;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _restRemaining--);

      if (_restRemaining == TimerConfig.warnAtSecondsRemaining) {
        _buzz(short: true);
      }
      if (_restRemaining <= 0) {
        timer.cancel();
        setState(() => _resting = false);
        _buzz();
      }
    });
  }

  /// Vibrate when rest ends. Falls back to the platform haptic when the device
  /// has no vibrator or the plugin is unavailable.
  Future<void> _buzz({bool short = false}) async {
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(duration: short ? 120 : 450);
        return;
      }
    } on Object {
      // Fall through to haptics.
    }
    await HapticFeedback.mediumImpact();
  }

  void _stopRest() {
    _timer?.cancel();
    if (mounted) setState(() => _resting = false);
  }

  // ----------------------------------------------------------- set logging

  void _logSet() {
    final value = int.tryParse(_repsController.text.trim());
    if (value == null || value <= 0) return;

    final unit = ref.read(settingsProvider).weightUnit;
    final raw = double.tryParse(_weightController.text.trim());
    final weightKg =
        raw == null || !_exercise.tracksWeight ? null : unit.toKg(raw);

    setState(() {
      _logged
          .putIfAbsent(_index, () => [])
          .add(
            SetLog(
              setNumber: _nextSetNumber,
              reps: _exercise.isTimed ? 0 : value,
              seconds: _exercise.isTimed ? value : null,
              weightKg: weightKg,
            ),
          );
    });

    if (_currentDone) {
      _stopRest();
      _askFeedback();
    } else {
      _startRest(_current.prescription.restSec);
    }
  }

  // --------------------------------------------------- feedback and moving on

  Future<void> _askFeedback() async {
    final l10n = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<SetFeedback>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: true,
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, Gap.l),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.feedbackTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Gap.h8,
                  Text(
                    l10n.feedbackSubtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Gap.h24,
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.sentiment_satisfied_alt),
                    onPressed:
                        () => Navigator.of(context).pop(SetFeedback.tooEasy),
                    label: Text(l10n.feedbackTooEasy),
                  ),
                  Gap.h8,
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.check_circle_outline),
                    onPressed:
                        () => Navigator.of(context).pop(SetFeedback.justRight),
                    label: Text(l10n.feedbackJustRight),
                  ),
                  Gap.h8,
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.sentiment_dissatisfied),
                    onPressed:
                        () => Navigator.of(context).pop(SetFeedback.tooHard),
                    label: Text(l10n.feedbackTooHard),
                  ),
                ],
              ),
            ),
          ),
    );

    if (choice != null) {
      setState(() => _feedback[_index] = choice);
    }
    await _advance();
  }

  Future<void> _advance() async {
    await _persistCurrent();
    if (!mounted) return;

    if (_index >= _exercises.length - 1) {
      await _finish();
      return;
    }

    _stopRest();
    setState(() => _index++);
    _prefillInputs();
  }

  Future<void> _persistCurrent() async {
    final id = _sessionId;
    if (id == null) return;
    final sets = _currentSets;
    final skipped = _skipped.contains(_index);
    if (sets.isEmpty && !skipped) return;

    await ref
        .read(servicesProvider)
        .db
        .saveExerciseLog(
          sessionId: id,
          position: _index,
          log: ExerciseLog(
            exerciseId: _exercise.id,
            exerciseName: _exercise.name,
            sets: sets,
            feedback: _feedback[_index],
            skipped: skipped,
            replacedExerciseId: _replacedFrom[_index],
          ),
        );
  }

  Future<void> _skipExercise() async {
    setState(() => _skipped.add(_index));
    await _advance();
  }

  Future<void> _replaceExercise() async {
    final l10n = AppLocalizations.of(context);
    final data = ref.read(guidelineDataProvider);
    final profile = ref.read(profileProvider).profile!;
    final options = PlanBuilder.replacementsFor(
      data: data,
      current: _exercise,
      place: profile.place,
      maxDifficulty: ref.read(effectiveExperienceProvider),
      alreadyInSession: _exercises.map((e) => e.exercise.id).toSet(),
    );

    if (options.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.workoutReplaceEmpty)));
      return;
    }

    final picked = await showModalBottomSheet<Exercise>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, Gap.l),
              children: [
                Text(
                  l10n.workoutReplaceTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Gap.h16,
                for (final option in options.take(12))
                  ListTile(
                    title: Text(option.name),
                    subtitle: Text(option.equipmentDetail),
                    onTap: () => Navigator.of(context).pop(option),
                  ),
              ],
            ),
          ),
    );

    if (picked == null) return;

    setState(() {
      _replacedFrom[_index] = _exercise.id;
      _exercises[_index] = PlannedExercise(
        exercise: picked,
        prescription: picked.prescriptionFor(
          ref.read(profileProvider).profile!.goal,
        ),
      );
      _logged.remove(_index);
      _feedback.remove(_index);
    });
    _prefillInputs();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;

    final db = ref.read(servicesProvider).db;
    final id = _sessionId;

    if (id != null) {
      final anyWork = _logged.values.any((s) => s.isNotEmpty);
      if (anyWork) {
        await db.finishSession(id);
      } else {
        // Nothing was logged, so no empty session is kept in the history.
        await db.deleteSession(id);
      }

      if (!mounted) return;
      invalidateRecords(ref);

      final session = anyWork ? await db.sessionById(id) : null;
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => WorkoutSummaryScreen(session: session),
        ),
      );
      return;
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<bool> _confirmLeave() async {
    final l10n = AppLocalizations.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.workoutAbandonTitle),
            content: Text(l10n.workoutAbandonBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.actionCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.workoutAbandonConfirm),
              ),
            ],
          ),
    );
    if (leave ?? false) {
      await _persistCurrent();
      await _finish();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unit = ref.watch(settingsProvider).weightUnit;
    final p = _current.prescription;
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(splitLabel(l10n, widget.plan.labelKey)),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _confirmLeave,
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: (_index + 1) / _exercises.length,
              minHeight: 4,
            ),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(Gap.m),
            children: [
              if (widget.isLight) ...[
                SafetyNotice(
                  title: l10n.splitLightActivity,
                  body: l10n.checkProblemBody,
                  icon: Icons.healing_outlined,
                ),
                Gap.h16,
              ],
              const DisclaimerBanner(compact: true),
              Gap.h16,

              Text(
                l10n.workoutExerciseOf(_index + 1, _exercises.length),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Gap.h4,
              Text(
                _exercise.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Gap.h4,
              Text(
                _exercise.primaryMuscles
                    .map((m) => muscleLabel(l10n, m))
                    .join(', '),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),

              // No media is bundled with the app, so no media area is drawn at
              // all rather than showing an empty box or a stock image.
              Gap.h16,
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Gap.m),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.workoutSetOf(
                          _currentSets.length.clamp(0, p.sets) +
                              (_currentDone ? 0 : 1),
                          p.sets,
                        ),
                      ),
                      Gap.h4,
                      Text(
                        _exercise.isTimed
                            ? l10n.workoutTargetSeconds(p.repsMin, p.repsMax)
                            : l10n.workoutTargetReps(p.repsMin, p.repsMax),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (_current.progressionReasonKey != null) ...[
                        Gap.h8,
                        Row(
                          children: [
                            Icon(
                              Icons.auto_graph,
                              size: 14,
                              color: scheme.primary,
                            ),
                            Gap.w8,
                            Expanded(
                              child: Text(
                                progressionLabel(
                                  l10n,
                                  _current.progressionReasonKey!,
                                ),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ],
                      Gap.h16,
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _repsController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText:
                                    _exercise.isTimed
                                        ? l10n.workoutSecondsLabel
                                        : l10n.workoutRepsLabel,
                              ),
                            ),
                          ),
                          if (_exercise.tracksWeight) ...[
                            Gap.w16,
                            Expanded(
                              child: TextField(
                                controller: _weightController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: InputDecoration(
                                  labelText: l10n.workoutWeightLabel(
                                    unit == WeightUnit.kg
                                        ? l10n.unitKg
                                        : l10n.unitLb,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (_exercise.tracksWeight &&
                          _current.suggestedWeightKg == null) ...[
                        Gap.h8,
                        Text(
                          l10n.workoutWeightUnknown,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      Gap.h16,
                      FilledButton(
                        onPressed: _currentDone ? null : _logSet,
                        child: Text(l10n.workoutLogSet),
                      ),
                      if (_currentSets.isNotEmpty) ...[
                        Gap.h8,
                        Wrap(
                          spacing: Gap.s,
                          children: [
                            for (final s in _currentSets)
                              Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text(
                                  s.weightKg == null
                                      ? '${s.seconds ?? s.reps}'
                                      : '${s.reps} x ${_formatWeight(s.weightKg!)}',
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              if (_resting) ...[
                Gap.h16,
                Card(
                  color: scheme.tertiaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(Gap.m),
                    child: Column(
                      children: [
                        Text(
                          l10n.workoutRestTitle,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        Gap.h4,
                        Text(
                          l10n.workoutRestRemaining(
                            _restRemaining < 0 ? 0 : _restRemaining,
                          ),
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Gap.h8,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton(
                              onPressed: () => _startRest(_restRemaining + 30),
                              child: Text(l10n.workoutRestAdd),
                            ),
                            Gap.w16,
                            OutlinedButton(
                              onPressed: _stopRest,
                              child: Text(l10n.workoutRestSkip),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              Gap.h16,
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      onPressed: _replaceExercise,
                      label: Text(l10n.actionReplace),
                    ),
                  ),
                  Gap.w8,
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.skip_next, size: 18),
                      onPressed: _skipExercise,
                      label: Text(l10n.actionSkip),
                    ),
                  ),
                ],
              ),
              Gap.h8,
              FilledButton.tonalIcon(
                icon: const Icon(Icons.arrow_forward),
                onPressed: _currentSets.isEmpty ? null : _askFeedback,
                label: Text(
                  _index >= _exercises.length - 1
                      ? l10n.actionFinish
                      : l10n.workoutNextExercise,
                ),
              ),

              Gap.h24,
              _InstructionBlock(
                title: l10n.workoutHowToTitle,
                items: _exercise.steps,
                numbered: true,
              ),
              _InstructionBlock(
                title: l10n.workoutMistakesTitle,
                items: _exercise.mistakes,
              ),
              _InstructionBlock(
                title: l10n.workoutSafetyTitle,
                items: _exercise.safety,
              ),
              Gap.h8,
              Text(
                '${l10n.workoutEquipmentLabel}: ${_exercise.equipmentDetail}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Gap.h32,
            ],
          ),
        ),
      ),
    );
  }
}

class _InstructionBlock extends StatelessWidget {
  const _InstructionBlock({
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
