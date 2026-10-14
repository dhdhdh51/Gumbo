import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';
import '../providers/app_providers.dart';
import '../theme.dart';

/// The privacy notice the user accepted at first launch, available any time.
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final acceptedAt = ref.watch(servicesProvider).prefs.consentAcceptedAt;
    final locale = Localizations.localeOf(context).toString();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacyTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Gap.m),
          children: [
            Text(
              l10n.consentPrivacyHeading,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            Gap.h16,
            Text(
              l10n.privacyBody,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
            if (acceptedAt != null) ...[
              Gap.h24,
              Text(
                l10n.consentAcceptedOn(
                  DateFormat.yMMMd(locale).add_Hm().format(acceptedAt),
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            Gap.h32,
          ],
        ),
      ),
    );
  }
}
