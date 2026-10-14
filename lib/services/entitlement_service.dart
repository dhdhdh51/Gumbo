import 'package:in_app_purchase/in_app_purchase.dart';

import '../constants.dart';
import '../models/entitlement.dart';
import 'prefs_service.dart';

/// The single place that decides whether the user has Premium.
///
/// Nothing else in the app inspects a [PurchaseDetails]. Screens and providers
/// only ever read [current], so the rule for "is this user premium" lives here
/// and nowhere else.
///
/// Adding server-side receipt verification later:
/// [evaluate] is the only function that turns purchases into an [Entitlement].
/// To verify against a backend, make [evaluate] async, POST
/// `purchase.verificationData.serverVerificationData` together with the product
/// id to your endpoint, and set `verified` from the response instead of from
/// [_isLocallyVerified]. Everything downstream already keys off `verified`, so
/// no screen, provider or cache shape needs to change. Until that exists the
/// app is explicit that verification is on-device only.
class EntitlementService {
  EntitlementService(this._prefs) : _current = _prefs.entitlement;

  final PrefsService _prefs;
  Entitlement _current;

  /// Cached entitlement, read on every launch before the store replies.
  Entitlement get current => _current;

  bool get isPremium => _current.isActive;

  /// Turn the purchases the store reported into an entitlement.
  ///
  /// Returns null when the purchases say nothing about Premium, so a caller can
  /// tell "no information" apart from "definitely not premium".
  Entitlement? evaluate(List<PurchaseDetails> purchases) {
    PurchaseDetails? active;
    PurchaseDetails? pending;

    for (final p in purchases) {
      if (!BillingProducts.all.contains(p.productID)) continue;
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          active = p;
        case PurchaseStatus.pending:
          pending ??= p;
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          break;
      }
    }

    if (active != null) {
      return Entitlement(
        isPremium: true,
        productId: active.productID,
        purchaseId: active.purchaseID,
        updatedAt: DateTime.now(),
        verified: _isLocallyVerified(active),
        // Google Play does not expose a subscription expiry to the device, so
        // none is recorded. If a backend starts returning one, store it here
        // and `Entitlement.isActive` will honour it with no other changes.
        expiresAt: null,
      );
    }

    if (pending != null) {
      return Entitlement(
        isPremium: false,
        productId: pending.productID,
        purchaseId: pending.purchaseID,
        updatedAt: DateTime.now(),
        verified: false,
        pending: true,
      );
    }

    return null;
  }

  /// On-device verification: Play reported the purchase in a final state and
  /// handed back verification data. This is not a substitute for checking the
  /// receipt against Google's servers.
  bool _isLocallyVerified(PurchaseDetails p) =>
      p.verificationData.serverVerificationData.isNotEmpty;

  /// Apply purchases and persist the result. Returns the entitlement in force.
  Future<Entitlement> applyPurchases(List<PurchaseDetails> purchases) async {
    final next = evaluate(purchases);
    if (next == null) return _current;
    return _write(next);
  }

  /// The store is reachable and reported no active subscription, so Premium is
  /// revoked. Called only when we actually heard back from the store; being
  /// offline must never downgrade a paying user.
  Future<Entitlement> revoke() async {
    if (!_current.isPremium && !_current.pending) return _current;
    return _write(const Entitlement.free());
  }

  /// Drop a cached entitlement whose known expiry has passed.
  Future<Entitlement> dropIfExpired() async {
    if (_current.isPremium && _current.isExpired) {
      return _write(const Entitlement.free());
    }
    return _current;
  }

  Future<Entitlement> _write(Entitlement e) async {
    _current = e;
    await _prefs.saveEntitlement(e);
    return e;
  }
}
