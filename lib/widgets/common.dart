import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/gen/app_localizations.dart';
import '../models/guidelines.dart';
import '../providers/app_providers.dart';
import '../theme.dart';

/// The standing disclaimer. Shown on first launch, on the workout and diet
/// screens, and on the Sources screen.
class DisclaimerBanner extends StatelessWidget {
  const DisclaimerBanner({super.key, this.compact = false, this.onTap});

  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: scheme.errorContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.error.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Gap.m),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: 20,
                color: scheme.onErrorContainer,
              ),
              Gap.w8,
              Expanded(
                child: Text(
                  l10n.disclaimerText,
                  maxLines: compact ? 3 : null,
                  overflow: compact ? TextOverflow.ellipsis : null,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onErrorContainer,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A prominent safety notice, used for screening flags and emergencies.
class SafetyNotice extends StatelessWidget {
  const SafetyNotice({
    super.key,
    required this.title,
    required this.body,
    this.icon = Icons.warning_amber_rounded,
    this.severe = false,
    this.action,
  });

  final String title;
  final String body;
  final IconData icon;
  final bool severe;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = severe ? scheme.error : scheme.errorContainer;
    final fg = severe ? scheme.onError : scheme.onErrorContainer;

    return Card(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.all(Gap.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: fg),
                Gap.w8,
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            Gap.h8,
            Text(
              body,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: fg, height: 1.4),
            ),
            if (action != null) ...[Gap.h16, action!],
          ],
        ),
      ),
    );
  }
}

/// Heading plus optional trailing action, used to open every section.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Shown instead of a chart or list when the user has no data yet.
///
/// The app never fills these with sample data.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: Gap.l, horizontal: Gap.m),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: scheme.onSurfaceVariant),
          Gap.h8,
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (action != null) ...[Gap.h16, action!],
        ],
      ),
    );
  }
}

/// Small tappable citation shown next to any sourced value.
class SourceChip extends ConsumerWidget {
  const SourceChip({super.key, required this.sourceId, this.prefix});

  final String? sourceId;
  final String? prefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final data = ref.watch(guidelineDataProvider);
    final source = data.source(sourceId);
    if (source == null) return const SizedBox.shrink();

    return Tooltip(
      message: '${source.name}\n${source.publisher}, ${source.year}',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => showSourceSheet(context, source, l10n),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '${prefix ?? l10n.labelSource}: ${source.shortLabel}',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Marks a figure the app chose itself rather than took from a publication.
class AppRuleChip extends StatelessWidget {
  const AppRuleChip({super.key, this.note});

  final String? note;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Tooltip(
      message: note ?? l10n.labelAppRule,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shield_outlined,
              size: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              l10n.labelAppRule,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet with the full citation and a link out to the publication.
Future<void> showSourceSheet(
  BuildContext context,
  DataSource source,
  AppLocalizations l10n,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder:
        (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, Gap.l),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Gap.h8,
                Text(
                  source.publisher,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Gap.h4,
                Text(
                  l10n.sourcesPublishedYear(source.year),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (source.edition != null)
                  Text(
                    source.edition!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (source.accessed != null)
                  Text(
                    l10n.sourcesAccessed(source.accessed!),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                Gap.h16,
                SelectableText(
                  source.url,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Gap.h16,
                OutlinedButton.icon(
                  onPressed: () async {
                    final uri = Uri.tryParse(source.url);
                    final ok =
                        uri != null &&
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.sourcesCouldNotOpen)),
                      );
                    }
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l10n.sourcesOpenLink),
                ),
              ],
            ),
          ),
        ),
  );
}

/// A single number with a label, used across Home, Diet and Progress.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.progress,
    this.icon,
  });

  final String label;
  final String value;
  final String? caption;

  /// 0 to 1, or null for no bar.
  final double? progress;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            Gap.h4,
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (progress != null) ...[
              Gap.h8,
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress!.clamp(0, 1),
                  minHeight: 6,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
            ],
            if (caption != null) ...[
              Gap.h4,
              Text(
                caption!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Wraps a Premium-only area. Free users see why it is locked and a way up.
class PremiumLock extends StatelessWidget {
  const PremiumLock({super.key, required this.onUpgrade});

  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_outline, size: 20),
                Gap.w8,
                Expanded(child: Text(l10n.paywallLockedFeature)),
              ],
            ),
            Gap.h16,
            FilledButton.tonal(
              onPressed: onUpgrade,
              child: Text(l10n.paywallUpgrade),
            ),
          ],
        ),
      ),
    );
  }
}

/// Standard page padding with a bottom inset so content clears the nav bar.
class PagePadding extends StatelessWidget {
  const PagePadding({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Gap.m, Gap.s, Gap.m, Gap.xl),
    child: child,
  );
}

/// Shows an error with a retry, used for every async provider in the app.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      icon: Icons.error_outline,
      message: l10n.errorGeneric,
      action: OutlinedButton(onPressed: onRetry, child: Text(l10n.actionRetry)),
    );
  }
}
