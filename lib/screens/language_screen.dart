import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/gen/app_localizations.dart';
import '../providers/app_providers.dart';
import '../theme.dart';

/// Language selection, shown before anything else so every safety notice is
/// read in a language the user chose.
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Gap.l),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.language,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  Gap.h24,
                  Text(
                    l10n.languageTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Gap.h8,
                  Text(
                    l10n.languageSubtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Gap.h32,
                  _LanguageButton(
                    label: l10n.languageEnglish,
                    onTap:
                        () => ref
                            .read(settingsProvider.notifier)
                            .setLocale(const Locale('en')),
                  ),
                  Gap.h16,
                  _LanguageButton(
                    label: l10n.languageHindi,
                    onTap:
                        () => ref
                            .read(settingsProvider.notifier)
                            .setLocale(const Locale('hi')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FilledButton.tonal(
    onPressed: onTap,
    child: Text(label, style: const TextStyle(fontSize: 18)),
  );
}
