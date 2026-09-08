// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get welcomeTitle => 'Willkommen bei Duo';

  @override
  String get welcomeSubtitle =>
      'Melde dich an oder erstelle ein Konto, bevor du dein Profil einrichtest.';

  @override
  String get continueWithGoogle => 'Mit Google fortfahren';

  @override
  String get signingIn => 'Anmeldung…';

  @override
  String get termsFooter =>
      'Mit dem Fortfahren stimmst du unseren Bedingungen und Richtlinien zu.';

  @override
  String get googleSignInCancelled =>
      'Die Google-Anmeldung wurde abgebrochen. Bitte versuche es erneut.';

  @override
  String get googleSignInFailed =>
      'Die Google-Anmeldung konnte nicht abgeschlossen werden. Prüfe deine Internetverbindung und versuche es erneut.';

  @override
  String get languageMenuTooltip => 'Sprache';

  @override
  String get chooseAvatarTitle => 'wähle einen avatar';

  @override
  String get chooseAvatarSubtitle =>
      'Ein eigenes Foto kannst du später in den Einstellungen hinzufügen.';

  @override
  String get displayNameHint => 'dein name';

  @override
  String get displayNameSubtitle => 'so sehen dich deine freunde';

  @override
  String get permissionMicTitle => 'mikrofon';

  @override
  String get permissionMicSubtitle =>
      'damit dich deine freunde hören,\nwenn du sprichst...';

  @override
  String get permissionNotificationsTitle => 'benachrichtigungen';

  @override
  String get permissionNotificationsSubtitle =>
      'erfahren, wenn deine freunde\nmit dir sprechen';

  @override
  String get permissionBackgroundTitle => 'hintergrundaktivität';

  @override
  String get permissionBackgroundSubtitle =>
      'nudges empfangen, wenn duo\nnicht geöffnet ist';

  @override
  String get permissionFootnote => '*wir brauchen das, damit duo funktioniert';

  @override
  String get permissionSetupFailed =>
      'Die Einrichtung konnte nicht abgeschlossen werden. Bitte versuche es erneut.';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsLanguageSection => 'Sprache';

  @override
  String get settingsLanguageTitle => 'App-Sprache';

  @override
  String get settingsLanguageSubtitle =>
      'Du kannst jederzeit zu Englisch zurückwechseln.';

  @override
  String get settingsSectionGroup => 'Gruppe';

  @override
  String get settingsManageGroup => 'Gruppe verwalten';

  @override
  String get settingsManageGroupSubtitle => 'Gruppen, die du erstellt hast';

  @override
  String get settingsSectionPreferences => 'Einstellungen';

  @override
  String get settingsAccentColorTitle => 'Akzentfarbe';

  @override
  String get settingsAccentColorSubtitle =>
      'Wähle die Farbe, die in Duo verwendet wird.';

  @override
  String get settingsHapticsTitle => 'Haptik für eingehende Sprachnachrichten';

  @override
  String settingsHapticsSubtitle(String detail) {
    return 'Durchgehende Vibrationen — $detail';
  }

  @override
  String get hapticsLight => 'Leicht';

  @override
  String get hapticsPulse => 'Impuls';

  @override
  String get hapticsWild => 'Stark';

  @override
  String get hapticsLightDetail => 'Zwei Impulse am Anfang und zwei am Ende.';

  @override
  String get hapticsPulseDetail => 'Ein Doppelimpuls — zwei schnelle Paare.';

  @override
  String get hapticsWildDetail =>
      'Durchgehende Vibration während des gesamten Nudges.';

  @override
  String get settingsSaveColor => 'Farbe speichern';

  @override
  String get settingsSaved => 'Einstellungen gespeichert';

  @override
  String get settingsSectionBackground => 'Hintergrundzuverlässigkeit';

  @override
  String get settingsMicPermission => 'Mikrofonberechtigung';

  @override
  String get settingsMicReady => 'Bereit';

  @override
  String get settingsMicRequired => 'Erforderlich, bevor du sprechen kannst.';

  @override
  String get settingsNotificationPermission => 'Benachrichtigungsberechtigung';

  @override
  String get settingsNotificationReady => 'Bereit für Hintergrundaktivität';

  @override
  String get settingsNotificationRequired =>
      'Erforderlich für zuverlässige Hintergrundaktivität.';

  @override
  String get settingsBatteryOptimization => 'Batterieoptimierung';

  @override
  String get settingsBatteryUnrestricted => 'Uneingeschränkt';

  @override
  String get settingsBatteryMayInterrupt =>
      'Dein Gerät kann lange Sitzungen unterbrechen.';

  @override
  String get settingsClosedAppReceive => 'Empfang bei geschlossener App';

  @override
  String get settingsClosedAppReady =>
      'Bereit für Nudges, wenn die App nicht geöffnet ist.';

  @override
  String get settingsClosedAppRequired =>
      'Erlaube Benachrichtigungen und uneingeschränkte Hintergrundaktivität.';

  @override
  String get settingsSectionLegal => 'Rechtliches';

  @override
  String get settingsTerms => 'Allgemeine Geschäftsbedingungen';

  @override
  String get settingsPrivacy => 'Datenschutzrichtlinie';

  @override
  String get settingsSectionSubscription => 'Abo';

  @override
  String get settingsDuoPro => 'Duo Pro';

  @override
  String get settingsViewPlans => 'Tarife ansehen';

  @override
  String settingsTrialDaysLeft(int count) {
    return 'Noch $count Tage in der Testphase';
  }

  @override
  String get settingsTrialOneDayLeft => 'Noch 1 Tag in der Testphase';

  @override
  String get settingsTrialLessThanADay =>
      'Weniger als ein Tag in der Testphase';

  @override
  String get settingsFreePlanSubtitle =>
      'Gratisplan — Live-Sprache braucht Duo Pro';

  @override
  String get settingsDuoProActiveSubtitle => 'Du nutzt Duo Pro';

  @override
  String get settingsManageSubscription => 'Abo verwalten';

  @override
  String get settingsSectionSupport => 'Support';

  @override
  String get settingsSendFeedback => 'Feedback senden';

  @override
  String get settingsDebugLogs => 'Debug-Protokolle';

  @override
  String get settingsSectionAccount => 'Konto';

  @override
  String get settingsSignedInWithGoogle => 'Mit Google angemeldet';

  @override
  String get settingsGoogleAccount => 'Google-Konto';

  @override
  String get settingsLogOut => 'Abmelden';

  @override
  String get settingsLogOutTitle => 'Abmelden?';

  @override
  String get settingsLogOutMessage =>
      'Du musst dich erneut mit Google anmelden, um Duo zu nutzen.';

  @override
  String get settingsDeleteAccount => 'Konto löschen';

  @override
  String get settingsDeleteAccountTitle => 'Konto dauerhaft löschen?';

  @override
  String get settingsDeleteAccountMessage =>
      'Dein Duo-Profil, Geräteinformationen und Einstellungen werden gelöscht. Das kann nicht rückgängig gemacht werden.';

  @override
  String get settingsDeleteAccountFailed =>
      'Das Konto konnte nicht gelöscht werden. Melde dich erneut mit Google an und versuche es noch einmal.';

  @override
  String get settingsCancel => 'Abbrechen';

  @override
  String get settingsEditProfile => 'Profil bearbeiten';

  @override
  String get settingsEditProfileSubtitle =>
      'So sehen dich Freunde in deinen Gruppen.';

  @override
  String get settingsDisplayName => 'Anzeigename';

  @override
  String get settingsAvatarSection => 'AVATAR';

  @override
  String get settingsAvatar => 'Avatar';

  @override
  String get settingsPhoto => 'Foto';

  @override
  String get settingsYourPhoto => 'Dein hochgeladenes Foto';

  @override
  String get settingsNoPhoto => 'Noch kein Foto hochgeladen';

  @override
  String get settingsChangePhoto => 'Foto ändern';

  @override
  String get settingsUploadPhoto => 'Foto hochladen';

  @override
  String get settingsSaveProfile => 'Profil speichern';

  @override
  String get settingsSaving => 'Speichern…';

  @override
  String get settingsDone => 'Fertig';

  @override
  String get settingsClose => 'Schließen';

  @override
  String get settingsProfileUpdated => 'Profil aktualisiert';

  @override
  String get settingsWelcomeDuoPro => 'Willkommen bei Duo Pro!';

  @override
  String get settingsPaywallFailed =>
      'Abo-Optionen konnten nicht geöffnet werden.';

  @override
  String get settingsMicGranted => 'Mikrofonberechtigung erteilt.';

  @override
  String get settingsMicDenied => 'Mikrofonberechtigung wurde verweigert.';

  @override
  String get settingsNotificationGranted =>
      'Benachrichtigungsberechtigung erteilt.';

  @override
  String get settingsNotificationDenied =>
      'Benachrichtigungsberechtigung wurde verweigert.';

  @override
  String get settingsBatteryRequestSent =>
      'Anfrage zur Batterieoptimierung gesendet. Prüfe die Geräteeinstellungen.';

  @override
  String get settingsClosedAppChecked =>
      'Empfang bei geschlossener App geprüft.';

  @override
  String get settingsBeta => 'BETA';

  @override
  String get settingsTestingUnlocked => 'Testbereich freigeschaltet';

  @override
  String get settingsTestingSection => 'Tests';

  @override
  String get settingsTestingHomeTitle => 'Startbildschirm';

  @override
  String get settingsTestingHomeSubtitle =>
      'Temporäre Looks zur Bewertung der Hintergründe. Das Layout bleibt gleich.';

  @override
  String get accentCoral => 'Koralle';

  @override
  String get accentLime => 'Limette';

  @override
  String get accentSky => 'Himmel';

  @override
  String get accentViolet => 'Violett';

  @override
  String get accentAmber => 'Bernstein';

  @override
  String get accentPink => 'Pink';

  @override
  String get accentTeal => 'Petrol';

  @override
  String get accentIndigo => 'Indigo';

  @override
  String get accentOrange => 'Orange';

  @override
  String get accentMint => 'Minze';

  @override
  String get accentYellow => 'Gelb';

  @override
  String get accentCyan => 'Cyan';

  @override
  String get homeJoinGroup => '+ gruppe\nbeitreten';

  @override
  String get homeCreateGroup => '+ neue\ngruppe';

  @override
  String get homeJoinQuestion => 'Beitreten?';

  @override
  String get homeNudgeTheGroup => 'Gruppe anstupsen';

  @override
  String get homeSendNudge => 'Nudge senden';

  @override
  String get homeSettings => 'Einstellungen';

  @override
  String get homeSettingsSetup => 'Einstellungen / Einrichtung';

  @override
  String get homeTalk => 'Sprechen';

  @override
  String get homeTapToTalk => 'Tippen zum Sprechen';

  @override
  String get homeTapToStopTalking => 'Tippen zum Stoppen';

  @override
  String get homeStatusUnavailable =>
      'Verfügbar, sobald ein anderes Mitglied beitritt';

  @override
  String get homeStatusGoAway => 'Tippen, um abwesend zu sein';

  @override
  String get homeStatusGoOnline =>
      'Geh online, wenn jemand schon live ist, oder sende einen Nudge, um gemeinsam zu starten';

  @override
  String get homeInviteFriends => 'Freunde einladen';

  @override
  String get homeInviteFriendsSubtitle =>
      'Teile diesen Link. Dein Freund öffnet Duo und tritt dieser Gruppe automatisch bei.';

  @override
  String get homeShareInviteLink => 'Einladungslink teilen';

  @override
  String get homeInviteLinkCopied => 'Einladungslink kopiert';

  @override
  String get homeFallbackPinCopied => 'Ersatz-PIN kopiert';

  @override
  String homeCopyPin(String code) {
    return 'PIN $code kopieren';
  }

  @override
  String homeSelectGroup(String name) {
    return 'Gruppe $name auswählen';
  }

  @override
  String get homeSetup => 'Einrichtung';

  @override
  String get homeSetupReady =>
      'Bereit für Sprache im Vordergrund und bei geschlossener App';

  @override
  String get homeSetupNeedGroup => 'Erstelle eine Gruppe oder tritt einer bei.';

  @override
  String get homeSetupNeedMic =>
      'Die Mikrofonberechtigung wurde nicht bestätigt.';

  @override
  String get homeSetupNeedNotifications =>
      'Benachrichtigungen sind für Nudges bei geschlossener App erforderlich.';

  @override
  String get homeSetupNeedPush =>
      'Die Push-Registrierung ist nicht bereit. Öffne die App erneut, während du online bist.';

  @override
  String get homeSetupNeedBattery =>
      'Die Batterieoptimierung kann den Hintergrundmodus unterbrechen.';

  @override
  String get noGroupsTitle => 'Lade mindestens einen Freund ein, um loszulegen';

  @override
  String get noGroupsSubtitle =>
      'füge deine besties hinzu, mit denen du jeden tag sprichst 🫶';

  @override
  String get noGroupsCreate => 'Gruppe erstellen';

  @override
  String get noGroupsShareInvite => 'Einladung teilen';

  @override
  String get noGroupsInviteClosedOnes => 'Deine Liebsten einladen';

  @override
  String get noGroupsHavePin =>
      'Hast du schon eine Gruppe? Nutze die PIN eines Freundes.';

  @override
  String get noGroupsJoinPin => 'Mit PIN beitreten';

  @override
  String get noGroupsNeedGroupFirst =>
      'Tritt zuerst einer Gruppe bei oder erstelle eine';

  @override
  String get inviteSheetTitle => 'Deine Liebsten einladen';

  @override
  String get inviteSheetGroupNameLabel => 'Gruppe benennen';

  @override
  String get inviteSheetGroupNameHint => 'z. B. Familie, Freunde…';

  @override
  String get inviteSheetContactsHeader => 'Wen einladen?';

  @override
  String get inviteSheetSearchHint => 'Kontakte suchen';

  @override
  String get inviteSheetNoContacts => 'Keine Kontakte gefunden';

  @override
  String get inviteSheetPermissionDenied =>
      'Kontakte erlauben, um zu sehen, wen du einladen kannst';

  @override
  String get inviteSheetPermissionButton => 'Zugriff erlauben';

  @override
  String get inviteSheetSendButton => 'Gruppe erstellen & Einladung senden';

  @override
  String get inviteSheetCreating => 'Gruppe wird erstellt…';

  @override
  String get inviteSheetGroupNameRequired =>
      'Gib einen Gruppennamen ein, um fortzufahren';

  @override
  String get createGroupTitle => 'gruppe erstellen';

  @override
  String get createGroupSubtitle =>
      'benenne die gruppe, die du starten möchtest';

  @override
  String get createGroupHint => 'Gruppenname';

  @override
  String get joinGroupTitle => 'per pin beitreten';

  @override
  String get joinGroupSubtitle => 'frage deinen freund nach der pin';

  @override
  String get joinGroupHint => 'Einladungs-PIN';

  @override
  String get backTooltip => 'Zurück';

  @override
  String get subManageTitle => 'Abo verwalten';

  @override
  String get subBetaNote => 'Duo Pro befindet sich derzeit in der Beta.';

  @override
  String get subManageInStore => 'Im Store verwalten';

  @override
  String get subManageInStoreSubtitle =>
      'Upgrade, kündigen oder wiederherstellen über App Store / Play';

  @override
  String get subContactTeam => 'Team Duo kontaktieren';

  @override
  String get subContactTeamSubtitle => 'Abrechnungsfragen und Support';

  @override
  String get subBetaFooter =>
      'In der Beta können Antwortzeiten variieren. Für Store-Erstattungen nutze Im Store verwalten, wenn verfügbar.';

  @override
  String get subContactBody =>
      'Schreib uns zu Abrechnung, Zugang oder Feedback:';

  @override
  String get subEmailCopied => 'E-Mail-Adresse in die Zwischenablage kopiert.';

  @override
  String get subClose => 'Schließen';

  @override
  String get subCustomerCenterFailed =>
      'Die Abo-Verwaltung konnte nicht geöffnet werden.';

  @override
  String get trialExpiredTitle => 'Deine Testphase ist beendet';

  @override
  String get trialExpiredBody =>
      'Bleib mit deinen Freunden in Verbindung — weiter mit Duo Pro.';

  @override
  String get trialExpiredGetPro => 'Pro holen';

  @override
  String get crashTitle => 'Die App ist auf ein Problem gestoßen';

  @override
  String get crashBody =>
      'Bitte sende einen Bericht, damit wir nachschauen können, was passiert ist. Das umfasst aktuelle Geräteprotokolle.';

  @override
  String get crashSendReport => 'Bericht senden';

  @override
  String get crashTryAgain => 'Erneut versuchen';

  @override
  String get crashSendFailed =>
      'Der Bericht konnte nicht gesendet werden. Prüfe deine Verbindung und versuche es erneut.';

  @override
  String get startupSetupFailed =>
      'Wir konnten dein Konto nicht fertig einrichten.';

  @override
  String get startupTryAgain => 'Erneut versuchen';

  @override
  String get homeMicOnMute => 'Mikro an — tippen zum Stummschalten';

  @override
  String homeConnectedToOtherGroup(String name) {
    return 'verbunden mit $name • tippen zum Anstupsen';
  }

  @override
  String get homeSomeoneLive => 'Jemand ist live — tippe auf Beitreten?';

  @override
  String get homeLiveVoiceLocked =>
      'Live-Sprache braucht Duo Pro — Nudges und Chat bleiben frei';

  @override
  String get homeInviteFriendVoice =>
      'lade einen freund ein, um sprache zu aktivieren';

  @override
  String get homeSendNudgeTogether =>
      'sende einen nudge, um gemeinsam online zu gehen';

  @override
  String get chatPresetJoin15Min => 'Ich komme in 15 Min';

  @override
  String get chatPresetWhereEveryone => 'Wo ist eigentlich jeder?';

  @override
  String get chatPresetOnMyWay => 'Bin unterwegs';

  @override
  String get chatPresetGiveMe5Min => 'Gib mir 5 Min';

  @override
  String get chatMoreEmojis => 'Mehr Emojis';

  @override
  String get chatWriteCustomMessage => 'Eigene Nachricht schreiben';

  @override
  String get chatMessageHint => 'Nachricht an die Gruppe…';

  @override
  String get feedbackSubtitle =>
      'Beschreibe, was schiefgelaufen ist. Aktuelle Geräteprotokolle werden angehängt.';

  @override
  String get feedbackHint => 'Was ist passiert? (optional)';

  @override
  String get feedbackThanks => 'Danke, dein Bericht wurde gesendet';

  @override
  String get feedbackSendFailed =>
      'Dein Bericht konnte nicht gesendet werden. Prüfe deine Verbindung und versuche es erneut.';

  @override
  String get debugLogsReading => 'Heutige Protokolldatei wird gelesen…';

  @override
  String get debugLogsEmpty =>
      'Heute wurde noch keine Protokolldatei erstellt.';

  @override
  String debugLogsTodayFile(String size, String time) {
    return 'Heutige Datei · $size · zuletzt aktualisiert $time';
  }

  @override
  String get debugLogsShareTitle => 'Protokolldatei teilen';

  @override
  String get debugLogsShareSubtitle =>
      'Öffnet das System-Teilen-Blatt mit der heutigen .txt-Datei';

  @override
  String get debugLogsCopyTitle => 'In Zwischenablage kopieren';

  @override
  String get debugLogsCopySubtitle =>
      'Kopiert den vollständigen Text der heutigen Protokolldatei';

  @override
  String get debugLogsNoFile => 'Noch keine Protokolldatei.';

  @override
  String get debugLogsCopied => 'In Zwischenablage kopiert';

  @override
  String get debugLogsShareSubject => 'Duo-Debug-Protokolle';

  @override
  String get legalLastUpdated => 'Zuletzt aktualisiert: 12. Juli 2026';

  @override
  String get legalTerms1Title => '1. Annahme der Bedingungen';

  @override
  String get legalTerms1Body =>
      'Durch das Herunterladen, den Zugriff auf oder die Nutzung von Duo stimmst du diesen Allgemeinen Geschäftsbedingungen zu. Wenn du nicht zustimmst, nutze die App nicht.';

  @override
  String get legalTerms2Title => '2. Der Dienst';

  @override
  String get legalTerms2Body =>
      'Duo ermöglicht es, private Gruppen zu erstellen oder beizutreten und Live-Sprachaudio auszutauschen. Verfügbarkeit, Audioqualität und Hintergrundzustellung können von Netzwerkzugang, Geräteeinstellungen, Berechtigungen und Drittanbieterdiensten abhängen. Der Dienst wird nach Verfügbarkeit bereitgestellt.';

  @override
  String get legalTerms3Title => '3. Deine Verantwortlichkeiten';

  @override
  String get legalTerms3Body =>
      'Du bist für die Aktivität verantwortlich, die mit deiner Installation verbunden ist, und dafür, Einladungscodes privat zu halten. Du musst das Recht haben, jeden Namen, jedes Profilbild, jede Stimme oder andere Inhalte zu teilen, die du bereitstellst. Nutze Duo nicht, um andere zu belästigen, ihre Privatsphäre zu verletzen, jemanden vorzutäuschen, Gesetze zu brechen oder den Dienst zu stören.';

  @override
  String get legalTerms4Title => '4. Sprache und Berechtigungen';

  @override
  String get legalTerms4Body =>
      'Duo benötigt Mikrofonzugriff, um Live-Sprache zu übertragen. Du steuerst, wann die Übertragung beginnt, über die Sprechsteuerung in der App. Benachrichtigungs- und Hintergrundberechtigungen können angefordert werden, um Verfügbarkeit und Audiofunktionen zu unterstützen. Du kannst Berechtigungen in deinen Geräteeinstellungen ändern.';

  @override
  String get legalTerms5Title => '5. Drittanbieterdienste';

  @override
  String get legalTerms5Body =>
      'Duo verlässt sich auf Dienstleister für Authentifizierung, Datenspeicherung, Medienübermittlung, Profilbild-Hosting und Infrastruktur. Deren Dienste können durch separate Bedingungen geregelt sein und können gelegentlich nicht verfügbar sein.';

  @override
  String get legalTerms6Title => '6. Sperrung und Beendigung';

  @override
  String get legalTerms6Body =>
      'Wir können den Zugang einschränken oder beenden, wenn dies vernünftigerweise erforderlich ist, um Nutzer zu schützen, Gesetze einzuhalten, Missbrauch zu verhindern oder den Dienst aufrechtzuerhalten. Du kannst Duo jederzeit nicht mehr nutzen und die App von deinem Gerät entfernen.';

  @override
  String get legalTerms7Title => '7. Haftungsausschlüsse und Haftung';

  @override
  String get legalTerms7Body =>
      'Soweit gesetzlich zulässig, wird Duo ohne Garantien für unterbrechungsfreien, fehlerfreien oder sicheren Betrieb bereitgestellt. Wir haften nicht für indirekte, beiläufige, besondere, Folgeschäden oder Strafschäden, die aus der Nutzung der App entstehen. Nichts in diesen Bedingungen schränkt Rechte oder Haftung ein, die gesetzlich nicht eingeschränkt werden können.';

  @override
  String get legalTerms8Title => '8. Änderungen';

  @override
  String get legalTerms8Body =>
      'Wir können diese Bedingungen aktualisieren, wenn sich der Dienst ändert. Das Aktualisierungsdatum erscheint oben auf dieser Seite. Die fortgesetzte Nutzung nach einer Aktualisierung bedeutet, dass du die überarbeiteten Bedingungen akzeptierst.';

  @override
  String get legalTerms9Title => '9. Kontakt';

  @override
  String get legalTerms9Body =>
      'Fragen zu diesen Bedingungen können über den Supportkanal gesendet werden, der in der Duo-App-Store-Listung angegeben ist.';

  @override
  String get legalPrivacy1Title => '1. Überblick';

  @override
  String get legalPrivacy1Body =>
      'Diese Datenschutzrichtlinie erklärt, was Duo erfasst, wofür es verwendet wird und welche Optionen dir bei der Nutzung der App zur Verfügung stehen.';

  @override
  String get legalPrivacy2Title => '2. Informationen, die wir erfassen';

  @override
  String get legalPrivacy2Body =>
      'Wir erfassen deine Google-authentifizierte Kontokennung und E-Mail-Adresse, Anzeigenamen, optionales Profilbild, Gruppenmitgliedschaft und Einladungsinformationen, App-Einstellungen, Geräte- und App-Versionskennungen, Berechtigungsstatus, Verfügbarkeitsstatus und grundlegende Servicediagnosen. Wenn du Live-Sprache nutzt, wird Mikrofonaudio an die anderen aktiven Mitglieder deiner Gruppe übertragen.';

  @override
  String get legalPrivacy3Title => '3. Wie Informationen verwendet werden';

  @override
  String get legalPrivacy3Body =>
      'Informationen werden verwendet, um deine App-Identität zu erstellen, dein Profil Gruppenmitgliedern anzuzeigen, Gruppen und Einladungen zu verwalten, Live-Sprachsitzungen zu verbinden, Einstellungen zu speichern, Verfügbarkeit aufrechtzuerhalten, Zuverlässigkeit zu diagnostizieren, Missbrauch zu verhindern und Duo zu betreiben und zu verbessern.';

  @override
  String get legalPrivacy4Title => '4. Audio';

  @override
  String get legalPrivacy4Body =>
      'Live-Sprache wird übertragen, damit Gruppenmitglieder dich hören können. Duo ist nicht dafür ausgelegt, den Inhalt deiner Live-Gespräche aufzuzeichnen oder zu speichern. Dienstleister können Netzwerk- und Verbindungsmetadaten verarbeiten, die zur Übermittlung des Audios erforderlich sind.';

  @override
  String get legalPrivacy5Title => '5. Dienstleister';

  @override
  String get legalPrivacy5Body =>
      'Duo nutzt Anbieter wie Google Firebase für Authentifizierung und App-Daten, Cloudinary für Profilbild-Hosting, LiveKit für Echtzeit-Audio und Hosting-Anbieter für Anwendungsdienste. Diese Anbieter verarbeiten Informationen in unserem Auftrag gemäß ihren eigenen Datenschutz- und Sicherheitspraktiken.';

  @override
  String get legalPrivacy6Title => '6. Weitergabe';

  @override
  String get legalPrivacy6Body =>
      'Dein Anzeigename, Profilbild, Verfügbarkeit und Live-Sprache werden mit Mitgliedern der Gruppen geteilt, denen du beitrittst. Wir können Informationen auch an Dienstleister weitergeben, um Gesetze oder gültige rechtliche Verfahren einzuhalten, Nutzer und den Dienst zu schützen oder im Rahmen einer Unternehmensübertragung. Wir verkaufen keine personenbezogenen Daten.';

  @override
  String get legalPrivacy7Title => '7. Aufbewahrung und Sicherheit';

  @override
  String get legalPrivacy7Body =>
      'Wir bewahren Informationen nur so lange auf, wie es vernünftigerweise erforderlich ist, um den Dienst bereitzustellen, gesetzliche Verpflichtungen zu erfüllen, Streitigkeiten beizulegen und die App zu schützen. Wir verwenden angemessene Schutzmaßnahmen, aber kein vernetzter Dienst kann absolute Sicherheit garantieren.';

  @override
  String get legalPrivacy8Title => '8. Deine Optionen';

  @override
  String get legalPrivacy8Body =>
      'Du kannst deinen Anzeigenamen, dein Profilbild, App-Einstellungen und Geräteberechtigungen ändern. Du kannst Gruppen verlassen, dich abmelden oder dein Konto in den Einstellungen löschen. Anfragen zum Zugriff auf Informationen können über den Supportkanal gestellt werden, der in der Duo-App-Store-Listung angegeben ist. Wir benötigen möglicherweise Informationen, die deine App-Installation identifizieren, um eine Anfrage abzuschließen.';

  @override
  String get legalPrivacy9Title => '9. Kinder';

  @override
  String get legalPrivacy9Body =>
      'Duo richtet sich nicht an Kinder unter 13 Jahren oder dem nach lokalem Recht erforderlichen Mindestalter. Wir erfassen wissentlich keine personenbezogenen Daten von Kindern unter diesem Alter.';

  @override
  String get legalPrivacy10Title => '10. Internationale Verarbeitung';

  @override
  String get legalPrivacy10Body =>
      'Informationen können in anderen Ländern als deinem verarbeitet werden. Wo erforderlich, werden angemessene Schutzmaßnahmen für internationale Übermittlungen verwendet.';

  @override
  String get legalPrivacy11Title => '11. Änderungen und Kontakt';

  @override
  String get legalPrivacy11Body =>
      'Wir können diese Richtlinie aktualisieren, wenn sich Duo ändert. Das Aktualisierungsdatum erscheint oben. Datenschutzfragen und -anfragen können über den Supportkanal gesendet werden, der in der Duo-App-Store-Listung angegeben ist.';
}
