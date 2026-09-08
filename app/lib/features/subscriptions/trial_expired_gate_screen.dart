import 'package:one_one_app/one_one.dart';

/// Hard gate after the free trial ends.
///
/// Shows the illustrated [DuoGatePaywallScreen] (paywall.png + two CTAs).
/// **Get Pro** opens [ElevenProPaywallScreen]; **Log out** signs the user out.
class TrialExpiredGateScreen extends StatelessWidget {
  const TrialExpiredGateScreen({
    super.key,
    required this.identityRepository,
    required this.onUnlocked,
  });

  final IdentityRepository identityRepository;
  final Future<void> Function() onUnlocked;

  @override
  Widget build(BuildContext context) {
    return DuoGatePaywallScreen(
      mode: DuoGatePaywallMode.trialExpired,
      identityRepository: identityRepository,
      onUnlocked: onUnlocked,
    );
  }
}
