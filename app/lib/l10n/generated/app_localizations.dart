import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
  ];

  /// Welcome screen headline before sign-in
  ///
  /// In en, this message translates to:
  /// **'Welcome to Duo'**
  String get welcomeTitle;

  /// Welcome screen supporting copy
  ///
  /// In en, this message translates to:
  /// **'Sign in or create your account before setting up your profile.'**
  String get welcomeSubtitle;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get signingIn;

  /// No description provided for @termsFooter.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our terms & policies.'**
  String get termsFooter;

  /// No description provided for @googleSignInCancelled.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in was cancelled. Please try again.'**
  String get googleSignInCancelled;

  /// No description provided for @googleSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in couldn\'t be completed. Check your internet connection and try again.'**
  String get googleSignInFailed;

  /// No description provided for @languageMenuTooltip.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageMenuTooltip;

  /// No description provided for @chooseAvatarTitle.
  ///
  /// In en, this message translates to:
  /// **'choose an avatar'**
  String get chooseAvatarTitle;

  /// No description provided for @chooseAvatarSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You can add a custom photo later in Settings.'**
  String get chooseAvatarSubtitle;

  /// No description provided for @displayNameHint.
  ///
  /// In en, this message translates to:
  /// **'your name'**
  String get displayNameHint;

  /// No description provided for @displayNameSubtitle.
  ///
  /// In en, this message translates to:
  /// **'this is how your friends will see you'**
  String get displayNameSubtitle;

  /// No description provided for @permissionMicTitle.
  ///
  /// In en, this message translates to:
  /// **'mic'**
  String get permissionMicTitle;

  /// No description provided for @permissionMicSubtitle.
  ///
  /// In en, this message translates to:
  /// **'so your friends can hear you\nwhen you talk...'**
  String get permissionMicSubtitle;

  /// No description provided for @permissionNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'notifications'**
  String get permissionNotificationsTitle;

  /// No description provided for @permissionNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'know when your friends are\ntalking to you'**
  String get permissionNotificationsSubtitle;

  /// No description provided for @permissionBackgroundTitle.
  ///
  /// In en, this message translates to:
  /// **'background activity'**
  String get permissionBackgroundTitle;

  /// No description provided for @permissionBackgroundSubtitle.
  ///
  /// In en, this message translates to:
  /// **'receive nudges when duo\nisn\'t open'**
  String get permissionBackgroundSubtitle;

  /// No description provided for @permissionFootnote.
  ///
  /// In en, this message translates to:
  /// **'*we need those for duo to work'**
  String get permissionFootnote;

  /// No description provided for @permissionSetupFailed.
  ///
  /// In en, this message translates to:
  /// **'Setup could not be completed. Please try again.'**
  String get permissionSetupFailed;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguageSection.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageSection;

  /// No description provided for @settingsLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get settingsLanguageTitle;

  /// No description provided for @settingsLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You can switch back to English at any time.'**
  String get settingsLanguageSubtitle;

  /// No description provided for @settingsSectionGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get settingsSectionGroup;

  /// No description provided for @settingsManageGroup.
  ///
  /// In en, this message translates to:
  /// **'Manage Group'**
  String get settingsManageGroup;

  /// No description provided for @settingsManageGroupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Groups you created'**
  String get settingsManageGroupSubtitle;

  /// No description provided for @settingsSectionPreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get settingsSectionPreferences;

  /// No description provided for @settingsAccentColorTitle.
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get settingsAccentColorTitle;

  /// No description provided for @settingsAccentColorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the color used across Duo.'**
  String get settingsAccentColorSubtitle;

  /// No description provided for @settingsHapticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Haptics for incoming voice messages'**
  String get settingsHapticsTitle;

  /// No description provided for @settingsHapticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Continuous vibrations — {detail}'**
  String settingsHapticsSubtitle(String detail);

  /// No description provided for @hapticsLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get hapticsLight;

  /// No description provided for @hapticsPulse.
  ///
  /// In en, this message translates to:
  /// **'Pulse'**
  String get hapticsPulse;

  /// No description provided for @hapticsWild.
  ///
  /// In en, this message translates to:
  /// **'Wild'**
  String get hapticsWild;

  /// No description provided for @hapticsLightDetail.
  ///
  /// In en, this message translates to:
  /// **'Two taps at the start and two at the end.'**
  String get hapticsLightDetail;

  /// No description provided for @hapticsPulseDetail.
  ///
  /// In en, this message translates to:
  /// **'A double-double burst — two quick pairs.'**
  String get hapticsPulseDetail;

  /// No description provided for @hapticsWildDetail.
  ///
  /// In en, this message translates to:
  /// **'Continuous vibration for the whole nudge.'**
  String get hapticsWildDetail;

  /// No description provided for @settingsHomeBackgroundTitle.
  ///
  /// In en, this message translates to:
  /// **'Home background'**
  String get settingsHomeBackgroundTitle;

  /// No description provided for @settingsHomeBackgroundSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the backdrop on your home screen.'**
  String get settingsHomeBackgroundSubtitle;

  /// No description provided for @settingsHomeBackgroundDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get settingsHomeBackgroundDefault;

  /// No description provided for @settingsHomeBackgroundIllustrated.
  ///
  /// In en, this message translates to:
  /// **'Illustrated'**
  String get settingsHomeBackgroundIllustrated;

  /// No description provided for @settingsSaveColor.
  ///
  /// In en, this message translates to:
  /// **'Save color'**
  String get settingsSaveColor;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get settingsSaved;

  /// No description provided for @settingsAppVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String settingsAppVersion(String version);

  /// No description provided for @settingsSectionBackground.
  ///
  /// In en, this message translates to:
  /// **'Background reliability'**
  String get settingsSectionBackground;

  /// No description provided for @settingsMicPermission.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission'**
  String get settingsMicPermission;

  /// No description provided for @settingsMicReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get settingsMicReady;

  /// No description provided for @settingsMicRequired.
  ///
  /// In en, this message translates to:
  /// **'Required before you can talk.'**
  String get settingsMicRequired;

  /// No description provided for @settingsNotificationPermission.
  ///
  /// In en, this message translates to:
  /// **'Notification permission'**
  String get settingsNotificationPermission;

  /// No description provided for @settingsNotificationReady.
  ///
  /// In en, this message translates to:
  /// **'Ready for background activity'**
  String get settingsNotificationReady;

  /// No description provided for @settingsNotificationRequired.
  ///
  /// In en, this message translates to:
  /// **'Required for reliable background activity.'**
  String get settingsNotificationRequired;

  /// No description provided for @settingsBatteryOptimization.
  ///
  /// In en, this message translates to:
  /// **'Battery optimization'**
  String get settingsBatteryOptimization;

  /// No description provided for @settingsBatteryUnrestricted.
  ///
  /// In en, this message translates to:
  /// **'Unrestricted'**
  String get settingsBatteryUnrestricted;

  /// No description provided for @settingsBatteryMayInterrupt.
  ///
  /// In en, this message translates to:
  /// **'Your device may interrupt long sessions.'**
  String get settingsBatteryMayInterrupt;

  /// No description provided for @settingsClosedAppReceive.
  ///
  /// In en, this message translates to:
  /// **'Closed-app receive'**
  String get settingsClosedAppReceive;

  /// No description provided for @settingsClosedAppReady.
  ///
  /// In en, this message translates to:
  /// **'Ready for nudges when the app is not open.'**
  String get settingsClosedAppReady;

  /// No description provided for @settingsClosedAppRequired.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications and unrestricted background activity.'**
  String get settingsClosedAppRequired;

  /// No description provided for @settingsSectionLegal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get settingsSectionLegal;

  /// No description provided for @settingsTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions'**
  String get settingsTerms;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsPrivacy;

  /// No description provided for @settingsSectionSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get settingsSectionSubscription;

  /// No description provided for @settingsDuoPro.
  ///
  /// In en, this message translates to:
  /// **'Duo Pro'**
  String get settingsDuoPro;

  /// No description provided for @settingsViewPlans.
  ///
  /// In en, this message translates to:
  /// **'View plans'**
  String get settingsViewPlans;

  /// No description provided for @settingsTrialDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'⌛ {count} days left'**
  String settingsTrialDaysLeft(int count);

  /// No description provided for @settingsTrialOneDayLeft.
  ///
  /// In en, this message translates to:
  /// **'⌛ 1 day left'**
  String get settingsTrialOneDayLeft;

  /// No description provided for @settingsTrialLessThanADay.
  ///
  /// In en, this message translates to:
  /// **'⌛ Less than a day left'**
  String get settingsTrialLessThanADay;

  /// No description provided for @settingsFreePlanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Free plan — live voice requires Duo Pro'**
  String get settingsFreePlanSubtitle;

  /// No description provided for @settingsDuoProActiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re on Duo Pro'**
  String get settingsDuoProActiveSubtitle;

  /// No description provided for @settingsManageSubscription.
  ///
  /// In en, this message translates to:
  /// **'Manage Subscription'**
  String get settingsManageSubscription;

  /// No description provided for @settingsSectionSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get settingsSectionSupport;

  /// No description provided for @settingsSendFeedback.
  ///
  /// In en, this message translates to:
  /// **'Send Feedback'**
  String get settingsSendFeedback;

  /// No description provided for @settingsDebugLogs.
  ///
  /// In en, this message translates to:
  /// **'Debug Logs'**
  String get settingsDebugLogs;

  /// No description provided for @settingsSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsSectionAccount;

  /// No description provided for @settingsSignedInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Signed in with Google'**
  String get settingsSignedInWithGoogle;

  /// No description provided for @settingsGoogleAccount.
  ///
  /// In en, this message translates to:
  /// **'Google account'**
  String get settingsGoogleAccount;

  /// No description provided for @settingsLogOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get settingsLogOut;

  /// No description provided for @settingsLogOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get settingsLogOutTitle;

  /// No description provided for @settingsLogOutMessage.
  ///
  /// In en, this message translates to:
  /// **'You will need to sign in with Google to use Duo again.'**
  String get settingsLogOutMessage;

  /// No description provided for @settingsDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDeleteAccount;

  /// No description provided for @settingsDeleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account permanently?'**
  String get settingsDeleteAccountTitle;

  /// No description provided for @settingsDeleteAccountMessage.
  ///
  /// In en, this message translates to:
  /// **'Your Duo profile, device information, and preferences will be deleted. This cannot be undone.'**
  String get settingsDeleteAccountMessage;

  /// No description provided for @settingsDeleteAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Account deletion couldn\'t be completed. Sign in with Google again and retry.'**
  String get settingsDeleteAccountFailed;

  /// No description provided for @settingsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsCancel;

  /// No description provided for @settingsEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get settingsEditProfile;

  /// No description provided for @settingsEditProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This is how friends see you in your groups.'**
  String get settingsEditProfileSubtitle;

  /// No description provided for @settingsDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get settingsDisplayName;

  /// No description provided for @settingsAvatarSection.
  ///
  /// In en, this message translates to:
  /// **'AVATAR'**
  String get settingsAvatarSection;

  /// No description provided for @settingsAvatar.
  ///
  /// In en, this message translates to:
  /// **'Avatar'**
  String get settingsAvatar;

  /// No description provided for @settingsPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get settingsPhoto;

  /// No description provided for @settingsYourPhoto.
  ///
  /// In en, this message translates to:
  /// **'Your uploaded photo'**
  String get settingsYourPhoto;

  /// No description provided for @settingsNoPhoto.
  ///
  /// In en, this message translates to:
  /// **'No photo uploaded yet'**
  String get settingsNoPhoto;

  /// No description provided for @settingsChangePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get settingsChangePhoto;

  /// No description provided for @settingsUploadPhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload photo'**
  String get settingsUploadPhoto;

  /// No description provided for @settingsSaveProfile.
  ///
  /// In en, this message translates to:
  /// **'Save profile'**
  String get settingsSaveProfile;

  /// No description provided for @settingsSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get settingsSaving;

  /// No description provided for @settingsDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get settingsDone;

  /// No description provided for @settingsClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get settingsClose;

  /// No description provided for @settingsProfileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get settingsProfileUpdated;

  /// No description provided for @settingsWelcomeDuoPro.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Duo Pro!'**
  String get settingsWelcomeDuoPro;

  /// No description provided for @settingsPaywallFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open subscription options.'**
  String get settingsPaywallFailed;

  /// No description provided for @settingsMicGranted.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission granted.'**
  String get settingsMicGranted;

  /// No description provided for @settingsMicDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission was denied.'**
  String get settingsMicDenied;

  /// No description provided for @settingsNotificationGranted.
  ///
  /// In en, this message translates to:
  /// **'Notification permission granted.'**
  String get settingsNotificationGranted;

  /// No description provided for @settingsNotificationDenied.
  ///
  /// In en, this message translates to:
  /// **'Notification permission was denied.'**
  String get settingsNotificationDenied;

  /// No description provided for @settingsBatteryRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Battery optimization request sent. Check your device settings.'**
  String get settingsBatteryRequestSent;

  /// No description provided for @settingsClosedAppChecked.
  ///
  /// In en, this message translates to:
  /// **'Closed-app receive setup checked.'**
  String get settingsClosedAppChecked;

  /// No description provided for @settingsBeta.
  ///
  /// In en, this message translates to:
  /// **'BETA'**
  String get settingsBeta;

  /// No description provided for @settingsTestingUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Testing section unlocked'**
  String get settingsTestingUnlocked;

  /// No description provided for @settingsTestingSection.
  ///
  /// In en, this message translates to:
  /// **'Testing'**
  String get settingsTestingSection;

  /// No description provided for @settingsTestingHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Home screen'**
  String get settingsTestingHomeTitle;

  /// No description provided for @settingsTestingHomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Temporary looks for evaluating doodle backdrops. Layout stays the same.'**
  String get settingsTestingHomeSubtitle;

  /// No description provided for @accentCoral.
  ///
  /// In en, this message translates to:
  /// **'Coral'**
  String get accentCoral;

  /// No description provided for @accentLime.
  ///
  /// In en, this message translates to:
  /// **'Lime'**
  String get accentLime;

  /// No description provided for @accentSky.
  ///
  /// In en, this message translates to:
  /// **'Sky'**
  String get accentSky;

  /// No description provided for @accentViolet.
  ///
  /// In en, this message translates to:
  /// **'Violet'**
  String get accentViolet;

  /// No description provided for @accentAmber.
  ///
  /// In en, this message translates to:
  /// **'Amber'**
  String get accentAmber;

  /// No description provided for @accentPink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get accentPink;

  /// No description provided for @accentTeal.
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get accentTeal;

  /// No description provided for @accentIndigo.
  ///
  /// In en, this message translates to:
  /// **'Indigo'**
  String get accentIndigo;

  /// No description provided for @accentOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get accentOrange;

  /// No description provided for @accentMint.
  ///
  /// In en, this message translates to:
  /// **'Mint'**
  String get accentMint;

  /// No description provided for @accentYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get accentYellow;

  /// No description provided for @accentCyan.
  ///
  /// In en, this message translates to:
  /// **'Cyan'**
  String get accentCyan;

  /// No description provided for @homeJoinGroup.
  ///
  /// In en, this message translates to:
  /// **'+ join\ngroup'**
  String get homeJoinGroup;

  /// No description provided for @homeCreateGroup.
  ///
  /// In en, this message translates to:
  /// **'+ create\nnew group'**
  String get homeCreateGroup;

  /// No description provided for @homeJoinQuestion.
  ///
  /// In en, this message translates to:
  /// **'Join?'**
  String get homeJoinQuestion;

  /// No description provided for @homeNudgeTheGroup.
  ///
  /// In en, this message translates to:
  /// **'Nudge the group'**
  String get homeNudgeTheGroup;

  /// No description provided for @homeSendNudge.
  ///
  /// In en, this message translates to:
  /// **'Send a nudge'**
  String get homeSendNudge;

  /// No description provided for @homeSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get homeSettings;

  /// No description provided for @homeSettingsSetup.
  ///
  /// In en, this message translates to:
  /// **'Settings / Setup'**
  String get homeSettingsSetup;

  /// No description provided for @homeTalk.
  ///
  /// In en, this message translates to:
  /// **'Talk'**
  String get homeTalk;

  /// No description provided for @homeTapToTalk.
  ///
  /// In en, this message translates to:
  /// **'Tap to Talk'**
  String get homeTapToTalk;

  /// No description provided for @homeTapToStopTalking.
  ///
  /// In en, this message translates to:
  /// **'Tap to Stop Talking'**
  String get homeTapToStopTalking;

  /// No description provided for @homeStatusUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Available after another member joins'**
  String get homeStatusUnavailable;

  /// No description provided for @homeStatusGoAway.
  ///
  /// In en, this message translates to:
  /// **'Tap to go away'**
  String get homeStatusGoAway;

  /// No description provided for @homeStatusGoOnline.
  ///
  /// In en, this message translates to:
  /// **'Go online when someone is already live, or send a nudge to go together'**
  String get homeStatusGoOnline;

  /// No description provided for @homeInviteFriends.
  ///
  /// In en, this message translates to:
  /// **'Invite friends'**
  String get homeInviteFriends;

  /// No description provided for @homeInviteFriendsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share this link. Your friend will open Duo and join this group automatically.'**
  String get homeInviteFriendsSubtitle;

  /// No description provided for @homeShareInviteLink.
  ///
  /// In en, this message translates to:
  /// **'Share invite link'**
  String get homeShareInviteLink;

  /// No description provided for @homeInviteLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Invite link copied'**
  String get homeInviteLinkCopied;

  /// No description provided for @homeFallbackPinCopied.
  ///
  /// In en, this message translates to:
  /// **'Fallback PIN copied'**
  String get homeFallbackPinCopied;

  /// No description provided for @homeCopyPin.
  ///
  /// In en, this message translates to:
  /// **'Copy PIN {code}'**
  String homeCopyPin(String code);

  /// No description provided for @homeSelectGroup.
  ///
  /// In en, this message translates to:
  /// **'Select {name} group'**
  String homeSelectGroup(String name);

  /// No description provided for @homeSetup.
  ///
  /// In en, this message translates to:
  /// **'Setup'**
  String get homeSetup;

  /// No description provided for @homeSetupReady.
  ///
  /// In en, this message translates to:
  /// **'Ready for foreground and closed-app voice'**
  String get homeSetupReady;

  /// No description provided for @homeSetupNeedGroup.
  ///
  /// In en, this message translates to:
  /// **'Create or join a group.'**
  String get homeSetupNeedGroup;

  /// No description provided for @homeSetupNeedMic.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission has not been confirmed.'**
  String get homeSetupNeedMic;

  /// No description provided for @homeSetupNeedNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notification permission is required for closed-app nudges.'**
  String get homeSetupNeedNotifications;

  /// No description provided for @homeSetupNeedPush.
  ///
  /// In en, this message translates to:
  /// **'Push registration is not ready. Reopen the app while online.'**
  String get homeSetupNeedPush;

  /// No description provided for @homeSetupNeedBattery.
  ///
  /// In en, this message translates to:
  /// **'Battery optimization may interrupt background mode.'**
  String get homeSetupNeedBattery;

  /// No description provided for @noGroupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite at least one friend to get started'**
  String get noGroupsTitle;

  /// No description provided for @noGroupsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'add your besties, the ones you talk to everyday 🫶'**
  String get noGroupsSubtitle;

  /// No description provided for @noGroupsCreate.
  ///
  /// In en, this message translates to:
  /// **'Create Group'**
  String get noGroupsCreate;

  /// No description provided for @noGroupsShareInvite.
  ///
  /// In en, this message translates to:
  /// **'Share an invite'**
  String get noGroupsShareInvite;

  /// No description provided for @noGroupsInviteClosedOnes.
  ///
  /// In en, this message translates to:
  /// **'Invite Your Closed Ones'**
  String get noGroupsInviteClosedOnes;

  /// No description provided for @noGroupsHavePin.
  ///
  /// In en, this message translates to:
  /// **'Have a group already? Use the PIN from a friend.'**
  String get noGroupsHavePin;

  /// No description provided for @noGroupsJoinPin.
  ///
  /// In en, this message translates to:
  /// **'Join with PIN'**
  String get noGroupsJoinPin;

  /// No description provided for @noGroupsNeedGroupFirst.
  ///
  /// In en, this message translates to:
  /// **'Join or create a group first'**
  String get noGroupsNeedGroupFirst;

  /// No description provided for @inviteSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite Your Closed Ones'**
  String get inviteSheetTitle;

  /// No description provided for @inviteSheetGroupNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name your group'**
  String get inviteSheetGroupNameLabel;

  /// No description provided for @inviteSheetGroupNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Family, Besties…'**
  String get inviteSheetGroupNameHint;

  /// No description provided for @inviteSheetContactsHeader.
  ///
  /// In en, this message translates to:
  /// **'Select who to invite'**
  String get inviteSheetContactsHeader;

  /// No description provided for @inviteSheetSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search contacts'**
  String get inviteSheetSearchHint;

  /// No description provided for @inviteSheetNoContacts.
  ///
  /// In en, this message translates to:
  /// **'No contacts found'**
  String get inviteSheetNoContacts;

  /// No description provided for @inviteSheetPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Allow contacts to see who to invite'**
  String get inviteSheetPermissionDenied;

  /// No description provided for @inviteSheetPermissionButton.
  ///
  /// In en, this message translates to:
  /// **'Grant Contacts Access'**
  String get inviteSheetPermissionButton;

  /// No description provided for @inviteSheetSendButton.
  ///
  /// In en, this message translates to:
  /// **'Create Group & Send Invite'**
  String get inviteSheetSendButton;

  /// No description provided for @inviteSheetCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating group…'**
  String get inviteSheetCreating;

  /// No description provided for @inviteSheetGroupNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a group name to continue'**
  String get inviteSheetGroupNameRequired;

  /// No description provided for @createGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'create group'**
  String get createGroupTitle;

  /// No description provided for @createGroupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'name the group you want to start'**
  String get createGroupSubtitle;

  /// No description provided for @createGroupHint.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get createGroupHint;

  /// No description provided for @joinGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'join by pin'**
  String get joinGroupTitle;

  /// No description provided for @joinGroupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ask your friend for their pin'**
  String get joinGroupSubtitle;

  /// No description provided for @joinGroupHint.
  ///
  /// In en, this message translates to:
  /// **'Invite PIN'**
  String get joinGroupHint;

  /// No description provided for @backTooltip.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backTooltip;

  /// No description provided for @subManageTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage Subscription'**
  String get subManageTitle;

  /// No description provided for @subBetaNote.
  ///
  /// In en, this message translates to:
  /// **'Duo Pro is currently in beta.'**
  String get subBetaNote;

  /// No description provided for @subManageInStore.
  ///
  /// In en, this message translates to:
  /// **'Manage in store'**
  String get subManageInStore;

  /// No description provided for @subManageInStoreSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upgrade, cancel, or restore with App Store / Play'**
  String get subManageInStoreSubtitle;

  /// No description provided for @subContactTeam.
  ///
  /// In en, this message translates to:
  /// **'Contact Team Duo'**
  String get subContactTeam;

  /// No description provided for @subContactTeamSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Billing questions and support'**
  String get subContactTeamSubtitle;

  /// No description provided for @subBetaFooter.
  ///
  /// In en, this message translates to:
  /// **'During beta, reply times may vary. For store refunds, use Manage in store when available.'**
  String get subBetaFooter;

  /// No description provided for @subContactBody.
  ///
  /// In en, this message translates to:
  /// **'Email us about billing, access, or feedback:'**
  String get subContactBody;

  /// No description provided for @subEmailCopied.
  ///
  /// In en, this message translates to:
  /// **'Email address copied to your clipboard.'**
  String get subEmailCopied;

  /// No description provided for @subClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get subClose;

  /// No description provided for @subCustomerCenterFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open subscription management.'**
  String get subCustomerCenterFailed;

  /// Hard paywall title after the free trial
  ///
  /// In en, this message translates to:
  /// **'Your free trial has ended'**
  String get trialExpiredTitle;

  /// Hard paywall body after the free trial
  ///
  /// In en, this message translates to:
  /// **'Keep talking with your friends by continuing with Duo Pro.'**
  String get trialExpiredBody;

  /// CTA that opens the Duo Pro paywall
  ///
  /// In en, this message translates to:
  /// **'Get Pro'**
  String get trialExpiredGetPro;

  /// No description provided for @crashTitle.
  ///
  /// In en, this message translates to:
  /// **'The app ran into a problem'**
  String get crashTitle;

  /// No description provided for @crashBody.
  ///
  /// In en, this message translates to:
  /// **'Please send a report so we can look into what happened. This includes recent on-device logs from this phone.'**
  String get crashBody;

  /// No description provided for @crashSendReport.
  ///
  /// In en, this message translates to:
  /// **'Send Report'**
  String get crashSendReport;

  /// No description provided for @crashTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get crashTryAgain;

  /// No description provided for @crashSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the report. Check your connection and try again.'**
  String get crashSendFailed;

  /// No description provided for @startupSetupFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t finish setting up your account.'**
  String get startupSetupFailed;

  /// No description provided for @startupTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get startupTryAgain;

  /// No description provided for @homeMicOnMute.
  ///
  /// In en, this message translates to:
  /// **'Mic on — tap to mute'**
  String get homeMicOnMute;

  /// No description provided for @homeConnectedToOtherGroup.
  ///
  /// In en, this message translates to:
  /// **'connected to {name} • tap to nudge this group'**
  String homeConnectedToOtherGroup(String name);

  /// No description provided for @homeSomeoneLive.
  ///
  /// In en, this message translates to:
  /// **'Someone is live — tap Join? to join'**
  String get homeSomeoneLive;

  /// No description provided for @homeLiveVoiceLocked.
  ///
  /// In en, this message translates to:
  /// **'Live voice requires Duo Pro — nudges and chat stay free'**
  String get homeLiveVoiceLocked;

  /// No description provided for @homeInviteFriendVoice.
  ///
  /// In en, this message translates to:
  /// **'invite a friend to enable voice service'**
  String get homeInviteFriendVoice;

  /// No description provided for @homeSendNudgeTogether.
  ///
  /// In en, this message translates to:
  /// **'send a nudge to go online together'**
  String get homeSendNudgeTogether;

  /// No description provided for @chatPresetJoin15Min.
  ///
  /// In en, this message translates to:
  /// **'I\'ll join in 15 min'**
  String get chatPresetJoin15Min;

  /// No description provided for @chatPresetWhereEveryone.
  ///
  /// In en, this message translates to:
  /// **'Where is everyone?'**
  String get chatPresetWhereEveryone;

  /// No description provided for @chatPresetOnMyWay.
  ///
  /// In en, this message translates to:
  /// **'On my way'**
  String get chatPresetOnMyWay;

  /// No description provided for @chatPresetGiveMe5Min.
  ///
  /// In en, this message translates to:
  /// **'Give me 5 min'**
  String get chatPresetGiveMe5Min;

  /// No description provided for @chatMoreEmojis.
  ///
  /// In en, this message translates to:
  /// **'More emojis'**
  String get chatMoreEmojis;

  /// No description provided for @chatWriteCustomMessage.
  ///
  /// In en, this message translates to:
  /// **'Write a custom message'**
  String get chatWriteCustomMessage;

  /// No description provided for @chatMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Message the group…'**
  String get chatMessageHint;

  /// No description provided for @feedbackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Describe what went wrong. Recent on-device logs will be attached.'**
  String get feedbackSubtitle;

  /// No description provided for @feedbackHint.
  ///
  /// In en, this message translates to:
  /// **'What happened? (optional)'**
  String get feedbackHint;

  /// No description provided for @feedbackThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks, your report was sent'**
  String get feedbackThanks;

  /// No description provided for @feedbackSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send your report. Check your connection and try again.'**
  String get feedbackSendFailed;

  /// No description provided for @debugLogsReading.
  ///
  /// In en, this message translates to:
  /// **'Reading today\'s log file…'**
  String get debugLogsReading;

  /// No description provided for @debugLogsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No log file has been written yet today.'**
  String get debugLogsEmpty;

  /// No description provided for @debugLogsTodayFile.
  ///
  /// In en, this message translates to:
  /// **'Today\'s file · {size} · last updated {time}'**
  String debugLogsTodayFile(String size, String time);

  /// No description provided for @debugLogsShareTitle.
  ///
  /// In en, this message translates to:
  /// **'Share Log File'**
  String get debugLogsShareTitle;

  /// No description provided for @debugLogsShareSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Opens the system share sheet with today\'s .txt file'**
  String get debugLogsShareSubtitle;

  /// No description provided for @debugLogsCopyTitle.
  ///
  /// In en, this message translates to:
  /// **'Copy to Clipboard'**
  String get debugLogsCopyTitle;

  /// No description provided for @debugLogsCopySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Copies the full text of today\'s log file'**
  String get debugLogsCopySubtitle;

  /// No description provided for @debugLogsNoFile.
  ///
  /// In en, this message translates to:
  /// **'No log file yet.'**
  String get debugLogsNoFile;

  /// No description provided for @debugLogsCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get debugLogsCopied;

  /// No description provided for @debugLogsShareSubject.
  ///
  /// In en, this message translates to:
  /// **'Duo debug logs'**
  String get debugLogsShareSubject;

  /// No description provided for @legalLastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated: July 12, 2026'**
  String get legalLastUpdated;

  /// No description provided for @legalTerms1Title.
  ///
  /// In en, this message translates to:
  /// **'1. Acceptance of terms'**
  String get legalTerms1Title;

  /// No description provided for @legalTerms1Body.
  ///
  /// In en, this message translates to:
  /// **'By downloading, accessing, or using Duo, you agree to these Terms & Conditions. If you do not agree, do not use the app.'**
  String get legalTerms1Body;

  /// No description provided for @legalTerms2Title.
  ///
  /// In en, this message translates to:
  /// **'2. The service'**
  String get legalTerms2Title;

  /// No description provided for @legalTerms2Body.
  ///
  /// In en, this message translates to:
  /// **'Duo lets people create or join private groups and exchange live voice audio. Availability, audio quality, and background delivery can depend on network access, device settings, permissions, and third-party services. The service is provided on an as-available basis.'**
  String get legalTerms2Body;

  /// No description provided for @legalTerms3Title.
  ///
  /// In en, this message translates to:
  /// **'3. Your responsibilities'**
  String get legalTerms3Title;

  /// No description provided for @legalTerms3Body.
  ///
  /// In en, this message translates to:
  /// **'You are responsible for activity associated with your installation and for keeping invite codes private. You must have the right to share any name, profile picture, voice, or other content you provide. Do not use Duo to harass others, violate their privacy, impersonate someone, break the law, or interfere with the service.'**
  String get legalTerms3Body;

  /// No description provided for @legalTerms4Title.
  ///
  /// In en, this message translates to:
  /// **'4. Voice and permissions'**
  String get legalTerms4Title;

  /// No description provided for @legalTerms4Body.
  ///
  /// In en, this message translates to:
  /// **'Duo requires microphone access to transmit live voice. You control when transmission starts through the in-app talk control. Notification and background permissions may be requested to support availability and audio features. You can change permissions in your device settings.'**
  String get legalTerms4Body;

  /// No description provided for @legalTerms5Title.
  ///
  /// In en, this message translates to:
  /// **'5. Third-party services'**
  String get legalTerms5Title;

  /// No description provided for @legalTerms5Body.
  ///
  /// In en, this message translates to:
  /// **'Duo relies on service providers for authentication, data storage, media delivery, profile-image hosting, and infrastructure. Their services may be governed by separate terms and may occasionally be unavailable.'**
  String get legalTerms5Body;

  /// No description provided for @legalTerms6Title.
  ///
  /// In en, this message translates to:
  /// **'6. Suspension and termination'**
  String get legalTerms6Title;

  /// No description provided for @legalTerms6Body.
  ///
  /// In en, this message translates to:
  /// **'We may restrict or end access when reasonably necessary to protect users, comply with law, prevent abuse, or maintain the service. You may stop using Duo at any time and remove the app from your device.'**
  String get legalTerms6Body;

  /// No description provided for @legalTerms7Title.
  ///
  /// In en, this message translates to:
  /// **'7. Disclaimers and liability'**
  String get legalTerms7Title;

  /// No description provided for @legalTerms7Body.
  ///
  /// In en, this message translates to:
  /// **'To the extent permitted by law, Duo is provided without warranties of uninterrupted, error-free, or secure operation. We are not liable for indirect, incidental, special, consequential, or punitive damages arising from use of the app. Nothing in these terms limits rights or liability that cannot legally be limited.'**
  String get legalTerms7Body;

  /// No description provided for @legalTerms8Title.
  ///
  /// In en, this message translates to:
  /// **'8. Changes'**
  String get legalTerms8Title;

  /// No description provided for @legalTerms8Body.
  ///
  /// In en, this message translates to:
  /// **'We may update these terms as the service changes. The updated date will appear at the top of this page. Continued use after an update means you accept the revised terms.'**
  String get legalTerms8Body;

  /// No description provided for @legalTerms9Title.
  ///
  /// In en, this message translates to:
  /// **'9. Contact'**
  String get legalTerms9Title;

  /// No description provided for @legalTerms9Body.
  ///
  /// In en, this message translates to:
  /// **'Questions about these terms can be sent through the support channel shown on the Duo App Store listing.'**
  String get legalTerms9Body;

  /// No description provided for @legalPrivacy1Title.
  ///
  /// In en, this message translates to:
  /// **'1. Overview'**
  String get legalPrivacy1Title;

  /// No description provided for @legalPrivacy1Body.
  ///
  /// In en, this message translates to:
  /// **'This Privacy Policy explains what Duo collects, why it is used, and the choices available to you when you use the app.'**
  String get legalPrivacy1Body;

  /// No description provided for @legalPrivacy2Title.
  ///
  /// In en, this message translates to:
  /// **'2. Information we collect'**
  String get legalPrivacy2Title;

  /// No description provided for @legalPrivacy2Body.
  ///
  /// In en, this message translates to:
  /// **'We collect your Google-authenticated account identifier and email address, display name, optional profile picture, group membership and invite information, app settings, device and app-version identifiers, permission status, availability state, and basic service diagnostics. When you use live voice, microphone audio is transmitted to the other active members of your group.'**
  String get legalPrivacy2Body;

  /// No description provided for @legalPrivacy3Title.
  ///
  /// In en, this message translates to:
  /// **'3. How information is used'**
  String get legalPrivacy3Title;

  /// No description provided for @legalPrivacy3Body.
  ///
  /// In en, this message translates to:
  /// **'Information is used to create your app identity, show your profile to group members, manage groups and invitations, connect live voice sessions, remember preferences, maintain availability, diagnose reliability, prevent misuse, and operate and improve Duo.'**
  String get legalPrivacy3Body;

  /// No description provided for @legalPrivacy4Title.
  ///
  /// In en, this message translates to:
  /// **'4. Audio'**
  String get legalPrivacy4Title;

  /// No description provided for @legalPrivacy4Body.
  ///
  /// In en, this message translates to:
  /// **'Live voice is transmitted so group members can hear you. Duo is not designed to record or store the content of your live conversations. Service providers may process network and connection metadata needed to deliver the audio.'**
  String get legalPrivacy4Body;

  /// No description provided for @legalPrivacy5Title.
  ///
  /// In en, this message translates to:
  /// **'5. Service providers'**
  String get legalPrivacy5Title;

  /// No description provided for @legalPrivacy5Body.
  ///
  /// In en, this message translates to:
  /// **'Duo uses providers including Google Firebase for authentication and app data, Cloudinary for profile-picture hosting, LiveKit for real-time audio, and hosting providers for application services. These providers process information on our behalf under their own privacy and security practices.'**
  String get legalPrivacy5Body;

  /// No description provided for @legalPrivacy6Title.
  ///
  /// In en, this message translates to:
  /// **'6. Sharing'**
  String get legalPrivacy6Title;

  /// No description provided for @legalPrivacy6Body.
  ///
  /// In en, this message translates to:
  /// **'Your display name, profile picture, availability, and live voice are shared with members of groups you join. We may also disclose information to service providers, to comply with law or valid legal process, to protect users and the service, or as part of a business transfer. We do not sell personal information.'**
  String get legalPrivacy6Body;

  /// No description provided for @legalPrivacy7Title.
  ///
  /// In en, this message translates to:
  /// **'7. Retention and security'**
  String get legalPrivacy7Title;

  /// No description provided for @legalPrivacy7Body.
  ///
  /// In en, this message translates to:
  /// **'We retain information only for as long as reasonably needed to provide the service, meet legal obligations, resolve disputes, and protect the app. We use reasonable safeguards, but no networked service can guarantee absolute security.'**
  String get legalPrivacy7Body;

  /// No description provided for @legalPrivacy8Title.
  ///
  /// In en, this message translates to:
  /// **'8. Your choices'**
  String get legalPrivacy8Title;

  /// No description provided for @legalPrivacy8Body.
  ///
  /// In en, this message translates to:
  /// **'You may change your display name, profile picture, app preferences, and device permissions. You may leave groups, log out, or delete your account from Settings. Requests to access information can be made through the support channel shown on the Duo App Store listing. We may need information that identifies your app installation to complete a request.'**
  String get legalPrivacy8Body;

  /// No description provided for @legalPrivacy9Title.
  ///
  /// In en, this message translates to:
  /// **'9. Children'**
  String get legalPrivacy9Title;

  /// No description provided for @legalPrivacy9Body.
  ///
  /// In en, this message translates to:
  /// **'Duo is not directed to children under 13, or the minimum age required by local law. We do not knowingly collect personal information from children below that age.'**
  String get legalPrivacy9Body;

  /// No description provided for @legalPrivacy10Title.
  ///
  /// In en, this message translates to:
  /// **'10. International processing'**
  String get legalPrivacy10Title;

  /// No description provided for @legalPrivacy10Body.
  ///
  /// In en, this message translates to:
  /// **'Information may be processed in countries other than your own. Where required, appropriate safeguards are used for international transfers.'**
  String get legalPrivacy10Body;

  /// No description provided for @legalPrivacy11Title.
  ///
  /// In en, this message translates to:
  /// **'11. Changes and contact'**
  String get legalPrivacy11Title;

  /// No description provided for @legalPrivacy11Body.
  ///
  /// In en, this message translates to:
  /// **'We may update this policy as Duo changes. The updated date will appear above. Privacy questions and requests can be sent through the support channel shown on the Duo App Store listing.'**
  String get legalPrivacy11Body;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'fr', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
