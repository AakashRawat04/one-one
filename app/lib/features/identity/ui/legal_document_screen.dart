import 'package:flutter/material.dart';

enum LegalDocument { terms, privacy }

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final content = document == LegalDocument.terms
        ? _termsSections
        : _privacySections;
    final title = document == LegalDocument.terms
        ? 'Terms & Conditions'
        : 'Privacy Policy';

    return Scaffold(
      backgroundColor: const Color(0xff101010),
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 36),
          children: [
            const Text(
              'Last updated: July 12, 2026',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 24),
            for (final section in content) ...[
              Text(
                section.heading,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                section.body,
                style: const TextStyle(
                  color: Colors.white70,
                  height: 1.55,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}

class _LegalSection {
  const _LegalSection(this.heading, this.body);

  final String heading;
  final String body;
}

const _termsSections = <_LegalSection>[
  _LegalSection(
    '1. Acceptance of terms',
    'By downloading, accessing, or using One One, you agree to these Terms & Conditions. If you do not agree, do not use the app.',
  ),
  _LegalSection(
    '2. The service',
    'One One lets people create or join private groups and exchange live voice audio. Availability, audio quality, and background delivery can depend on network access, device settings, permissions, and third-party services. The service is provided on an as-available basis.',
  ),
  _LegalSection(
    '3. Your responsibilities',
    'You are responsible for activity associated with your installation and for keeping invite codes private. You must have the right to share any name, profile picture, voice, or other content you provide. Do not use One One to harass others, violate their privacy, impersonate someone, break the law, or interfere with the service.',
  ),
  _LegalSection(
    '4. Voice and permissions',
    'One One requires microphone access to transmit live voice. You control when transmission starts through the in-app talk control. Notification and background permissions may be requested to support availability and audio features. You can change permissions in your device settings.',
  ),
  _LegalSection(
    '5. Third-party services',
    'One One relies on service providers for authentication, data storage, media delivery, profile-image hosting, and infrastructure. Their services may be governed by separate terms and may occasionally be unavailable.',
  ),
  _LegalSection(
    '6. Suspension and termination',
    'We may restrict or end access when reasonably necessary to protect users, comply with law, prevent abuse, or maintain the service. You may stop using One One at any time and remove the app from your device.',
  ),
  _LegalSection(
    '7. Disclaimers and liability',
    'To the extent permitted by law, One One is provided without warranties of uninterrupted, error-free, or secure operation. We are not liable for indirect, incidental, special, consequential, or punitive damages arising from use of the app. Nothing in these terms limits rights or liability that cannot legally be limited.',
  ),
  _LegalSection(
    '8. Changes',
    'We may update these terms as the service changes. The updated date will appear at the top of this page. Continued use after an update means you accept the revised terms.',
  ),
  _LegalSection(
    '9. Contact',
    'Questions about these terms can be sent through the support channel shown on the One One App Store listing.',
  ),
];

const _privacySections = <_LegalSection>[
  _LegalSection(
    '1. Overview',
    'This Privacy Policy explains what One One collects, why it is used, and the choices available to you when you use the app.',
  ),
  _LegalSection(
    '2. Information we collect',
    'We collect your Google-authenticated account identifier and email address, display name, optional profile picture, group membership and invite information, app settings, device and app-version identifiers, permission status, availability state, and basic service diagnostics. When you use live voice, microphone audio is transmitted to the other active members of your group.',
  ),
  _LegalSection(
    '3. How information is used',
    'Information is used to create your app identity, show your profile to group members, manage groups and invitations, connect live voice sessions, remember preferences, maintain availability, diagnose reliability, prevent misuse, and operate and improve One One.',
  ),
  _LegalSection(
    '4. Audio',
    'Live voice is transmitted so group members can hear you. One One is not designed to record or store the content of your live conversations. Service providers may process network and connection metadata needed to deliver the audio.',
  ),
  _LegalSection(
    '5. Service providers',
    'One One uses providers including Google Firebase for authentication and app data, Cloudinary for profile-picture hosting, LiveKit for real-time audio, and hosting providers for application services. These providers process information on our behalf under their own privacy and security practices.',
  ),
  _LegalSection(
    '6. Sharing',
    'Your display name, profile picture, availability, and live voice are shared with members of groups you join. We may also disclose information to service providers, to comply with law or valid legal process, to protect users and the service, or as part of a business transfer. We do not sell personal information.',
  ),
  _LegalSection(
    '7. Retention and security',
    'We retain information only for as long as reasonably needed to provide the service, meet legal obligations, resolve disputes, and protect the app. We use reasonable safeguards, but no networked service can guarantee absolute security.',
  ),
  _LegalSection(
    '8. Your choices',
    'You may change your display name, profile picture, app preferences, and device permissions. You may leave groups, log out, or delete your account from Settings. Requests to access information can be made through the support channel shown on the One One App Store listing. We may need information that identifies your app installation to complete a request.',
  ),
  _LegalSection(
    '9. Children',
    'One One is not directed to children under 13, or the minimum age required by local law. We do not knowingly collect personal information from children below that age.',
  ),
  _LegalSection(
    '10. International processing',
    'Information may be processed in countries other than your own. Where required, appropriate safeguards are used for international transfers.',
  ),
  _LegalSection(
    '11. Changes and contact',
    'We may update this policy as One One changes. The updated date will appear above. Privacy questions and requests can be sent through the support channel shown on the One One App Store listing.',
  ),
];
