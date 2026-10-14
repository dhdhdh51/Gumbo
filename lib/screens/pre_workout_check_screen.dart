import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/gen/app_localizations.dart';
import '../models/enums.dart';
import '../models/workout.dart';
import '../providers/app_providers.dart';
import '../services/health_safety.dart';
import '../services/plan_builder.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'active_workout_screen.dart';

/// Shown EVERY time the user taps Start Workout. There is no way to reach the
/// active workout screen without passing through here.
///
/// A red flag (chest pain, fainting, severe breathlessness) stops everything.
/// Any other reported problem replaces the planned session with light activity
/// or lets the user skip the day.
class PreWorkoutCheckScreen extends ConsumerStatefulWidget {
  const PreWorkoutCheckScreen({super.key, required this.plan});

  final PlannedDay plan;

  @override
  ConsumerState<PreWorkoutCheckScreen> createState() =>
      _PreWorkoutCheckScreenState();
}

class _PreWorkoutCheckScreenState extends ConsumerState<PreWorkoutCheckScreen> {
  /// Null until the user answers, so neither option is preselected.
  bool? _hasProblem;
  final Set<String> _redFlags = {};
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String _flagLabel(AppLocalizations l10n, String id) => switch (id) {
    'chest_pain_today' => l10n.flagChestPain,
    'fainting_today' => l10n.flagFainting,
    'severe_breathlessness_today' => l10n.flagBreathless,
    _ => id,
  };

  PreWorkoutDecision get _decision => HealthSafety.evaluateDailyCheck(
    hasProblem: _hasProblem ?? false,
    redFlags: _redFlags,
  );

  Future<void> _record(PreWorkoutOutcome chosen) async {
    final record = HealthSafety.recordFor(
      decision: _decision,
      hasProblem: _hasProblem ?? false,
      note: _noteController.text,
      chosen: chosen,
    );
    await ref.read(servicesProvider).db.savePreWorkoutCheck(record);
  }

  Future<void> _startNormal() async {
    await _record(PreWorkoutOutcome.proceedNormal);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder:
            (_) => ActiveWorkoutScreen(
              plan: widget.plan,
              note:
                  _noteController.text.trim().isEmpty
                      ? null
                      : _noteController.text.trim(),
            ),
      ),
    );
  }

  Future<void> _startLight() async {
    await _record(PreWorkoutOutcome.lightActivityOnly);
    if (!mounted) return;
    final light = PlanBuilder.buildLightSession(
      data: ref.read(guidelineDataProvider),
      place: ref.read(profileProvider).profile!.place,
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder:
            (_) => ActiveWorkoutScreen(
              plan: light,
              isLight: true,
              note:
                  _noteController.text.trim().isEmpty
                      ? null
                      : _noteController.text.trim(),
            ),
      ),
    );
  }

  Future<void> _skipToday() async {
    await _record(PreWorkoutOutcome.skipToday);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _acknowledgeEmergency() async {
    await _record(PreWorkoutOutcome.seekHelpNow);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final data = ref.watch(guidelineDataProvider);
    final decision = _decision;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.checkTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Gap.m),
          children: [
            const DisclaimerBanner(compact: true),
            Gap.h24,

            Text(
              l10n.checkQuestion,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(height: 1.4),
            ),
            Gap.h16,
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style:
                        _hasProblem == false
                            ? OutlinedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                            )
                            : null,
                    onPressed:
                        () => setState(() {
                          _hasProblem = false;
                          _redFlags.clear();
                        }),
                    child: Text(l10n.actionNo),
                  ),
                ),
                Gap.w16,
                Expanded(
                  child: OutlinedButton(
                    style:
                        _hasProblem == true
                            ? OutlinedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.errorContainer,
                            )
                            : null,
                    onPressed: () => setState(() => _hasProblem = true),
                    child: Text(l10n.actionYes),
                  ),
                ),
              ],
            ),

            Gap.h24,
            // The red flags are always visible, not hidden behind a Yes, so a
            // user with chest pain is never one tap away from training.
            Text(
              l10n.checkRedFlagHeading,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Gap.h8,
            for (final id in data.redFlagKeys)
              CheckboxListTile(
                value: _redFlags.contains(id),
                onChanged:
                    (v) => setState(() {
                      if (v ?? false) {
                        _redFlags.add(id);
                      } else {
                        _redFlags.remove(id);
                      }
                    }),
                title: Text(_flagLabel(l10n, id)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),

            Gap.h16,
            Text(
              l10n.checkNoteLabel,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Gap.h8,
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: InputDecoration(hintText: l10n.checkNoteHint),
            ),

            Gap.h24,

            if (decision.isEmergency) ...[
              SafetyNotice(
                severe: true,
                icon: Icons.emergency_outlined,
                title: l10n.checkEmergencyTitle,
                body: l10n.checkEmergencyBody,
              ),
              Gap.h16,
              OutlinedButton(
                onPressed: _acknowledgeEmergency,
                child: Text(l10n.actionClose),
              ),
            ] else if (decision.offerLightActivity) ...[
              SafetyNotice(
                title: l10n.checkProblemTitle,
                body: l10n.checkProblemBody,
              ),
              Gap.h16,
              FilledButton.tonal(
                onPressed: _startLight,
                child: Text(l10n.checkChooseLight),
              ),
              Gap.h8,
              OutlinedButton(
                onPressed: _skipToday,
                child: Text(l10n.checkChooseSkip),
              ),
            ] else if (_hasProblem == false) ...[
              FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                onPressed: _startNormal,
                label: Text(l10n.checkProceed),
              ),
            ],
            Gap.h32,
          ],
        ),
      ),
    );
  }
}
