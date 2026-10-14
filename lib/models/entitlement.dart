/// Cached Premium entitlement.
///
/// This is the only thing in the app that decides whether Premium features are
/// unlocked. It is written by [EntitlementService] and nothing else.
///
/// Server-side verification note: today the entitlement is derived from the
/// purchase details Google Play hands back on the device. If receipt
/// verification against a backend is added later, the only change needed is to
/// have [EntitlementService.evaluate] call that backend and keep writing into
/// this same cached shape. No screen or provider reads purchase objects
/// directly, so nothing else has to change.
class Entitlement {
  const Entitlement({
    required this.isPremium,
    required this.productId,
    required this.purchaseId,
    required this.updatedAt,
    required this.verified,
    this.expiresAt,
    this.pending = false,
  });

  const Entitlement.free()
    : isPremium = false,
      productId = null,
      purchaseId = null,
      updatedAt = null,
      verified = false,
      expiresAt = null,
      pending = false;

  final bool isPremium;
  final String? productId;
  final String? purchaseId;
  final DateTime? updatedAt;

  /// True once the purchase has been acknowledged as valid. With on-device
  /// checks only this means Play reported the purchase as purchased and the
  /// signature verification the plugin performs passed.
  final bool verified;

  /// Null when the store does not expose an expiry. When present the cache is
  /// treated as stale after this instant.
  final DateTime? expiresAt;

  /// A purchase is awaiting completion, for example a pending UPI mandate.
  final bool pending;

  bool get isExpired {
    final e = expiresAt;
    if (e == null) return false;
    return DateTime.now().isAfter(e);
  }

  /// Premium is active only when the flag is set, the purchase was verified and
  /// any known expiry has not passed.
  bool get isActive => isPremium && verified && !isExpired;

  Entitlement copyWith({
    bool? isPremium,
    String? productId,
    String? purchaseId,
    DateTime? updatedAt,
    bool? verified,
    DateTime? expiresAt,
    bool? pending,
  }) => Entitlement(
    isPremium: isPremium ?? this.isPremium,
    productId: productId ?? this.productId,
    purchaseId: purchaseId ?? this.purchaseId,
    updatedAt: updatedAt ?? this.updatedAt,
    verified: verified ?? this.verified,
    expiresAt: expiresAt ?? this.expiresAt,
    pending: pending ?? this.pending,
  );

  Map<String, dynamic> toJson() => {
    'isPremium': isPremium,
    'productId': productId,
    'purchaseId': purchaseId,
    'updatedAt': updatedAt?.toIso8601String(),
    'verified': verified,
    'expiresAt': expiresAt?.toIso8601String(),
    'pending': pending,
  };

  static Entitlement fromJson(Map<String, dynamic> j) => Entitlement(
    isPremium: j['isPremium'] == true,
    productId: j['productId'] as String?,
    purchaseId: j['purchaseId'] as String?,
    updatedAt: DateTime.tryParse((j['updatedAt'] as String?) ?? ''),
    verified: j['verified'] == true,
    expiresAt: DateTime.tryParse((j['expiresAt'] as String?) ?? ''),
    pending: j['pending'] == true,
  );
}

/// A subscription offer as the store reported it.
///
/// Price and title always come from Google Play. The app never hardcodes a
/// price, a currency or a localised title.
class SubscriptionOffer {
  const SubscriptionOffer({
    required this.productId,
    required this.title,
    required this.description,
    required this.price,
    required this.currencyCode,
    required this.rawPriceMicros,
  });

  final String productId;
  final String title;
  final String description;

  /// Formatted, localised price string straight from the store.
  final String price;
  final String currencyCode;

  /// Raw price in micro-units, used only to sort offers.
  final int rawPriceMicros;
}
