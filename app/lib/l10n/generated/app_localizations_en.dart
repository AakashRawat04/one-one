// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get welcomeTitle => 'Welcome to Duo';

  @override
  String get welcomeSubtitle =>
      'Sign in or create your account before setting up your profile.';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get signingIn => 'Signing in…';

  @override
  String get termsFooter => 'By continuing, you agree to our terms & policies.';

  @override
  String get googleSignInCancelled =>
      'Google sign-in was cancelled. Please try again.';

  @override
  String get googleSignInFailed =>
      'Google sign-in couldn\'t be completed. Check your internet connection and try again.';

  @override
  String get languageMenuTooltip => 'Language';

  @override
  String get chooseAvatarTitle => 'choose an avatar';

  @override
  String get chooseAvatarSubtitle =>
      'You can add a custom photo later in Settings.';

  @override
  String get displayNameHint => 'your name';

  @override
  String get displayNameSubtitle => 'this is how your friends will see you';

  @override
  String get permissionMicTitle => 'mic';

  @override
  String get permissionMicSubtitle =>
      'so your friends can hear you\nwhen you talk...';

  @override
  String get permissionNotificationsTitle => 'notifications';

  @override
  String get permissionNotificationsSubtitle =>
      'know when your friends are\ntalking to you';

  @override
  String get permissionBackgroundTitle => 'background activity';

  @override
  String get permissionBackgroundSubtitle =>
      'receive nudges when duo\nisn\'t open';

  @override
  String get permissionFootnote => '*we need those for duo to work';

  @override
  String get permissionSetupFailed =>
      'Setup could not be completed. Please try again.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguageSection => 'Language';

  @override
  String get settingsLanguageTitle => 'App language';

  @override
  String get settingsLanguageSubtitle =>
      'You can switch back to English at any time.';

  @override
  String get settingsSectionGroup => 'Group';

  @override
  String get settingsManageGroup => 'Manage Group';

  @override
  String get settingsManageGroupSubtitle => 'Groups you created';

  @override
  String get settingsSectionPreferences => 'Preferences';

  @override
  String get settingsAccentColorTitle => 'Accent color';

  @override
  String get settingsAccentColorSubtitle => 'Choose the color used across Duo.';

  @override
  String get settingsHapticsTitle => 'Haptics for incoming voice messages';

  @override
  String settingsHapticsSubtitle(String detail) {
    return 'Continuous vibrations — $detail';
  }

  @override
  String get hapticsLight => 'Light';

  @override
  String get hapticsPulse => 'Pulse';

  @override
  String get hapticsWild => 'Wild';

  @override
  String get hapticsLightDetail => 'Two taps at the start and two at the end.';

  @override
  String get hapticsPulseDetail => 'A double-double burst — two quick pairs.';

  @override
  String get hapticsWildDetail => 'Continuous vibration for the whole nudge.';

  @override
  String get settingsSaveColor => 'Save color';

  @override
  String get settingsSaved => 'Settings saved';

  @override
  String get settingsSectionBackground => 'Background reliability';

  @override
  String get settingsMicPermission => 'Microphone permission';

  @override
  String get settingsMicReady => 'Ready';

  @override
  String get settingsMicRequired => 'Required before you can talk.';

  @override
  String get settingsNotificationPermission => 'Notification permission';

  @override
  String get settingsNotificationReady => 'Ready for background activity';

  @override
  String get settingsNotificationRequired =>
      'Required for reliable background activity.';

  @override
  String get settingsBatteryOptimization => 'Battery optimization';

  @override
  String get settingsBatteryUnrestricted => 'Unrestricted';

  @override
  String get settingsBatteryMayInterrupt =>
      'Your device may interrupt long sessions.';

  @override
  String get settingsClosedAppReceive => 'Closed-app receive';

  @override
  String get settingsClosedAppReady =>
      'Ready for nudges when the app is not open.';

  @override
  String get settingsClosedAppRequired =>
      'Allow notifications and unrestricted background activity.';

  @override
  String get settingsSectionLegal => 'Legal';

  @override
  String get settingsTerms => 'Terms & Conditions';

  @override
  String get settingsPrivacy => 'Privacy Policy';

  @override
  String get settingsSectionSubscription => 'Subscription';

  @override
  String get settingsDuoPro => 'Duo Pro';

  @override
  String get settingsViewPlans => 'View plans';

  @override
  String settingsTrialDaysLeft(int count) {
    return '$count days left in free trial';
  }

  @override
  String get settingsTrialOneDayLeft => '1 day left in free trial';

  @override
  String get settingsTrialLessThanADay =>
      'Less than a day left in your free trial';

  @override
  String get settingsFreePlanSubtitle =>
      'Free plan — live voice requires Duo Pro';

  @override
  String get settingsDuoProActiveSubtitle => 'You\'re on Duo Pro';

  @override
  String get settingsManageSubscription => 'Manage Subscription';

  @override
  String get settingsSectionSupport => 'Support';

  @override
  String get settingsSendFeedback => 'Send Feedback';

  @override
  String get settingsDebugLogs => 'Debug Logs';

  @override
  String get settingsSectionAccount => 'Account';

  @override
  String get settingsSignedInWithGoogle => 'Signed in with Google';

  @override
  String get settingsGoogleAccount => 'Google account';

  @override
  String get settingsLogOut => 'Log out';

  @override
  String get settingsLogOutTitle => 'Log out?';

  @override
  String get settingsLogOutMessage =>
      'You will need to sign in with Google to use Duo again.';

  @override
  String get settingsDeleteAccount => 'Delete account';

  @override
  String get settingsDeleteAccountTitle => 'Delete account permanently?';

  @override
  String get settingsDeleteAccountMessage =>
      'Your Duo profile, device information, and preferences will be deleted. This cannot be undone.';

  @override
  String get settingsDeleteAccountFailed =>
      'Account deletion couldn\'t be completed. Sign in with Google again and retry.';

  @override
  String get settingsCancel => 'Cancel';

  @override
  String get settingsEditProfile => 'Edit profile';

  @override
  String get settingsEditProfileSubtitle =>
      'This is how friends see you in your groups.';

  @override
  String get settingsDisplayName => 'Display name';

  @override
  String get settingsAvatarSection => 'AVATAR';

  @override
  String get settingsAvatar => 'Avatar';

  @override
  String get settingsPhoto => 'Photo';

  @override
  String get settingsYourPhoto => 'Your uploaded photo';

  @override
  String get settingsNoPhoto => 'No photo uploaded yet';

  @override
  String get settingsChangePhoto => 'Change photo';

  @override
  String get settingsUploadPhoto => 'Upload photo';

  @override
  String get settingsSaveProfile => 'Save profile';

  @override
  String get settingsSaving => 'Saving…';

  @override
  String get settingsDone => 'Done';

  @override
  String get settingsClose => 'Close';

  @override
  String get settingsProfileUpdated => 'Profile updated';

  @override
  String get settingsWelcomeDuoPro => 'Welcome to Duo Pro!';

  @override
  String get settingsPaywallFailed => 'Could not open subscription options.';

  @override
  String get settingsMicGranted => 'Microphone permission granted.';

  @override
  String get settingsMicDenied => 'Microphone permission was denied.';

  @override
  String get settingsNotificationGranted => 'Notification permission granted.';

  @override
  String get settingsNotificationDenied =>
      'Notification permission was denied.';

  @override
  String get settingsBatteryRequestSent =>
      'Battery optimization request sent. Check your device settings.';

  @override
  String get settingsClosedAppChecked => 'Closed-app receive setup checked.';

  @override
  String get settingsBeta => 'BETA';

  @override
  String get settingsTestingUnlocked => 'Testing section unlocked';

  @override
  String get settingsTestingSection => 'Testing';

  @override
  String get settingsTestingHomeTitle => 'Home screen';

  @override
  String get settingsTestingHomeSubtitle =>
      'Temporary looks for evaluating doodle backdrops. Layout stays the same.';

  @override
  String get accentCoral => 'Coral';

  @override
  String get accentLime => 'Lime';

  @override
  String get accentSky => 'Sky';

  @override
  String get accentViolet => 'Violet';

  @override
  String get accentAmber => 'Amber';

  @override
  String get accentPink => 'Pink';

  @override
  String get accentTeal => 'Teal';

  @override
  String get accentIndigo => 'Indigo';

  @override
  String get accentOrange => 'Orange';

  @override
  String get accentMint => 'Mint';

  @override
  String get accentYellow => 'Yellow';

  @override
  String get accentCyan => 'Cyan';

  @override
  String get homeJoinGroup => '+ join\ngroup';

  @override
  String get homeCreateGroup => '+ create\nnew group';

  @override
  String get homeJoinQuestion => 'Join?';

  @override
  String get homeNudgeTheGroup => 'Nudge the group';

  @override
  String get homeSendNudge => 'Send a nudge';

  @override
  String get homeSettings => 'Settings';

  @override
  String get homeSettingsSetup => 'Settings / Setup';

  @override
  String get homeTalk => 'Talk';

  @override
  String get homeTapToTalk => 'Tap to Talk';

  @override
  String get homeTapToStopTalking => 'Tap to Stop Talking';

  @override
  String get homeStatusUnavailable => 'Available after another member joins';

  @override
  String get homeStatusGoAway => 'Tap to go away';

  @override
  String get homeStatusGoOnline =>
      'Go online when someone is already live, or send a nudge to go together';

  @override
  String get homeInviteFriends => 'Invite friends';

  @override
  String get homeInviteFriendsSubtitle =>
      'Share this link. Your friend will open Duo and join this group automatically.';

  @override
  String get homeShareInviteLink => 'Share invite link';

  @override
  String get homeInviteLinkCopied => 'Invite link copied';

  @override
  String get homeFallbackPinCopied => 'Fallback PIN copied';

  @override
  String homeCopyPin(String code) {
    return 'Copy PIN $code';
  }

  @override
  String homeSelectGroup(String name) {
    return 'Select $name group';
  }

  @override
  String get homeSetup => 'Setup';

  @override
  String get homeSetupReady => 'Ready for foreground and closed-app voice';

  @override
  String get homeSetupNeedGroup => 'Create or join a group.';

  @override
  String get homeSetupNeedMic =>
      'Microphone permission has not been confirmed.';

  @override
  String get homeSetupNeedNotifications =>
      'Notification permission is required for closed-app nudges.';

  @override
  String get homeSetupNeedPush =>
      'Push registration is not ready. Reopen the app while online.';

  @override
  String get homeSetupNeedBattery =>
      'Battery optimization may interrupt background mode.';

  @override
  String get noGroupsTitle => 'Invite at least one friend to get started';

  @override
  String get noGroupsSubtitle =>
      'add your besties, the ones you talk to everyday 🫶';

  @override
  String get noGroupsCreate => 'Create Group';

  @override
  String get noGroupsShareInvite => 'Share an invite';

  @override
  String get noGroupsInviteClosedOnes => 'Invite Your Closed Ones';

  @override
  String get noGroupsHavePin =>
      'Have a group already? Use the PIN from a friend.';

  @override
  String get noGroupsJoinPin => 'Join with PIN';

  @override
  String get noGroupsNeedGroupFirst => 'Join or create a group first';

  @override
  String get inviteSheetTitle => 'Invite Your Closed Ones';

  @override
  String get inviteSheetGroupNameLabel => 'Name your group';

  @override
  String get inviteSheetGroupNameHint => 'e.g. Family, Besties…';

  @override
  String get inviteSheetContactsHeader => 'Select who to invite';

  @override
  String get inviteSheetSearchHint => 'Search contacts';

  @override
  String get inviteSheetNoContacts => 'No contacts found';

  @override
  String get inviteSheetPermissionDenied =>
      'Allow contacts to see who to invite';

  @override
  String get inviteSheetPermissionButton => 'Grant Contacts Access';

  @override
  String get inviteSheetSendButton => 'Create Group & Send Invite';

  @override
  String get inviteSheetCreating => 'Creating group…';

  @override
  String get inviteSheetGroupNameRequired => 'Enter a group name to continue';

  @override
  String get createGroupTitle => 'create group';

  @override
  String get createGroupSubtitle => 'name the group you want to start';

  @override
  String get createGroupHint => 'Group name';

  @override
  String get joinGroupTitle => 'join by pin';

  @override
  String get joinGroupSubtitle => 'ask your friend for their pin';

  @override
  String get joinGroupHint => 'Invite PIN';

  @override
  String get backTooltip => 'Back';

  @override
  String get subManageTitle => 'Manage Subscription';

  @override
  String get subBetaNote => 'Duo Pro is currently in beta.';

  @override
  String get subManageInStore => 'Manage in store';

  @override
  String get subManageInStoreSubtitle =>
      'Upgrade, cancel, or restore with App Store / Play';

  @override
  String get subContactTeam => 'Contact Team Duo';

  @override
  String get subContactTeamSubtitle => 'Billing questions and support';

  @override
  String get subBetaFooter =>
      'During beta, reply times may vary. For store refunds, use Manage in store when available.';

  @override
  String get subContactBody => 'Email us about billing, access, or feedback:';

  @override
  String get subEmailCopied => 'Email address copied to your clipboard.';

  @override
  String get subClose => 'Close';

  @override
  String get subCustomerCenterFailed =>
      'Could not open subscription management.';

  @override
  String get trialExpiredTitle => 'Your free trial has ended';

  @override
  String get trialExpiredBody =>
      'Keep talking with your friends by continuing with Duo Pro.';

  @override
  String get trialExpiredGetPro => 'Get Pro';

  @override
  String get crashTitle => 'The app ran into a problem';

  @override
  String get crashBody =>
      'Please send a report so we can look into what happened. This includes recent on-device logs from this phone.';

  @override
  String get crashSendReport => 'Send Report';

  @override
  String get crashTryAgain => 'Try Again';

  @override
  String get crashSendFailed =>
      'Couldn\'t send the report. Check your connection and try again.';

  @override
  String get startupSetupFailed =>
      'We couldn\'t finish setting up your account.';

  @override
  String get startupTryAgain => 'Try again';

  @override
  String get homeMicOnMute => 'Mic on — tap to mute';

  @override
  String homeConnectedToOtherGroup(String name) {
    return 'connected to $name • tap to nudge this group';
  }

  @override
  String get homeSomeoneLive => 'Someone is live — tap Join? to join';

  @override
  String get homeLiveVoiceLocked =>
      'Live voice requires Duo Pro — nudges and chat stay free';

  @override
  String get homeInviteFriendVoice => 'invite a friend to enable voice service';

  @override
  String get homeSendNudgeTogether => 'send a nudge to go online together';

  @override
  String get chatPresetJoin15Min => 'I\'ll join in 15 min';

  @override
  String get chatPresetWhereEveryone => 'Where is everyone?';

  @override
  String get chatPresetOnMyWay => 'On my way';

  @override
  String get chatPresetGiveMe5Min => 'Give me 5 min';

  @override
  String get chatMoreEmojis => 'More emojis';

  @override
  String get chatWriteCustomMessage => 'Write a custom message';

  @override
  String get chatMessageHint => 'Message the group…';

  @override
  String get feedbackSubtitle =>
      'Describe what went wrong. Recent on-device logs will be attached.';

  @override
  String get feedbackHint => 'What happened? (optional)';

  @override
  String get feedbackThanks => 'Thanks, your report was sent';

  @override
  String get feedbackSendFailed =>
      'Couldn\'t send your report. Check your connection and try again.';

  @override
  String get debugLogsReading => 'Reading today\'s log file…';

  @override
  String get debugLogsEmpty => 'No log file has been written yet today.';

  @override
  String debugLogsTodayFile(String size, String time) {
    return 'Today\'s file · $size · last updated $time';
  }

  @override
  String get debugLogsShareTitle => 'Share Log File';

  @override
  String get debugLogsShareSubtitle =>
      'Opens the system share sheet with today\'s .txt file';

  @override
  String get debugLogsCopyTitle => 'Copy to Clipboard';

  @override
  String get debugLogsCopySubtitle =>
      'Copies the full text of today\'s log file';

  @override
  String get debugLogsNoFile => 'No log file yet.';

  @override
  String get debugLogsCopied => 'Copied to clipboard';

  @override
  String get debugLogsShareSubject => 'Duo debug logs';

  @override
  String get legalLastUpdated => 'Last updated: July 12, 2026';

  @override
  String get legalTerms1Title => '1. Acceptance of terms';

  @override
  String get legalTerms1Body =>
      'By downloading, accessing, or using Duo, you agree to these Terms & Conditions. If you do not agree, do not use the app.';

  @override
  String get legalTerms2Title => '2. The service';

  @override
  String get legalTerms2Body =>
      'Duo lets people create or join private groups and exchange live voice audio. Availability, audio quality, and background delivery can depend on network access, device settings, permissions, and third-party services. The service is provided on an as-available basis.';

  @override
  String get legalTerms3Title => '3. Your responsibilities';

  @override
  String get legalTerms3Body =>
      'You are responsible for activity associated with your installation and for keeping invite codes private. You must have the right to share any name, profile picture, voice, or other content you provide. Do not use Duo to harass others, violate their privacy, impersonate someone, break the law, or interfere with the service.';

  @override
  String get legalTerms4Title => '4. Voice and permissions';

  @override
  String get legalTerms4Body =>
      'Duo requires microphone access to transmit live voice. You control when transmission starts through the in-app talk control. Notification and background permissions may be requested to support availability and audio features. You can change permissions in your device settings.';

  @override
  String get legalTerms5Title => '5. Third-party services';

  @override
  String get legalTerms5Body =>
      'Duo relies on service providers for authentication, data storage, media delivery, profile-image hosting, and infrastructure. Their services may be governed by separate terms and may occasionally be unavailable.';

  @override
  String get legalTerms6Title => '6. Suspension and termination';

  @override
  String get legalTerms6Body =>
      'We may restrict or end access when reasonably necessary to protect users, comply with law, prevent abuse, or maintain the service. You may stop using Duo at any time and remove the app from your device.';

  @override
  String get legalTerms7Title => '7. Disclaimers and liability';

  @override
  String get legalTerms7Body =>
      'To the extent permitted by law, Duo is provided without warranties of uninterrupted, error-free, or secure operation. We are not liable for indirect, incidental, special, consequential, or punitive damages arising from use of the app. Nothing in these terms limits rights or liability that cannot legally be limited.';

  @override
  String get legalTerms8Title => '8. Changes';

  @override
  String get legalTerms8Body =>
      'We may update these terms as the service changes. The updated date will appear at the top of this page. Continued use after an update means you accept the revised terms.';

  @override
  String get legalTerms9Title => '9. Contact';

  @override
  String get legalTerms9Body =>
      'Questions about these terms can be sent through the support channel shown on the Duo App Store listing.';

  @override
  String get legalPrivacy1Title => '1. Overview';

  @override
  String get legalPrivacy1Body =>
      'This Privacy Policy explains what Duo collects, why it is used, and the choices available to you when you use the app.';

  @override
  String get legalPrivacy2Title => '2. Information we collect';

  @override
  String get legalPrivacy2Body =>
      'We collect your Google-authenticated account identifier and email address, display name, optional profile picture, group membership and invite information, app settings, device and app-version identifiers, permission status, availability state, and basic service diagnostics. When you use live voice, microphone audio is transmitted to the other active members of your group.';

  @override
  String get legalPrivacy3Title => '3. How information is used';

  @override
  String get legalPrivacy3Body =>
      'Information is used to create your app identity, show your profile to group members, manage groups and invitations, connect live voice sessions, remember preferences, maintain availability, diagnose reliability, prevent misuse, and operate and improve Duo.';

  @override
  String get legalPrivacy4Title => '4. Audio';

  @override
  String get legalPrivacy4Body =>
      'Live voice is transmitted so group members can hear you. Duo is not designed to record or store the content of your live conversations. Service providers may process network and connection metadata needed to deliver the audio.';

  @override
  String get legalPrivacy5Title => '5. Service providers';

  @override
  String get legalPrivacy5Body =>
      'Duo uses providers including Google Firebase for authentication and app data, Cloudinary for profile-picture hosting, LiveKit for real-time audio, and hosting providers for application services. These providers process information on our behalf under their own privacy and security practices.';

  @override
  String get legalPrivacy6Title => '6. Sharing';

  @override
  String get legalPrivacy6Body =>
      'Your display name, profile picture, availability, and live voice are shared with members of groups you join. We may also disclose information to service providers, to comply with law or valid legal process, to protect users and the service, or as part of a business transfer. We do not sell personal information.';

  @override
  String get legalPrivacy7Title => '7. Retention and security';

  @override
  String get legalPrivacy7Body =>
      'We retain information only for as long as reasonably needed to provide the service, meet legal obligations, resolve disputes, and protect the app. We use reasonable safeguards, but no networked service can guarantee absolute security.';

  @override
  String get legalPrivacy8Title => '8. Your choices';

  @override
  String get legalPrivacy8Body =>
      'You may change your display name, profile picture, app preferences, and device permissions. You may leave groups, log out, or delete your account from Settings. Requests to access information can be made through the support channel shown on the Duo App Store listing. We may need information that identifies your app installation to complete a request.';

  @override
  String get legalPrivacy9Title => '9. Children';

  @override
  String get legalPrivacy9Body =>
      'Duo is not directed to children under 13, or the minimum age required by local law. We do not knowingly collect personal information from children below that age.';

  @override
  String get legalPrivacy10Title => '10. International processing';

  @override
  String get legalPrivacy10Body =>
      'Information may be processed in countries other than your own. Where required, appropriate safeguards are used for international transfers.';

  @override
  String get legalPrivacy11Title => '11. Changes and contact';

  @override
  String get legalPrivacy11Body =>
      'We may update this policy as Duo changes. The updated date will appear above. Privacy questions and requests can be sent through the support channel shown on the Duo App Store listing.';
}
