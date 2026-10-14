import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/gen/app_localizations.dart';
import '../providers/app_providers.dart';
import '../theme.dart';

/// Full-screen disclaimer and privacy notice shown on first launch.
///
/// The user must tick both boxes before the app will continue. There is no
/// way past this screen other than accepting.
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _understood = false;
  bool _privacyAccepted = false;

  bool get _canContinue => _understood && _privacyAccepted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          // Stretch so the Continue button spans the width. The button theme
          // deliberately carries a finite minimum width, so full width has to
          // come from the layout.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Gap.m),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Gap.h16,
                      Row(
                        children: [
                          Icon(
                            Icons.health_and_safety_outlined,
                            color: scheme.primary,
                          ),
                          Gap.w8,
                          Expanded(
                            child: Text(
                              l10n.consentTitle,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      Gap.h24,

                      // The disclaimer in full, not truncated.
                      Card(
                        color: scheme.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(Gap.m),
                          child: Text(
                            l10n.disclaimerText,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              color: scheme.onErrorContainer,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                      Gap.h24,

                      Text(
                        l10n.consentPrivacyHeading,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Gap.h8,
                      Text(
                        l10n.consentPrivacyBody,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(height: 1.5),
                      ),
                      Gap.h24,

                      CheckboxListTile(
                        value: _understood,
                        onChanged:
                            (v) => setState(() => _understood = v ?? false),
                        title: Text(l10n.consentUnderstand),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      CheckboxListTile(
                        value: _privacyAccepted,
                        onChanged:
                            (v) =>
                                setState(() => _privacyAccepted = v ?? false),
                        title: Text(l10n.consentPrivacyAccept),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (!_canContinue) ...[
                        Gap.h8,
                        Text(
                          l10n.consentMustAccept,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: scheme.error),
                        ),
                      ],
                      Gap.h16,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Gap.m),
              child: FilledButton(
                onPressed:
                    _canContinue
                        ? () =>
                            ref.read(settingsProvider.notifier).acceptConsent()
                        : null,
                child: Text(l10n.actionContinue),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
