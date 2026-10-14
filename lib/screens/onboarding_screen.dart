import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants.dart';
import '../l10n/gen/app_localizations.dart';
import '../models/enums.dart';
import '../models/profile.dart';
import '../providers/app_providers.dart';
import '../services/age_rules.dart';
import '../services/calculations.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'questionnaire_screen.dart';

/// Onboarding wizard, and the same form reused for "edit profile".
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.editing = false});

  /// When true the screen edits an existing profile instead of creating one,
  /// so it skips the questionnaire and pops when saved.
  final bool editing;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  final _nameController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  int _step = 0;
  static const int _stepCount = 7;

  int? _age;
  Sex _sex = Sex.male;
  Goal _goal = Goal.maintain;
  int _days = 3;
  TrainingPlace _place = TrainingPlace.home;
  ExperienceLevel _experience = ExperienceLevel.beginner;
  ActivityLevel _activity = ActivityLevel.sedentary;
  DietType _diet = DietType.veg;
  int _budget = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(profileProvider).profile;
    if (existing != null) {
      _nameController.text = existing.name;
      _age = existing.age;
      _sex = existing.sex;
      _heightController.text = existing.heightCm.toStringAsFixed(0);
      _weightController.text = existing.weightKg.toStringAsFixed(1);
      _goal = existing.goal;
      _days = existing.daysPerWeek;
      _place = existing.place;
      _experience = existing.experience;
      _activity = existing.activityLevel;
      _diet = existing.dietType;
      _budget = existing.monthlyFoodBudgetInr;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  double? get _heightCm => double.tryParse(_heightController.text.trim());
  double? get _weightKg => double.tryParse(_weightController.text.trim());

  /// Whether a weight-loss goal may be offered, given age and BMI.
  bool get _weightLossAllowed {
    final age = _age;
    final h = _heightCm;
    final w = _weightKg;
    if (age == null) return true;
    final data = ref.read(guidelineDataProvider);
    final decision = AgeRules.decide(data: data, age: age);
    if (!decision.allowWeightLossGoal) return false;
    if (h == null || w == null) return true;
    return !Calculations.weightLossBlockedByBmi(
      data: data,
      weightKg: w,
      heightCm: h,
    );
  }

  String? _validateStep(AppLocalizations l10n) {
    switch (_step) {
      case 0:
        if (_nameController.text.trim().isEmpty) {
          return l10n.onboardingNameRequired;
        }
      case 1:
        final age = _age;
        if (age == null || age < 1 || age > 120) {
          return l10n.onboardingAgeInvalid;
        }
      case 2:
        final h = _heightCm;
        if (h == null || h < 100 || h > 250) {
          return l10n.onboardingHeightInvalid;
        }
        final w = _weightKg;
        if (w == null || w < 25 || w > 300) {
          return l10n.onboardingWeightInvalid;
        }
      default:
        return null;
    }
    return null;
  }

  void _next() {
    final l10n = AppLocalizations.of(context);
    final error = _validateStep(l10n);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() => _error = null);

    // A goal that became invalid after age or weight changed is corrected here
    // rather than silently carried forward.
    if (_goal == Goal.lose && !_weightLossAllowed) {
      _goal = Goal.maintain;
    }

    if (_step < _stepCount - 1) {
      setState(() => _step++);
      _controller.animateToPage(
        _step,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _finish();
    }
  }

  void _back() {
    if (_step == 0) {
      if (widget.editing) Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _step--;
      _error = null;
    });
    _controller.animateToPage(
      _step,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finish() async {
    final existing = ref.read(profileProvider).profile;
    final profile = UserProfile(
      name: _nameController.text.trim(),
      age: _age!,
      sex: _sex,
      heightCm: _heightCm!,
      weightKg: _weightKg!,
      goal: _weightLossAllowed || _goal != Goal.lose ? _goal : Goal.maintain,
      daysPerWeek: _days,
      place: _place,
      experience: _experience,
      dietType: _diet,
      activityLevel: _activity,
      monthlyFoodBudgetInr: _budget,
      createdAt: existing?.createdAt ?? DateTime.now(),
      // Keep the original plan anchor on edit so the split rotation and the
      // deload count do not restart every time the profile is touched.
      planStartDate: existing?.effectivePlanStart ?? DateTime.now(),
    );

    await ref.read(profileProvider.notifier).save(profile);
    if (!mounted) return;

    if (widget.editing) {
      Navigator.of(context).maybePop();
      return;
    }

    // First run continues straight into the health questionnaire.
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const QuestionnaireScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isLast = _step == _stepCount - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editing ? l10n.settingsEditProfile : l10n.onboardingTitle,
        ),
        leading: BackButton(onPressed: _back),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / _stepCount,
            minHeight: 4,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _stepName(l10n),
                  _stepAgeSex(l10n),
                  _stepBody(l10n),
                  _stepGoal(l10n),
                  _stepTraining(l10n),
                  _stepLevel(l10n),
                  _stepDiet(l10n),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.m),
                child: Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(Gap.m),
              child: Row(
                children: [
                  Text(
                    l10n.onboardingStep(_step + 1, _stepCount),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _next,
                    child: Text(
                      isLast
                          ? (widget.editing
                              ? l10n.actionSave
                              : l10n.onboardingFinish)
                          : l10n.actionNext,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _page({
    required String title,
    String? note,
    required List<Widget> children,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Gap.m),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (note != null) ...[
              Gap.h8,
              Text(
                note,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            Gap.h24,
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _stepName(AppLocalizations l10n) => _page(
    title: l10n.onboardingName,
    children: [
      TextField(
        controller: _nameController,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: l10n.onboardingNameHint),
        onChanged: (_) => setState(() => _error = null),
      ),
    ],
  );

  Widget _stepAgeSex(AppLocalizations l10n) => _page(
    title: l10n.onboardingAge,
    note: l10n.onboardingSexNote,
    children: [
      TextField(
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: l10n.onboardingAge),
        controller: TextEditingController(text: _age?.toString() ?? '')
          ..selection = TextSelection.collapsed(
            offset: (_age?.toString() ?? '').length,
          ),
        onChanged:
            (v) => setState(() {
              _age = int.tryParse(v);
              _error = null;
            }),
      ),
      Gap.h24,
      Text(l10n.onboardingSex, style: Theme.of(context).textTheme.titleSmall),
      Gap.h8,
      SegmentedButton<Sex>(
        segments: [
          ButtonSegment(value: Sex.male, label: Text(l10n.onboardingSexMale)),
          ButtonSegment(
            value: Sex.female,
            label: Text(l10n.onboardingSexFemale),
          ),
        ],
        selected: {_sex},
        onSelectionChanged: (s) => setState(() => _sex = s.first),
      ),
    ],
  );

  Widget _stepBody(AppLocalizations l10n) => _page(
    title: '${l10n.onboardingHeight} / ${l10n.onboardingWeight}',
    children: [
      TextField(
        controller: _heightController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: l10n.onboardingHeight,
          suffixText: l10n.unitCm,
        ),
        onChanged: (_) => setState(() => _error = null),
      ),
      Gap.h16,
      TextField(
        controller: _weightController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: l10n.onboardingWeight,
          suffixText: l10n.unitKg,
        ),
        onChanged: (_) => setState(() => _error = null),
      ),
    ],
  );

  Widget _stepGoal(AppLocalizations l10n) {
    final age = _age ?? 0;
    final data = ref.read(guidelineDataProvider);
    final decision = AgeRules.decide(data: data, age: age);
    final bmiBlocks =
        _heightCm != null &&
        _weightKg != null &&
        Calculations.weightLossBlockedByBmi(
          data: data,
          weightKg: _weightKg!,
          heightCm: _heightCm!,
        );

    return _page(
      title: l10n.onboardingGoal,
      children: [
        RadioGroup<Goal>(
          groupValue: _goal,
          onChanged: (g) => setState(() => _goal = g ?? _goal),
          child: Column(
            children: [
              RadioListTile<Goal>(
                value: Goal.maintain,
                title: Text(l10n.onboardingGoalMaintain),
              ),
              RadioListTile<Goal>(
                value: Goal.gain,
                title: Text(l10n.onboardingGoalGain),
              ),
              RadioListTile<Goal>(
                value: Goal.lose,
                title: Text(l10n.onboardingGoalLose),
                subtitle:
                    !decision.allowWeightLossGoal
                        ? Text(l10n.onboardingGoalLoseBlockedAge)
                        : bmiBlocks
                        ? Text(l10n.onboardingGoalLoseBlockedBmi)
                        : null,
                enabled: _weightLossAllowed,
              ),
            ],
          ),
        ),
        if (decision.access == AccessLevel.activityOnly) ...[
          Gap.h16,
          SafetyNotice(
            title: l10n.ageTeenNoticeTitle,
            body: decision.message ?? l10n.ageTeenNoticeBody,
            icon: Icons.school_outlined,
          ),
        ],
        if (decision.access == AccessLevel.fullLighterDefault) ...[
          Gap.h16,
          SafetyNotice(
            title: l10n.ageOlderNoticeTitle,
            body: decision.message ?? l10n.ageOlderNoticeBody,
            icon: Icons.favorite_outline,
          ),
        ],
      ],
    );
  }

  Widget _stepTraining(AppLocalizations l10n) {
    final premium = ref.watch(isPremiumProvider);
    final maxDays = premium ? 6 : Entitlements.freeMaxDaysPerWeek;

    return _page(
      title: l10n.onboardingDays,
      note: premium ? null : l10n.onboardingDaysFreeNote,
      children: [
        Slider(
          value: _days.clamp(3, maxDays).toDouble(),
          min: 3,
          max: 6,
          divisions: 3,
          label: l10n.onboardingDaysValue(_days),
          onChanged: (v) {
            final next = v.round();
            setState(() => _days = next > maxDays ? maxDays : next);
          },
        ),
        Center(
          child: Text(
            l10n.onboardingDaysValue(_days),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Gap.h24,
        Text(
          l10n.onboardingPlace,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Gap.h8,
        SegmentedButton<TrainingPlace>(
          segments: [
            ButtonSegment(
              value: TrainingPlace.gym,
              label: Text(l10n.onboardingPlaceGym),
              icon: const Icon(Icons.fitness_center),
            ),
            ButtonSegment(
              value: TrainingPlace.home,
              label: Text(l10n.onboardingPlaceHome),
              icon: const Icon(Icons.home_outlined),
            ),
          ],
          selected: {_place},
          onSelectionChanged: (s) => setState(() => _place = s.first),
        ),
        Gap.h8,
        Text(
          l10n.onboardingPlaceNote,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _stepLevel(AppLocalizations l10n) => _page(
    title: l10n.onboardingExperience,
    note: l10n.onboardingActivityNote,
    children: [
      RadioGroup<ExperienceLevel>(
        groupValue: _experience,
        onChanged: (v) => setState(() => _experience = v ?? _experience),
        child: Column(
          children: [
            RadioListTile<ExperienceLevel>(
              value: ExperienceLevel.beginner,
              title: Text(l10n.onboardingExperienceBeginner),
            ),
            RadioListTile<ExperienceLevel>(
              value: ExperienceLevel.intermediate,
              title: Text(l10n.onboardingExperienceIntermediate),
            ),
            RadioListTile<ExperienceLevel>(
              value: ExperienceLevel.advanced,
              title: Text(l10n.onboardingExperienceAdvanced),
            ),
          ],
        ),
      ),
      Gap.h24,
      Text(
        l10n.onboardingActivity,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      Gap.h8,
      RadioGroup<ActivityLevel>(
        groupValue: _activity,
        onChanged: (v) => setState(() => _activity = v ?? _activity),
        child: Column(
          children: [
            RadioListTile<ActivityLevel>(
              value: ActivityLevel.sedentary,
              title: Text(l10n.onboardingActivitySedentary),
            ),
            RadioListTile<ActivityLevel>(
              value: ActivityLevel.moderate,
              title: Text(l10n.onboardingActivityModerate),
            ),
            RadioListTile<ActivityLevel>(
              value: ActivityLevel.heavy,
              title: Text(l10n.onboardingActivityHeavy),
            ),
          ],
        ),
      ),
      const SourceChip(sourceId: 'icmr_rda_2020'),
    ],
  );

  Widget _stepDiet(AppLocalizations l10n) => _page(
    title: l10n.onboardingDiet,
    children: [
      RadioGroup<DietType>(
        groupValue: _diet,
        onChanged: (v) => setState(() => _diet = v ?? _diet),
        child: Column(
          children: [
            RadioListTile<DietType>(
              value: DietType.veg,
              title: Text(l10n.onboardingDietVeg),
            ),
            RadioListTile<DietType>(
              value: DietType.egg,
              title: Text(l10n.onboardingDietEgg),
            ),
            RadioListTile<DietType>(
              value: DietType.nonVeg,
              title: Text(l10n.onboardingDietNonVeg),
            ),
          ],
        ),
      ),
      Gap.h24,
      Text(
        l10n.onboardingBudget,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      Gap.h8,
      Slider(
        value: _budget.toDouble(),
        min: 0,
        max: 30000,
        divisions: 60,
        label:
            _budget == 0
                ? l10n.onboardingBudgetNone
                : l10n.onboardingBudgetValue(_budget.toString()),
        onChanged: (v) => setState(() => _budget = v.round()),
      ),
      Center(
        child: Text(
          _budget == 0
              ? l10n.onboardingBudgetNone
              : l10n.onboardingBudgetValue(_budget.toString()),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      Gap.h8,
      Text(
        l10n.onboardingBudgetNote,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}
