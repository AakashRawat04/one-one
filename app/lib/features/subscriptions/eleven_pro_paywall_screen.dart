import 'package:one_one_app/one_one.dart';

/// Brand yellow used on auth/onboarding — not the user accent color.
const Color _kBrandYellow = Color(0xffF8BE03);

// ─────────────────────────────────────────────────────────────────────────────
// User-state enum: what state the current user is in
// ─────────────────────────────────────────────────────────────────────────────
enum _UserPlanState {
  /// RC entitlement active → full Pro
  activePro,

  /// Trial clock still ticking → Pro access, not yet paid
  onTrial,

  /// Trial over, not subscribed → free tier
  freeAfterTrial,
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen widget
// ─────────────────────────────────────────────────────────────────────────────

/// In-app Duo Pro paywall — dynamically shows trial / free / pro state.
///
/// Returns `true` from [open] when the user purchases or restores Pro access.
class ElevenProPaywallScreen extends StatefulWidget {
  const ElevenProPaywallScreen({super.key});

  static Future<bool> open(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        opaque: true,
        barrierColor: const Color(0xff101010),
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (context, animation, secondaryAnimation) {
          return const AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: ColoredBox(
              color: Color(0xff101010),
              child: ElevenProPaywallScreen(),
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              // Exit left with the back arrow — not a downward dip.
              position: Tween<Offset>(
                begin: const Offset(-0.22, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
    return result ?? false;
  }

  @override
  State<ElevenProPaywallScreen> createState() => _ElevenProPaywallScreenState();
}

class _ElevenProPaywallScreenState extends State<ElevenProPaywallScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<Package> _packages = const [];
  Package? _selected;

  // Dynamic user-state
  _UserPlanState _planState = _UserPlanState.onTrial;
  int _trialDaysLeft = 0;

  @override
  void initState() {
    super.initState();
    unawaited(AnalyticsService.logScreenView(screenName: 'paywall'));
    unawaited(AnalyticsService.logPaywallViewed(source: 'settings'));
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rc = await RevenueCatService.initialize();
      final entitled = await rc.isEntitledToPro();

      // Resolve user plan state
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (entitled) {
        if (!mounted) return;
        setState(() {
          _planState = _UserPlanState.activePro;
          _loading = false;
        });
        return;
      }

      // Not entitled — check trial
      final snapshot = await FreeTrialAccess.snapshot(userId: userId);
      final planState = snapshot.trialActive
          ? _UserPlanState.onTrial
          : _UserPlanState.freeAfterTrial;
      final daysLeft = FreeTrialAccess.remainingWholeDays(snapshot.remaining);

      final offerings = await rc.getOfferings();
      final current = offerings.current;
      final packages = current?.availablePackages ?? const <Package>[];
      if (packages.isEmpty) {
        throw const RevenueCatException(
          'Subscription options are not available yet. Try again later.',
        );
      }

      Package preferred = packages.first;
      for (final package in packages) {
        if (package.packageType == PackageType.monthly) {
          preferred = package;
          break;
        }
      }

      if (!mounted) return;
      setState(() {
        _planState = planState;
        _trialDaysLeft = daysLeft;
        _packages = packages;
        _selected = preferred;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is RevenueCatException
            ? error.message
            : 'Could not load subscription options.';
      });
    }
  }

  Future<void> _purchase() async {
    final package = _selected;
    if (package == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    unawaited(
      AnalyticsService.logButtonClick(
        buttonName: 'purchase',
        screenName: 'paywall',
      ),
    );
    unawaited(
      AnalyticsService.logPurchaseStarted(
        packageId: package.storeProduct.identifier,
      ),
    );
    try {
      final rc = await RevenueCatService.initialize();
      final info = await rc.purchasePackage(package);
      final entitled =
          info.entitlements.active.containsKey(AppConfig.proEntitlementId);
      if (!mounted) return;
      if (entitled) {
        final entitlement =
            info.entitlements.active[AppConfig.proEntitlementId];
        final isTrial = entitlement?.periodType == PeriodType.trial ||
            entitlement?.periodType == PeriodType.intro;
        if (isTrial) {
          unawaited(
            AnalyticsService.logTrialStarted(
              packageId: package.storeProduct.identifier,
            ),
          );
        }
        unawaited(
          AnalyticsService.logPurchaseCompleted(
            packageId: package.storeProduct.identifier,
          ),
        );
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _busy = false;
        _error = 'Purchase completed, but Pro access is not active yet.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (error is RevenueCatException &&
            error.message == 'Purchase was cancelled.') {
          _error = null;
        } else {
          _error = error is RevenueCatException
              ? error.message
              : 'Purchase failed. Please try again.';
        }
      });
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final rc = await RevenueCatService.initialize();
      final info = await rc.restorePurchases();
      final entitled =
          info.entitlements.active.containsKey(AppConfig.proEntitlementId);
      if (!mounted) return;
      if (entitled) {
        unawaited(
          AnalyticsService.logPurchaseCompleted(
            packageId: _selected?.storeProduct.identifier,
          ),
        );
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _busy = false;
        _error = 'No active Duo Pro subscription found to restore.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error is RevenueCatException
            ? error.message
            : 'Restore failed. Please try again.';
      });
    }
  }

  String _titleFor(Package package) {
    switch (package.packageType) {
      case PackageType.weekly:
        return 'Weekly';
      case PackageType.monthly:
        return 'Monthly';
      case PackageType.twoMonth:
        return '2 months';
      case PackageType.threeMonth:
        return '3 months';
      case PackageType.sixMonth:
        return '6 months';
      case PackageType.annual:
        return 'Yearly';
      case PackageType.lifetime:
        return 'Lifetime';
      case PackageType.custom:
      case PackageType.unknown:
        return package.storeProduct.title.isNotEmpty
            ? package.storeProduct.title
            : 'Plan';
    }
  }

  String? get _trialAppBarLabel {
    switch (_planState) {
      case _UserPlanState.activePro:
        return null;
      case _UserPlanState.onTrial:
        if (_trialDaysLeft <= 0) return '⌛ <1 day left';
        if (_trialDaysLeft == 1) return '⌛ 1 day left';
        return '⌛ $_trialDaysLeft days left';
      case _UserPlanState.freeAfterTrial:
        return '⌛ Trial ended';
    }
  }

  String _subtitleFor(Package package) {
    switch (package.packageType) {
      case PackageType.weekly:
        return 'Billed every week';
      case PackageType.monthly:
        return 'Billed every month';
      case PackageType.twoMonth:
        return 'Billed every 2 months';
      case PackageType.threeMonth:
        return 'Billed every 3 months';
      case PackageType.sixMonth:
        return 'Billed every 6 months';
      case PackageType.annual:
        return 'Billed once a year';
      case PackageType.lifetime:
        return 'One-time purchase';
      case PackageType.custom:
      case PackageType.unknown:
        return package.storeProduct.description;
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = _kBrandYellow;

    return Scaffold(
      backgroundColor: const Color(0xff101010),
      appBar: AppBar(
        backgroundColor: const Color(0xff101010),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Semantics(
          label: 'Duo',
          child: Image.asset(
            'assets/logo.png',
            height: 34,
            fit: BoxFit.contain,
          ),
        ),
        actions: [
          if (!_loading && _trialAppBarLabel != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  _trialAppBarLabel!,
                  style: TextStyle(
                    color: _planState == _UserPlanState.onTrial
                        ? accent
                        : Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white70),
              )
            : _planState == _UserPlanState.activePro
                ? _AlreadyProBody(
                    accent: accent,
                    onDone: () => Navigator.of(context).pop(false),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: const Padding(
                          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: _PlanComparison(),
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                          child: Column(
                            children: [
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xffff8a80),
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                              if (_packages.isEmpty)
                                TextButton(
                                  onPressed: _busy ? null : _load,
                                  child: const Text('Try again'),
                                ),
                            ],
                          ),
                        ),
                      if (_packages.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Column(
                            children: [
                              for (final package in _packages) ...[
                                _PlanTile(
                                  package: package,
                                  title: _titleFor(package),
                                  subtitle: _subtitleFor(package),
                                  selected: identical(package, _selected) ||
                                      package.identifier ==
                                          _selected?.identifier,
                                  accent: accent,
                                  enabled: !_busy,
                                  onTap: () =>
                                      setState(() => _selected = package),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ],
                          ),
                        ),
                      if (_packages.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          child: Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _busy || _selected == null
                                      ? null
                                      : _purchase,
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(50),
                                    backgroundColor: accent,
                                    foregroundColor: Colors.black,
                                    disabledBackgroundColor:
                                        accent.withValues(alpha: 0.35),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                  ),
                                  child: _busy
                                      ? const SizedBox.square(
                                          dimension: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: Colors.black,
                                          ),
                                        )
                                      : Text(
                                          _selected == null
                                              ? 'Get Duo Pro'
                                              : 'Get Duo Pro · ${_selected!.storeProduct.priceString}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                        ),
                                ),
                              ),
                              TextButton(
                                onPressed: _busy ? null : _restore,
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: const Text('Restore purchases'),
                              ),
                              const Text(
                                'Prices are set by the App Store or Google Play.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                  height: 1.35,
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

// ─────────────────────────────────────────────────────────────────────────────
// Plan comparison — vertical Free vs Duo Pro lists
// ─────────────────────────────────────────────────────────────────────────────

class _FeatureItem {
  const _FeatureItem({
    required this.stickerAsset,
    required this.label,
  });
  final String stickerAsset;
  final String label;
}

const _freeFeatures = <_FeatureItem>[
  _FeatureItem(
    stickerAsset: 'assets/duo_stickers/bell.png',
    label: 'Nudges',
  ),
  _FeatureItem(
    stickerAsset: 'assets/duo_stickers/message.png',
    label: 'Chat',
  ),
  _FeatureItem(
    stickerAsset: 'assets/duo_stickers/boysNgirls.png',
    label: 'Groups',
  ),
  _FeatureItem(
    stickerAsset: 'assets/duo_stickers/gift.png',
    label: 'Always free',
  ),
];

const _proFeatures = <_FeatureItem>[
  _FeatureItem(
    stickerAsset: 'assets/duo_stickers/mic.png',
    label: 'Live voice',
  ),
  _FeatureItem(
    stickerAsset: 'assets/duo_stickers/online_orb.png',
    label: 'Presence',
  ),
  _FeatureItem(
    stickerAsset: 'assets/duo_stickers/handshake.png',
    label: 'Support',
  ),
  _FeatureItem(
    stickerAsset: 'assets/duo_stickers/update_sub.png',
    label: 'Change anytime',
  ),
];

class _PlanComparison extends StatelessWidget {
  const _PlanComparison();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Expanded(
          child: _PlanCard(
            label: 'Free',
            labelColor: Colors.white60,
            accentColor: Colors.white70,
            features: _freeFeatures,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PlanCard(
            label: 'Duo Pro',
            labelColor: _kBrandYellow,
            accentColor: _kBrandYellow,
            features: _proFeatures,
            crownAsset: 'assets/duo_stickers/minimalCrown.png',
            highlighted: true,
            includesEverythingInFree: true,
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.label,
    required this.labelColor,
    required this.accentColor,
    required this.features,
    this.crownAsset,
    this.highlighted = false,
    this.includesEverythingInFree = false,
  });

  final String label;
  final Color labelColor;
  final Color accentColor;
  final List<_FeatureItem> features;
  final String? crownAsset;
  final bool highlighted;
  final bool includesEverythingInFree;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xff1a1a1a),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlighted
              ? _kBrandYellow.withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.08),
          width: highlighted ? 1.6 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (crownAsset != null) ...[
                  Image.asset(crownAsset!, width: 16, height: 16),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: labelColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
            if (includesEverythingInFree) ...[
              const SizedBox(height: 10),
              const _EverythingInFreeNote(),
              const SizedBox(height: 6),
            ] else
              const SizedBox(height: 10),
            Expanded(
              child: Column(
                children: [
                  for (var i = 0; i < features.length; i++) ...[
                    if (i > 0) const SizedBox(height: 4),
                    Expanded(
                      child: _FeatureRow(
                        item: features[i],
                        accentColor: accentColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EverythingInFreeNote extends StatelessWidget {
  const _EverythingInFreeNote();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final item in _freeFeatures)
              Padding(
                padding: const EdgeInsets.only(right: 5),
                child: Image.asset(
                  item.stickerAsset,
                  width: 24,
                  height: 24,
                  fit: BoxFit.contain,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Everything in Free, plus',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontWeight: FontWeight.w600,
            fontSize: 11.5,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.item,
    required this.accentColor,
  });

  final _FeatureItem item;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stickerSize = constraints.maxHeight.clamp(40.0, 68.0);
        return Row(
          children: [
            SizedBox(
              width: stickerSize,
              height: stickerSize,
              child: Image.asset(
                item.stickerAsset,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  height: 1.15,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan tile (pricing rows) — unchanged from before
// ─────────────────────────────────────────────────────────────────────────────
class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.package,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.accent,
    required this.enabled,
    required this.onTap,
  });

  final Package package;
  final String title;
  final String subtitle;
  final bool selected;
  final Color accent;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xff1b1b1b),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.09),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? accent : Colors.white38,
                    width: 2,
                  ),
                  color: selected ? accent : Colors.transparent,
                ),
                child: selected
                    ? const Icon(Icons.check_rounded, size: 14, color: Colors.black)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                package.storeProduct.priceString,
                style: TextStyle(
                  color: selected ? accent : Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Already-Pro body — shown when RC entitlement is already active
// ─────────────────────────────────────────────────────────────────────────────
class _AlreadyProBody extends StatelessWidget {
  const _AlreadyProBody({
    required this.accent,
    required this.onDone,
  });

  final Color accent;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        children: [
          const Spacer(),
          Image.asset(
            'assets/duo_stickers/minimalCrown.png',
            width: 80,
            height: 80,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 20),
          const Text(
            'You\'re on Duo Pro',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Thanks for supporting Duo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, height: 1.45),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onDone,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                backgroundColor: accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
