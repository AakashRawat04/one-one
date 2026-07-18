import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../data/revenuecat_service.dart';
import '../models/subscription_state.dart';

/// Full-screen blocker shown when the extreme pricing tier is active
/// and the user does not have an active "OneOne Pro" subscription.
///
/// Explains that high demand means the app needs subscriptions to keep
/// running, and offers a single path forward: subscribe via the RevenueCat
/// paywall.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({
    super.key,
    required this.revenueCatService,
    required this.subscriptionState,
  });

  final RevenueCatService revenueCatService;
  final SubscriptionState subscriptionState;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _busy = false;
  bool _restoring = false;
  bool _redeeming = false;
  String? _message;

  Future<void> _subscribe() async {
    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      final purchased = await widget.revenueCatService.presentPaywall();
      if (!mounted) return;
      if (!purchased) {
        setState(() => _message = 'Subscribe to continue using One One.');
      }
      // If purchased, the subscription stream rebuilds the root gate.
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    setState(() {
      _restoring = true;
      _message = null;
    });

    try {
      final restored = await widget.revenueCatService.restorePurchases();
      if (!mounted) return;
      if (restored) {
        // The subscription stream rebuilds the root gate.
      } else {
        setState(() => _message = 'No active subscription found to restore.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _message = 'Could not restore purchases. Try again.');
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Future<void> _redeemDeveloperCode() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xff181818),
        title: const Text('Developer access'),
        content: TextField(
          controller: controller,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Redeem code',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Redeem'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || code == null || code.trim().isEmpty) return;

    setState(() {
      _redeeming = true;
      _message = null;
    });
    try {
      final redeemed = await widget.revenueCatService.redeemDeveloperCode(code);
      if (!mounted) return;
      if (!redeemed) {
        setState(() => _message = 'That developer code is not valid.');
      }
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0d0d0d),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 28.w),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // App icon / branding
              Image.asset('assets/logo.png', width: 120.w, fit: BoxFit.contain),
              SizedBox(height: 28.h),
              Text(
                'We\'re Experiencing\nHigh Demand! 🚀',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'To keep One One fast and reliable for everyone, '
                'we\'re asking new users to subscribe during this busy period. '
                'Your support helps us maintain the servers and deliver '
                'the best voice experience.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 40.h),
              // Subscribe button
              SizedBox(
                width: double.infinity,
                height: 56.h,
                child: FilledButton(
                  onPressed: _busy ? null : _subscribe,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xffff5a5f),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    textStyle: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: _busy
                      ? SizedBox(
                          width: 22.w,
                          height: 22.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Subscribe to One One Pro'),
                ),
              ),
              SizedBox(height: 14.h),
              // Restore purchases
              TextButton(
                onPressed: _restoring ? null : _restore,
                child: _restoring
                    ? SizedBox(
                        width: 18.w,
                        height: 18.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white54,
                        ),
                      )
                    : Text(
                        'Restore purchases',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                        ),
                      ),
              ),
              if (widget.subscriptionState.developerRedeemEnabled) ...[
                SizedBox(height: 4.h),
                TextButton.icon(
                  onPressed: _redeeming ? null : _redeemDeveloperCode,
                  icon: _redeeming
                      ? SizedBox(
                          width: 16.w,
                          height: 16.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white54,
                          ),
                        )
                      : const Icon(Icons.key_rounded, size: 18),
                  label: const Text('Redeem developer code'),
                  style: TextButton.styleFrom(foregroundColor: Colors.white54),
                ),
              ],
              if (_message != null) ...[
                SizedBox(height: 16.h),
                Text(
                  _message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 13.sp),
                ),
              ],
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
