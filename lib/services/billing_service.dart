import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../constants.dart';
import '../models/entitlement.dart';
import '../models/enums.dart';
import 'entitlement_service.dart';

/// What the paywall needs to render.
class BillingState {
  const BillingState({
    required this.storeAvailable,
    required this.offers,
    required this.uiState,
    required this.entitlement,
    this.errorMessage,
    this.lastProductId,
  });

  const BillingState.initial()
    : storeAvailable = false,
      offers = const [],
      uiState = PurchaseUiState.loadingProducts,
      entitlement = const Entitlement.free(),
      errorMessage = null,
      lastProductId = null;

  final bool storeAvailable;

  /// Offers exactly as the store described them. Prices and titles are never
  /// hardcoded in this app; if this list is empty there is nothing to show.
  final List<SubscriptionOffer> offers;
  final PurchaseUiState uiState;
  final Entitlement entitlement;
  final String? errorMessage;
  final String? lastProductId;

  bool get isPremium => entitlement.isActive;

  bool get isBusy =>
      uiState == PurchaseUiState.loadingProducts ||
      uiState == PurchaseUiState.pending;

  SubscriptionOffer? offerFor(String productId) {
    for (final o in offers) {
      if (o.productId == productId) return o;
    }
    return null;
  }

  BillingState copyWith({
    bool? storeAvailable,
    List<SubscriptionOffer>? offers,
    PurchaseUiState? uiState,
    Entitlement? entitlement,
    String? errorMessage,
    String? lastProductId,
    bool clearError = false,
  }) => BillingState(
    storeAvailable: storeAvailable ?? this.storeAvailable,
    offers: offers ?? this.offers,
    uiState: uiState ?? this.uiState,
    entitlement: entitlement ?? this.entitlement,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    lastProductId: lastProductId ?? this.lastProductId,
  );
}

/// Google Play Billing, wrapped so the rest of the app never touches the plugin.
///
/// Every purchase state the store can report is handled: purchased, pending,
/// error, canceled and restored.
class BillingService {
  BillingService(this._entitlements, {InAppPurchase? iap})
    : _iap = iap ?? InAppPurchase.instance;

  final InAppPurchase _iap;
  final EntitlementService _entitlements;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final _states = StreamController<BillingState>.broadcast();

  BillingState _state = const BillingState.initial();

  BillingState get state => _state;

  Stream<BillingState> get states => _states.stream;

  /// How long to wait for the store to replay owned purchases on launch before
  /// concluding that there is no active subscription.
  static const Duration _restoreGrace = Duration(seconds: 6);

  bool _sawPurchaseSinceRestore = false;
  Completer<void>? _restoreCompleter;

  void _emit(BillingState next) {
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }

  /// Start listening, load the products, and re-check the entitlement.
  ///
  /// Called on every app launch.
  Future<void> initialize() async {
    _emit(
      _state.copyWith(
        entitlement: await _entitlements.dropIfExpired(),
        uiState: PurchaseUiState.loadingProducts,
        clearError: true,
      ),
    );

    _subscription ??= _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError:
          (Object e) => _emit(
            _state.copyWith(
              uiState: PurchaseUiState.error,
              errorMessage: e.toString(),
            ),
          ),
    );

    bool available;
    try {
      available = await _iap.isAvailable();
    } on Object {
      available = false;
    }

    if (!available) {
      // Offline or Play Services missing. Keep whatever entitlement is cached:
      // being unable to reach the store must never lock a paying user out.
      _emit(
        _state.copyWith(
          storeAvailable: false,
          uiState: PurchaseUiState.productsUnavailable,
          entitlement: _entitlements.current,
        ),
      );
      return;
    }

    await loadProducts();
    await _recheckEntitlement();
  }

  /// Ask the store for the real titles and prices.
  Future<void> loadProducts() async {
    _emit(
      _state.copyWith(
        uiState: PurchaseUiState.loadingProducts,
        clearError: true,
      ),
    );
    try {
      final response = await _iap.queryProductDetails(BillingProducts.all);

      if (response.error != null) {
        _emit(
          _state.copyWith(
            storeAvailable: true,
            uiState: PurchaseUiState.error,
            errorMessage: response.error!.message,
          ),
        );
        return;
      }

      final offers =
          response.productDetails
              .map(
                (p) => SubscriptionOffer(
                  productId: p.id,
                  title: p.title,
                  description: p.description,
                  price: p.price,
                  currencyCode: p.currencyCode,
                  rawPriceMicros: (p.rawPrice * 1000000).round(),
                ),
              )
              .toList()
            ..sort((a, b) => a.rawPriceMicros.compareTo(b.rawPriceMicros));

      _emit(
        _state.copyWith(
          storeAvailable: true,
          offers: offers,
          uiState:
              offers.isEmpty
                  ? PurchaseUiState.productsUnavailable
                  : PurchaseUiState.idle,
          clearError: true,
        ),
      );
    } on Object catch (e) {
      _emit(
        _state.copyWith(
          uiState: PurchaseUiState.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Re-derive the entitlement from the store's record of owned purchases.
  ///
  /// If the store answers and reports nothing, Premium is revoked. If it never
  /// answers, the cached entitlement is kept.
  Future<void> _recheckEntitlement() async {
    _sawPurchaseSinceRestore = false;
    final completer = _restoreCompleter = Completer<void>();

    try {
      await _iap.restorePurchases();
    } on Object {
      // Nothing to restore, or the call is unsupported. Keep the cache.
      _restoreCompleter = null;
      return;
    }

    // Wait briefly for the stream to replay anything the user owns.
    await Future.any([completer.future, Future<void>.delayed(_restoreGrace)]);
    _restoreCompleter = null;

    if (!_sawPurchaseSinceRestore) {
      _emit(_state.copyWith(entitlement: await _entitlements.revoke()));
    }
  }

  /// Buy one of the two subscriptions.
  Future<void> buy(String productId) async {
    final offer = _state.offerFor(productId);
    if (offer == null) {
      _emit(
        _state.copyWith(
          uiState: PurchaseUiState.productsUnavailable,
          lastProductId: productId,
        ),
      );
      return;
    }

    ProductDetails? details;
    try {
      final response = await _iap.queryProductDetails({productId});
      details = response.productDetails
          .where((p) => p.id == productId)
          .cast<ProductDetails?>()
          .firstWhere((p) => p != null, orElse: () => null);
    } on Object catch (e) {
      _emit(
        _state.copyWith(
          uiState: PurchaseUiState.error,
          errorMessage: e.toString(),
        ),
      );
      return;
    }

    if (details == null) {
      _emit(
        _state.copyWith(
          uiState: PurchaseUiState.productsUnavailable,
          lastProductId: productId,
        ),
      );
      return;
    }

    _emit(
      _state.copyWith(
        uiState: PurchaseUiState.pending,
        lastProductId: productId,
        clearError: true,
      ),
    );

    try {
      // Subscriptions are non-consumable: the entitlement persists.
      await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: details),
      );
    } on Object catch (e) {
      _emit(
        _state.copyWith(
          uiState: PurchaseUiState.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// "Restore purchases" button.
  Future<void> restore() async {
    _emit(_state.copyWith(uiState: PurchaseUiState.pending, clearError: true));
    try {
      await _iap.restorePurchases();
      // The stream delivers the result; if nothing arrives, say so rather than
      // leaving a spinner running forever.
      await Future<void>.delayed(_restoreGrace);
      if (_state.uiState == PurchaseUiState.pending) {
        _emit(
          _state.copyWith(
            uiState:
                _entitlements.isPremium
                    ? PurchaseUiState.restored
                    : PurchaseUiState.idle,
            entitlement: _entitlements.current,
          ),
        );
      }
    } on Object catch (e) {
      _emit(
        _state.copyWith(
          uiState: PurchaseUiState.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (!BillingProducts.all.contains(purchase.productID)) continue;

      switch (purchase.status) {
        case PurchaseStatus.pending:
          _emit(
            _state.copyWith(
              uiState: PurchaseUiState.pending,
              lastProductId: purchase.productID,
              clearError: true,
            ),
          );

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _sawPurchaseSinceRestore = true;
          if (!(_restoreCompleter?.isCompleted ?? true)) {
            _restoreCompleter!.complete();
          }
          final entitlement = await _entitlements.applyPurchases([purchase]);
          _emit(
            _state.copyWith(
              entitlement: entitlement,
              uiState:
                  purchase.status == PurchaseStatus.restored
                      ? PurchaseUiState.restored
                      : PurchaseUiState.purchased,
              lastProductId: purchase.productID,
              clearError: true,
            ),
          );

        case PurchaseStatus.canceled:
          _emit(
            _state.copyWith(
              uiState: PurchaseUiState.canceled,
              lastProductId: purchase.productID,
            ),
          );

        case PurchaseStatus.error:
          _emit(
            _state.copyWith(
              uiState: PurchaseUiState.error,
              errorMessage: purchase.error?.message,
              lastProductId: purchase.productID,
            ),
          );
      }

      // Every delivered purchase must be completed, or Play will refund it.
      if (purchase.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(purchase);
        } on Object {
          // Completion can be retried on the next launch; the purchase stream
          // replays anything still outstanding.
        }
      }
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _states.close();
  }
}
