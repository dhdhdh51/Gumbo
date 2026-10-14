import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/gen/app_localizations.dart';
import '../models/guidelines.dart';
import '../models/profile.dart';
import '../providers/app_providers.dart';
import '../services/health_safety.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Pre-exercise health screening, answered once during onboarding and editable
/// afterwards from Settings.
///
/// Any serious yes shows a clear notice to see a doctor and withholds
/// weight-loss targets and high-intensity plans until the user confirms they
/// have medical clearance. The app never diagnoses anything.
class QuestionnaireScreen extends ConsumerStatefulWidget {
  const QuestionnaireScreen({super.key, this.editing = false});

  final bool editing;

  @override
  ConsumerState<QuestionnaireScreen> createState() =>
      _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends ConsumerState<QuestionnaireScreen> {
  final Map<String, bool> _answers = {};
  final _noteController = TextEditingController();
  bool _clearanceConfirmed = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(profileProvider);
    if (existing.healthAnswers.isAnswered) {
      _answers.addAll(existing.healthAnswers.answers);
      _noteController.text = existing.healthAnswers.notes;
      _submitted = true;
    }
    _clearanceConfirmed = existing.clearance.confirmed;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  /// Localised question text for a screening item id.
  String _questionText(AppLocalizations l10n, ScreeningItem item) =>
      switch (item.labelKey) {
        'qHeartCondition' => l10n.qHeartCondition,
        'qChestPain' => l10n.qChestPain,
        'qHighBp' => l10n.qHighBp,
        'qLowBp' => l10n.qLowBp,
        'qDiabetes' => l10n.qDiabetes,
        'qAsthma' => l10n.qAsthma,
        'qRecentSurgery' => l10n.qRecentSurgery,
        'qPregnancy' => l10n.qPregnancy,
        'qEatingDisorder' => l10n.qEatingDisorder,
        'qThyroid' => l10n.qThyroid,
        'qJointInjury' => l10n.qJointInjury,
        'qMedication' => l10n.qMedication,
        'qOtherProblem' => l10n.qOtherProblem,
        _ => item.labelKey,
      };

  Future<void> _save() async {
    final data = ref.read(guidelineDataProvider);

    // Unanswered items are recorded as no, which is what an unticked box means.
    final full = <String, bool>{
      for (final item in data.screeningItems)
        item.id: _answers[item.id] ?? false,
    };

    await ref
        .read(profileProvider.notifier)
        .saveHealthAnswers(
          HealthAnswers(
            answers: full,
            notes: _noteController.text.trim(),
            answeredAt: DateTime.now(),
          ),
        );
    await ref
        .read(profileProvider.notifier)
        .setMedicalClearance(_clearanceConfirmed);

    if (!mounted) return;
    setState(() => _submitted = true);

    final result = HealthSafety.evaluateScreening(
      data: data,
      answers: HealthAnswers(
        answers: full,
        notes: '',
        answeredAt: DateTime.now(),
      ),
      clearance: MedicalClearance(
        confirmed: _clearanceConfirmed,
        confirmedAt: DateTime.now(),
      ),
    );

    // With a serious flag outstanding the user stays on this screen so the
    // notice is read, rather than being dropped straight into the app.
    if (result.blocksWeightLoss) return;

    if (widget.editing) {
      Navigator.of(context).maybePop();
    } else {
      // Onboarding is finished; the startup gate takes over from here.
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final data = ref.watch(guidelineDataProvider);

    final serious = <String>[];
    final caution = <String>[];
    for (final item in data.screeningItems) {
      if (_answers[item.id] != true) continue;
      (item.isSerious ? serious : caution).add(_questionText(l10n, item));
    }
    final hasSerious = serious.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.questionnaireTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Gap.m),
          children: [
            Text(
              l10n.questionnaireIntro,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
            Gap.h16,
            const DisclaimerBanner(compact: true),
            Gap.h24,

            for (final item in data.screeningItems)
              Card(
                margin: const EdgeInsets.only(bottom: Gap.s),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.m,
                    Gap.s,
                    Gap.s,
                    Gap.s,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _questionText(l10n, item),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Gap.w8,
                      SegmentedButton<bool>(
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        segments: [
                          ButtonSegment(
                            value: false,
                            label: Text(l10n.actionNo),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text(l10n.actionYes),
                          ),
                        ],
                        selected: {_answers[item.id] ?? false},
                        onSelectionChanged:
                            (s) => setState(() => _answers[item.id] = s.first),
                      ),
                    ],
                  ),
                ),
              ),

            Gap.h16,
            Text(
              l10n.questionnaireAnyOther,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Gap.h8,
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: l10n.questionnaireAnyOtherHint,
              ),
            ),

            if (hasSerious) ...[
              Gap.h24,
              SafetyNotice(
                title: l10n.screeningDoctorTitle,
                body:
                    '${l10n.screeningDoctorBody}\n\n'
                    '${l10n.screeningFlagsListed(serious.join('; '))}',
              ),
              Gap.h16,
              CheckboxListTile(
                value: _clearanceConfirmed,
                onChanged:
                    (v) => setState(() => _clearanceConfirmed = v ?? false),
                title: Text(l10n.screeningClearanceConfirm),
                subtitle: Text(l10n.screeningClearanceNote),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ] else if (caution.isNotEmpty) ...[
              Gap.h24,
              SafetyNotice(
                title: l10n.screeningDoctorTitle,
                body:
                    '${l10n.screeningCautionBody}\n\n'
                    '${l10n.screeningFlagsListed(caution.join('; '))}',
                icon: Icons.info_outline,
              ),
            ],

            Gap.h16,
            Text(
              data.screeningNote,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            SourceChip(
              sourceId: data.screeningItems.isEmpty ? null : 'icmr_dgi_2024',
            ),

            Gap.h24,
            FilledButton(
              onPressed: _save,
              child: Text(
                widget.editing ? l10n.actionSave : l10n.actionContinue,
              ),
            ),
            if (_submitted && hasSerious && !_clearanceConfirmed) ...[
              Gap.h16,
              Text(
                l10n.screeningDoctorBody,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              Gap.h8,
              OutlinedButton(
                onPressed:
                    () => Navigator.of(
                      context,
                    ).popUntil((route) => route.isFirst),
                child: Text(l10n.actionContinue),
              ),
            ],
            Gap.h32,
          ],
        ),
      ),
    );
  }
}
