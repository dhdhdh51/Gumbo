import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/gen/app_localizations.dart';
import '../providers/app_providers.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Sources and disclaimer, reachable from the Home menu and from Settings at
/// any time.
class SourcesScreen extends ConsumerWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final data = ref.watch(guidelineDataProvider);

    final sources =
        data.sources.values.toList()..sort((a, b) {
          final byPublisher = a.publisher.compareTo(b.publisher);
          return byPublisher != 0 ? byPublisher : b.year.compareTo(a.year);
        });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.sourcesTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Gap.m),
          children: [
            Text(
              l10n.sourcesDisclaimerHeading,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            Gap.h8,
            const DisclaimerBanner(),
            Gap.h24,

            Text(
              l10n.sourcesIntro,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
            Gap.h24,

            SectionHeader(title: l10n.sourcesListHeading),
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < sources.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      title: Text(sources[i].name),
                      subtitle: Text(
                        '${sources[i].publisher}\n'
                        '${l10n.sourcesPublishedYear(sources[i].year)}'
                        '${sources[i].edition == null ? '' : ' · ${sources[i].edition}'}',
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.open_in_new, size: 18),
                      onTap: () => showSourceSheet(context, sources[i], l10n),
                    ),
                  ],
                ],
              ),
            ),

            Gap.h24,
            _NoteCard(
              icon: Icons.fitness_center,
              text: l10n.sourcesExerciseNote,
            ),
            Gap.h8,
            _NoteCard(
              icon: Icons.restaurant_outlined,
              text: l10n.sourcesFoodNote,
            ),
            Gap.h8,
            _NoteCard(icon: Icons.currency_rupee, text: l10n.sourcesPriceNote),
            Gap.h8,
            _NoteCard(
              icon: Icons.shield_outlined,
              text: l10n.labelAppRule,
              subtitle:
                  data.weightSafety['maxLossPercentBodyWeightPerWeek']?.note,
            ),

            Gap.h24,
            SectionHeader(title: l10n.progressActivityHeading),
            Card(
              child: Column(
                children: [
                  for (final note in data.medicalClearanceNotes)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.info_outline, size: 18),
                      title: Text(note.text),
                      subtitle: SourceChip(sourceId: note.sourceId),
                    ),
                ],
              ),
            ),
            Gap.h32,
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.icon, required this.text, this.subtitle});

  final IconData icon;
  final String text;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(Gap.m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          Gap.w8,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(height: 1.4),
                ),
                if (subtitle != null) ...[
                  Gap.h4,
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      height: 1.4,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
