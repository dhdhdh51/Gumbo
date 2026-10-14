import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';
import '../l10n/gen/app_localizations.dart';
import '../models/entitlement.dart';
import '../models/enums.dart';
import '../providers/app_providers.dart';
import '../services/billing_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Subscription paywall.
///
/// Prices and titles always come from Google Play. Nothing about the price is
/// written into the app, so a price change in the Play Console needs no release.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh the offers whenever the paywall is opened, in case the user was
    // offline when the app started.
    final billing = ref.read(servicesProvider).billing;
    if (billing.state.offers.isEmpty) {
      billing.initialize();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final services = ref.watch(servicesProvider);
    final live = ref.watch(billingStateProvider);
    final state = live.value ?? services.billing.state;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.paywallTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Gap.m),
          children: [
            Text(
              l10n.paywallSubtitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Gap.h24,

            _statusBanner(context, l10n, state),

            _FeatureList(
              heading: l10n.paywallFreeHeading,
              icon: Icons.check,
              items: [
                l10n.paywallFree1,
                l10n.paywallFree2,
                l10n.paywallFree3,
                l10n.paywallFree4,
              ],
            ),
            Gap.h16,
            _FeatureList(
              heading: l10n.paywallPremiumHeading,
              icon: Icons.star_outline,
              highlight: true,
              items: [
                l10n.paywallPremium1,
                l10n.paywallPremium2,
                l10n.paywallPremium3,
                l10n.paywallPremium4,
                l10n.paywallPremium5,
              ],
            ),
            Gap.h24,

            if (state.isPremium)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Gap.m),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.verified_outlined),
                          Gap.w8,
                          Expanded(
                            child: Text(
                              l10n.paywallAlreadyPremium,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                        ],
                      ),
                      Gap.h16,
                      OutlinedButton.icon(
                        icon: const Icon(Icons.open_in_new),
                        onPressed: _openPlaySubscriptions,
                        label: Text(l10n.paywallManage),
                      ),
                    ],
                  ),
                ),
              )
            else if (state.uiState == PurchaseUiState.loadingProducts)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Gap.l),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      Gap.h16,
                      Text(
                        l10n.paywallLoadingPrices,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              )
            else if (state.offers.isEmpty)
              EmptyState(
                icon: Icons.storefront_outlined,
                message: l10n.paywallUnavailable,
                action: OutlinedButton(
                  onPressed: () => services.billing.initialize(),
                  child: Text(l10n.actionRetry),
                ),
              )
            else
              for (final offer in state.offers)
                Padding(
                  padding: const EdgeInsets.only(bottom: Gap.s),
                  child: _OfferCard(
                    offer: offer,
                    busy: state.isBusy,
                    onBuy: () => services.billing.buy(offer.productId),
                  ),
                ),

            Gap.h16,
            OutlinedButton.icon(
              icon: const Icon(Icons.restore),
              onPressed: state.isBusy ? null : () => services.billing.restore(),
              label: Text(l10n.paywallRestore),
            ),

            Gap.h24,
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Gap.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.paywallTermsHeading,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Gap.h8,
                    Text(
                      l10n.paywallTerms,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(height: 1.5),
                    ),
                    Gap.h16,
                    OutlinedButton.icon(
                      icon: const Icon(Icons.open_in_new),
                      onPressed: _openPlaySubscriptions,
                      label: Text(l10n.paywallManage),
                    ),
                  ],
                ),
              ),
            ),
            Gap.h32,
          ],
        ),
      ),
    );
  }

  /// Shows exactly what the store last reported, for every purchase state.
  Widget _statusBanner(
    BuildContext context,
    AppLocalizations l10n,
    BillingState state,
  ) {
    final (String? message, bool severe) = switch (state.uiState) {
      PurchaseUiState.pending => (l10n.paywallPending, false),
      PurchaseUiState.purchased => (l10n.paywallPurchased, false),
      PurchaseUiState.restored => (
        state.isPremium ? l10n.paywallRestored : l10n.paywallNothingToRestore,
        false,
      ),
      PurchaseUiState.canceled => (l10n.paywallCanceled, false),
      PurchaseUiState.error => (
        l10n.paywallError(state.errorMessage ?? l10n.errorGeneric),
        true,
      ),
      PurchaseUiState.productsUnavailable => (l10n.paywallUnavailable, false),
      _ => (null, false),
    };

    if (message == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.m),
      child: Card(
        color:
            severe
                ? Theme.of(context).colorScheme.errorContainer
                : Theme.of(context).colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(Gap.m),
          child: Row(
            children: [
              Icon(severe ? Icons.error_outline : Icons.info_outline, size: 20),
              Gap.w8,
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPlaySubscriptions() async {
    final l10n = AppLocalizations.of(context);
    final uri = Uri.parse(BillingProducts.playSubscriptionsUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.sourcesCouldNotOpen)));
    }
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.onBuy,
    required this.busy,
  });

  final SubscriptionOffer offer;
  final VoidCallback onBuy;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title and price are exactly what the store returned.
            Text(
              offer.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (offer.description.isNotEmpty) ...[
              Gap.h4,
              Text(
                offer.description,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            Gap.h8,
            Text(
              offer.price,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            Gap.h16,
            FilledButton(
              onPressed: busy ? null : onBuy,
              child: Text(AppLocalizations.of(context).actionContinue),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureList extends StatelessWidget {
  const _FeatureList({
    required this.heading,
    required this.items,
    required this.icon,
    this.highlight = false,
  });

  final String heading;
  final List<String> items;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: highlight ? scheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(Gap.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              heading,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            Gap.h8,
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 16),
                    Gap.w8,
                    Expanded(
                      child: Text(
                        item,
                        style: Theme.of(context).textTheme.bodyMedium,
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
}
