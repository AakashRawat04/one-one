import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import '../../../app/app_config.dart';
import '../models/subscription_state.dart';
import 'developer_access_service.dart';
import 'remote_config_service.dart';
import 'subscription_grace_period_store.dart';

/// Central service for RevenueCat subscription management.
///
/// Responsibilities:
/// - Initialise the RevenueCat SDK with the provided API key.
/// - Fetch customer info and map it to a [SubscriptionState].
/// - Present the RevenueCat paywall UI (via Purchases UI Flutter).
/// - Present the Customer Center for subscription management.
/// - Listen for customer-info updates so the app can react immediately.
class RevenueCatService {
  RevenueCatService({
    required this.remoteConfigService,
    required this.appUserId,
    required this.developerAccessService,
    required this.gracePeriodStore,
    required bool hasDeveloperBypass,
    String? apiKey,
  }) : _apiKey = apiKey ?? _platformApiKey(),
       _hasDeveloperBypass = hasDeveloperBypass;

  final RemoteConfigService remoteConfigService;
  final String appUserId;
  final DeveloperAccessService developerAccessService;
  final SubscriptionGracePeriodStore gracePeriodStore;
  final String _apiKey;
  bool _hasDeveloperBypass;
  StreamSubscription<void>? _remoteConfigSubscription;

  // ── RevenueCat API key ─────────────────────────────────────────────

  static String _platformApiKey() {
    if (Platform.isAndroid) return AppConfig.revenueCatAndroidApiKey;
    if (Platform.isIOS) return AppConfig.revenueCatAppleApiKey;
    return '';
  }

  // ── Entitlement identifier ──────────────────────────────────────────

  static const String entitlementId = 'OneOne_Pro';

  // ── State stream ───────────────────────────────────────────────────

  final StreamController<SubscriptionState> _stateController =
      StreamController<SubscriptionState>.broadcast();

  Stream<SubscriptionState> get subscriptionStateStream =>
      _stateController.stream;

  SubscriptionState? _latestState;

  SubscriptionState? get latestState => _latestState;

  // ── Initialization ─────────────────────────────────────────────────

  /// Must be called once at app startup, before any other RevenueCat calls.
  Future<void> initialize() async {
    if (_apiKey.trim().isEmpty) {
      throw StateError(
        'RevenueCat SDK key is missing. Supply the platform-specific '
        'ONE_ONE_REVENUECAT_*_API_KEY dart define.',
      );
    }

    // Configure the SDK with the correct API key.
    // On Android this activates the Google Play Billing library;
    // on iOS it sets up StoreKit.
    if (await Purchases.isConfigured) {
      // Firebase logout/login can change the app user without restarting the
      // process. RevenueCat must follow that authenticated identity instead
      // of retaining the previous account's entitlements.
      await Purchases.logIn(appUserId);
    } else {
      await Purchases.configure(
        PurchasesConfiguration(_apiKey)..appUserID = appUserId,
      );
    }

    // Listen for customer-info changes so the app stays in sync
    // (e.g. after a purchase or cancellation on another device).
    Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);
    _remoteConfigSubscription = remoteConfigService.updates.listen((_) {
      unawaited(_refreshState());
    });

    // Fetch the initial customer info immediately.
    await _refreshState();
  }

  /// Gracefully tear down listeners. Call when the app is shutting down.
  void dispose() {
    Purchases.removeCustomerInfoUpdateListener(_onCustomerInfoUpdated);
    unawaited(_remoteConfigSubscription?.cancel());
    _stateController.close();
  }

  // ── Public API ─────────────────────────────────────────────────────

  /// Fetch the latest customer info from RevenueCat and emit an updated
  /// [SubscriptionState].
  Future<SubscriptionState> refreshSubscriptionState() async {
    return _refreshState();
  }

  /// Present the RevenueCat paywall UI.
  ///
  /// This uses the Paywalls v2 UI from `purchases_ui_flutter`, which
  /// RevenueCat hosts and A/B-tests on their servers.  You just bring
  /// the offering identifier.
  ///
  /// Returns `true` when the user completed a purchase (entitlement
  /// is now active); `false` when they dismissed without buying.
  Future<bool> presentPaywall() async {
    try {
      final offering = await _activeOffering();
      if (offering == null) {
        debugPrint('RevenueCat active offering is unavailable.');
        return false;
      }

      final result = await RevenueCatUI.presentPaywall(
        offering: offering,
        displayCloseButton: true,
      );

      switch (result) {
        case PaywallResult.purchased:
        case PaywallResult.restored:
          await _refreshState();
          return true;
        case PaywallResult.cancelled:
        case PaywallResult.error:
        case PaywallResult.notPresented:
          return false;
      }
    } catch (e) {
      debugPrint('RevenueCat paywall error: $e');
      return false;
    }
  }

  /// Open the Customer Center so the user can manage their subscription
  /// (cancel, resubscribe, request refund, etc.).
  Future<void> presentCustomerCenter() async {
    try {
      await RevenueCatUI.presentCustomerCenter();
    } catch (e) {
      debugPrint('RevenueCat Customer Center error: $e');
    }
  }

  /// Perform a manual restore of purchases (e.g. when the user taps a
  /// "Restore Purchases" button).
  Future<bool> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      final state = await _mapCustomerInfo(customerInfo);
      _emitState(state);
      return state.isSubscribed;
    } catch (e) {
      debugPrint('Restore purchases error: $e');
      return _latestState?.isSubscribed ?? false;
    }
  }

  /// Return the list of products available in the default offering.
  /// This can be used to display custom pricing before opening the paywall.
  Future<List<Package>> getOfferings() async {
    try {
      final offering = await _activeOffering();
      return offering?.availablePackages ?? [];
    } catch (e) {
      debugPrint('Error fetching offerings: $e');
      return [];
    }
  }

  Future<bool> redeemDeveloperCode(String code) async {
    try {
      final redeemed = await developerAccessService.redeem(code);
      if (!redeemed) return false;
      _hasDeveloperBypass = true;
      await _refreshState();
      return true;
    } catch (error) {
      debugPrint('Developer code redemption failed: $error');
      return false;
    }
  }

  // ── Internal helpers ───────────────────────────────────────────────

  Future<SubscriptionState> _refreshState() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final state = await _mapCustomerInfo(customerInfo);
      _emitState(state);
      return state;
    } catch (e) {
      debugPrint('Error refreshing subscription state: $e');
      // Return a safe fallback — assume not subscribed so we don't
      // accidentally grant access.
      final fallback = await _stateFor(isSubscribed: false);
      _emitState(fallback);
      return fallback;
    }
  }

  void _onCustomerInfoUpdated(CustomerInfo customerInfo) {
    unawaited(_mapAndEmitCustomerInfo(customerInfo));
  }

  Future<void> _mapAndEmitCustomerInfo(CustomerInfo customerInfo) async {
    final state = await _mapCustomerInfo(customerInfo);
    _emitState(state);
  }

  Future<SubscriptionState> _mapCustomerInfo(CustomerInfo info) async {
    final entitlement = info.entitlements.active[entitlementId];
    final isSubscribed = entitlement != null && !entitlement.isSandbox
        ? entitlement.isActive
        : (entitlement?.isActive ?? false);

    // expirationDate is an ISO-8601 string (e.g. "2026-08-16T00:00:00Z").
    int? expirationDateMs;
    final rawExpiration = entitlement?.expirationDate;
    if (rawExpiration != null && rawExpiration.isNotEmpty) {
      expirationDateMs = DateTime.tryParse(
        rawExpiration,
      )?.millisecondsSinceEpoch;
    }

    return _stateFor(
      isSubscribed: isSubscribed,
      expirationDate: expirationDateMs,
    );
  }

  Future<SubscriptionState> _stateFor({
    required bool isSubscribed,
    int? expirationDate,
  }) async {
    final tier = remoteConfigService.activeTier;
    final graceDays = remoteConfigService.gracePeriodDays;
    final graceEndsAt = await gracePeriodStore.resolveGraceEndsAt(
      tier: tier,
      gracePeriodDays: graceDays,
      remoteExtremeActivatedAtMs: remoteConfigService.extremeActivatedAtMs,
    );
    return SubscriptionState(
      isSubscribed: isSubscribed,
      hasDeveloperBypass: _hasDeveloperBypass,
      activeTier: tier,
      gracePeriodDays: graceDays,
      developerRedeemEnabled: remoteConfigService.developerRedeemEnabled,
      graceEndsAt: graceEndsAt,
      expirationDate: expirationDate,
    );
  }

  Future<Offering?> _activeOffering() async {
    final storefront = await Purchases.storefront;
    final countryCode = storefront?.countryCode.trim().toUpperCase();
    final isIndia = countryCode == 'IN' || countryCode == 'IND';
    final offeringId = remoteConfigService.offeringId(
      tier: remoteConfigService.activeTier,
      isIndia: isIndia,
    );
    final offerings = await Purchases.getOfferings();
    return offerings.getOffering(offeringId);
  }

  void _emitState(SubscriptionState state) {
    _latestState = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }
}
