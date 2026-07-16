import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import '../models/subscription_state.dart';
import 'remote_config_service.dart';

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
    String? apiKey,
  }) : _apiKey = apiKey ?? _defaultApiKey;

  final RemoteConfigService remoteConfigService;
  final String _apiKey;

  // ── RevenueCat API key ─────────────────────────────────────────────

  static const String _defaultApiKey = 'test_wjhuvlZxKrybFKbvrtrSoBGnBGg';

  // ── Offering identifiers ───────────────────────────────────────────

  /// The offering identifier used when presenting the paywall.
  /// RevenueCat offerings let you group products and experiments.
  static const String _defaultOfferingIdentifier = 'default';

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
    // Configure the SDK with the correct API key.
    // On Android this activates the Google Play Billing library;
    // on iOS it sets up StoreKit.
    await Purchases.configure(
      PurchasesConfiguration(_apiKey)
        ..appUserID = null, // Let RevenueCat generate an anonymous ID
    );

    // Listen for customer-info changes so the app stays in sync
    // (e.g. after a purchase or cancellation on another device).
    Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);

    // Fetch the initial customer info immediately.
    await _refreshState();
  }

  /// Gracefully tear down listeners. Call when the app is shutting down.
  void dispose() {
    Purchases.removeCustomerInfoUpdateListener(_onCustomerInfoUpdated);
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
      Offering? offering;
      try {
        final offerings = await Purchases.getOfferings();
        offering = offerings.getOffering(_defaultOfferingIdentifier);
      } catch (_) {
        // If we can't fetch offerings, present without a specific one.
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
      final state = _mapCustomerInfo(customerInfo);
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
      final offerings = await Purchases.getOfferings();
      final offering = offerings.getOffering(_defaultOfferingIdentifier);
      return offering?.availablePackages ?? [];
    } catch (e) {
      debugPrint('Error fetching offerings: $e');
      return [];
    }
  }

  // ── Internal helpers ───────────────────────────────────────────────

  Future<SubscriptionState> _refreshState() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final state = _mapCustomerInfo(customerInfo);
      _emitState(state);
      return state;
    } catch (e) {
      debugPrint('Error refreshing subscription state: $e');
      // Return a safe fallback — assume not subscribed so we don't
      // accidentally grant access.
      final fallback = SubscriptionState(
        isSubscribed: false,
        activeTier: remoteConfigService.activeTier,
        gracePeriodDays: remoteConfigService.gracePeriodDays,
      );
      _emitState(fallback);
      return fallback;
    }
  }

  void _onCustomerInfoUpdated(CustomerInfo customerInfo) {
    final state = _mapCustomerInfo(customerInfo);
    _emitState(state);
  }

  SubscriptionState _mapCustomerInfo(CustomerInfo info) {
    final entitlement = info.entitlements.active[entitlementId];
    final isSubscribed = entitlement != null && !entitlement.isSandbox
        ? entitlement.isActive
        : (entitlement?.isActive ?? false);

    // expirationDate is an ISO-8601 string (e.g. "2026-08-16T00:00:00Z").
    int? expirationDateMs;
    final rawExpiration = entitlement?.expirationDate;
    if (rawExpiration != null && rawExpiration.isNotEmpty) {
      expirationDateMs = DateTime.tryParse(rawExpiration)?.millisecondsSinceEpoch;
    }

    return SubscriptionState(
      isSubscribed: isSubscribed,
      activeTier: remoteConfigService.activeTier,
      gracePeriodDays: remoteConfigService.gracePeriodDays,
      expirationDate: expirationDateMs,
    );
  }

  void _emitState(SubscriptionState state) {
    _latestState = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }
}
