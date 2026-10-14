import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/gen/app_localizations.dart';
import '../models/food.dart';
import '../providers/app_providers.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Where the user enters their own local food prices.
///
/// The app ships no prices at all. Budget planning uses only what is entered
/// here, and foods without a price are simply left out of the budget plan.
class FoodPricesScreen extends ConsumerStatefulWidget {
  const FoodPricesScreen({super.key});

  @override
  ConsumerState<FoodPricesScreen> createState() => _FoodPricesScreenState();
}

class _FoodPricesScreenState extends ConsumerState<FoodPricesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final data = ref.watch(guidelineDataProvider);
    final profile = ref.watch(profileProvider).profile;
    final prices = ref.watch(foodPricesProvider);
    final language = Localizations.localeOf(context).languageCode;

    final allowed = profile?.dietType.allowedFoodTags ?? const {'veg'};
    final pool = data.foods.where((f) => f.fitsDiet(allowed)).toList();

    final q = _query.trim().toLowerCase();
    final results =
        q.isEmpty
            ? pool
            : pool
                .where(
                  (f) =>
                      f.name.toLowerCase().contains(q) ||
                      (f.hindiName?.toLowerCase().contains(q) ?? false),
                )
                .toList();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.dietPricesTitle)),
      body: SafeArea(
        child: prices.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (_, _) => Padding(
                padding: const EdgeInsets.all(Gap.m),
                child: ErrorRetry(
                  onRetry: () => ref.invalidate(foodPricesProvider),
                ),
              ),
          data:
              (saved) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(Gap.m),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.dietPricesIntro,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(height: 1.4),
                        ),
                        Gap.h8,
                        Text(
                          l10n.dietPricesCount(saved.length),
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        Gap.h16,
                        TextField(
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            labelText: l10n.dietSearchFood(pool.length),
                          ),
                          onChanged: (v) => setState(() => _query = v),
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
                                message: l10n.dietSearchEmpty,
                              ),
                            )
                            : ListView.builder(
                              itemCount: results.length,
                              itemBuilder: (context, i) {
                                final food = results[i];
                                final price = saved[food.id];
                                return ListTile(
                                  title: Text(food.displayName(language)),
                                  subtitle: Text(
                                    price == null
                                        ? food.ifctGroup
                                        : '${l10n.dietPriceLabel}: '
                                            '${price.pricePerKgInr.toStringAsFixed(0)}',
                                  ),
                                  trailing:
                                      price == null
                                          ? const Icon(Icons.add, size: 20)
                                          : IconButton(
                                            tooltip: l10n.actionDelete,
                                            icon: const Icon(
                                              Icons.close,
                                              size: 18,
                                            ),
                                            onPressed: () async {
                                              await ref
                                                  .read(servicesProvider)
                                                  .db
                                                  .deleteFoodPrice(food.id);
                                              ref.invalidate(
                                                foodPricesProvider,
                                              );
                                              ref.invalidate(mealPlanProvider);
                                            },
                                          ),
                                  onTap: () => _editPrice(food, price),
                                );
                              },
                            ),
                  ),
                ],
              ),
        ),
      ),
    );
  }

  Future<void> _editPrice(Food food, FoodPrice? existing) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(
      text: existing?.pricePerKgInr.toStringAsFixed(0) ?? '',
    );

    final value = await showDialog<double>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(food.name),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: l10n.dietPriceLabel),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.actionCancel),
              ),
              FilledButton(
                onPressed:
                    () => Navigator.of(
                      context,
                    ).pop(double.tryParse(controller.text.trim())),
                child: Text(l10n.actionSave),
              ),
            ],
          ),
    );

    controller.dispose();
    if (value == null || value <= 0) return;

    await ref.read(servicesProvider).db.setFoodPrice(food.id, value);
    ref.invalidate(foodPricesProvider);
    ref.invalidate(mealPlanProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.dietPriceSaved)));
  }
}
