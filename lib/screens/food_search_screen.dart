import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/gen/app_localizations.dart';
import '../models/diet.dart';
import '../models/enums.dart';
import '../models/food.dart';
import '../providers/app_providers.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Search the IFCT food database and log a portion.
class FoodSearchScreen extends ConsumerStatefulWidget {
  const FoodSearchScreen({super.key});

  @override
  ConsumerState<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends ConsumerState<FoodSearchScreen> {
  final _queryController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final data = ref.watch(guidelineDataProvider);
    final profile = ref.watch(profileProvider).profile;
    final language = Localizations.localeOf(context).languageCode;

    // Only foods the user's diet allows are offered, so a vegetarian is never
    // shown chicken.
    final allowed = profile?.dietType.allowedFoodTags ?? const {'veg'};
    final pool = data.foods.where((f) => f.fitsDiet(allowed)).toList();

    final q = _query.trim().toLowerCase();
    final results =
        q.isEmpty
            ? pool
            : pool.where((f) {
              return f.name.toLowerCase().contains(q) ||
                  (f.hindiName?.toLowerCase().contains(q) ?? false) ||
                  f.ifctGroup.toLowerCase().contains(q);
            }).toList();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.dietAddFood)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(Gap.m),
              child: TextField(
                controller: _queryController,
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  labelText: l10n.dietSearchFood(pool.length),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child:
                  results.isEmpty
                      ? Padding(
                        padding: const EdgeInsets.all(Gap.m),
                        child: EmptyState(
                          icon: Icons.search_off,
                          message: l10n.dietSearchEmpty,
                        ),
                      )
                      : ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (context, i) {
                          final food = results[i];
                          return ListTile(
                            title: Text(food.displayName(language)),
                            subtitle: Text(
                              '${food.ifctGroup} · ${food.kcal} ${l10n.unitKcal} / 100 ${l10n.unitGram}'
                              ' · ${food.proteinPer100g.toStringAsFixed(1)} ${l10n.unitGram} '
                              '${l10n.dietNutrientProtein}',
                            ),
                            onTap: () => _showPortionSheet(food, language),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPortionSheet(Food food, String language) async {
    final l10n = AppLocalizations.of(context);
    final gramsController = TextEditingController(
      text: (food.servingG ?? 100).toString(),
    );
    var slot = MealSlot.breakfast;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: StatefulBuilder(
              builder:
                  (context, setSheetState) => SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        Gap.m,
                        0,
                        Gap.m,
                        Gap.l,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            food.displayName(language),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Gap.h4,
                          Text(
                            food.ifctGroup,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Gap.h16,

                          Text(
                            l10n.dietPer100g,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Gap.h4,
                          Wrap(
                            spacing: Gap.s,
                            runSpacing: Gap.xs,
                            children: [
                              _NutrientChip(
                                label: l10n.dietNutrientKcal,
                                value: '${food.kcal} ${l10n.unitKcal}',
                              ),
                              _NutrientChip(
                                label: l10n.dietNutrientProtein,
                                value:
                                    '${food.proteinPer100g.toStringAsFixed(1)} ${l10n.unitGram}',
                              ),
                              _NutrientChip(
                                label: l10n.dietNutrientCarbs,
                                value:
                                    '${food.carbPer100g.toStringAsFixed(1)} ${l10n.unitGram}',
                              ),
                              _NutrientChip(
                                label: l10n.dietNutrientFat,
                                value:
                                    '${food.fatPer100g.toStringAsFixed(1)} ${l10n.unitGram}',
                              ),
                              if (food.fibreG != null)
                                _NutrientChip(
                                  label: l10n.dietNutrientFibre,
                                  value:
                                      '${food.fibreG!.toStringAsFixed(1)} ${l10n.unitGram}',
                                ),
                            ],
                          ),
                          const SourceChip(sourceId: 'ifct_2017'),
                          if (food.energyDerived) ...[
                            Gap.h8,
                            Text(
                              l10n.dietEnergyDerivedNote,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            SourceChip(sourceId: food.energySourceId),
                          ],

                          Gap.h16,
                          if (food.hasServing) ...[
                            Text(
                              l10n.dietServingLabel(food.servingG!),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            SourceChip(sourceId: food.servingSourceId),
                          ] else
                            Text(
                              l10n.dietNoServingNote,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),

                          Gap.h16,
                          TextField(
                            controller: gramsController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: l10n.dietGramsLabel,
                              suffixText: l10n.unitGram,
                            ),
                            onChanged: (_) => setSheetState(() {}),
                          ),
                          Gap.h16,
                          DropdownButtonFormField<MealSlot>(
                            initialValue: slot,
                            decoration: InputDecoration(
                              labelText: l10n.dietMealBreakfast,
                            ),
                            items: [
                              for (final s in MealSlot.values)
                                DropdownMenuItem(
                                  value: s,
                                  child: Text(_slotName(l10n, s)),
                                ),
                            ],
                            onChanged:
                                (v) => setSheetState(
                                  () => slot = v ?? MealSlot.breakfast,
                                ),
                          ),
                          Gap.h16,
                          Builder(
                            builder: (context) {
                              final grams =
                                  double.tryParse(
                                    gramsController.text.trim(),
                                  ) ??
                                  0;
                              return Text(
                                '${food.kcalFor(grams).round()} ${l10n.unitKcal} · '
                                '${food.proteinFor(grams).toStringAsFixed(1)} ${l10n.unitGram} '
                                '${l10n.dietNutrientProtein}',
                                style: Theme.of(context).textTheme.titleMedium,
                              );
                            },
                          ),
                          Gap.h16,
                          FilledButton(
                            onPressed: () async {
                              final grams = double.tryParse(
                                gramsController.text.trim(),
                              );
                              if (grams == null || grams <= 0) return;
                              final prices =
                                  ref.read(foodPricesProvider).value ??
                                  const {};
                              await ref
                                  .read(servicesProvider)
                                  .db
                                  .logFood(
                                    slot: slot,
                                    item: MealItem.fromFood(
                                      food,
                                      grams,
                                      pricePerKgInr:
                                          prices[food.id]?.pricePerKgInr,
                                    ),
                                  );
                              ref.invalidate(todayTotalsProvider);
                              ref.invalidate(todayFoodLogProvider);
                              if (!context.mounted) return;
                              Navigator.of(context).pop();
                            },
                            child: Text(l10n.actionAdd),
                          ),
                        ],
                      ),
                    ),
                  ),
            ),
          ),
    );

    gramsController.dispose();
  }

  String _slotName(AppLocalizations l10n, MealSlot s) => switch (s) {
    MealSlot.breakfast => l10n.dietMealBreakfast,
    MealSlot.lunch => l10n.dietMealLunch,
    MealSlot.snack => l10n.dietMealSnack,
    MealSlot.dinner => l10n.dietMealDinner,
  };
}

class _NutrientChip extends StatelessWidget {
  const _NutrientChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) =>
      Chip(visualDensity: VisualDensity.compact, label: Text('$label: $value'));
}
