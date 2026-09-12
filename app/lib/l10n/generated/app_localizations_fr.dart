// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get welcomeTitle => 'Bienvenue sur Duo';

  @override
  String get welcomeSubtitle =>
      'Connectez-vous ou créez un compte avant de configurer votre profil.';

  @override
  String get continueWithGoogle => 'Continuer avec Google';

  @override
  String get signingIn => 'Connexion…';

  @override
  String get termsFooter =>
      'En continuant, vous acceptez nos conditions et politiques.';

  @override
  String get googleSignInCancelled =>
      'La connexion Google a été annulée. Veuillez réessayer.';

  @override
  String get googleSignInFailed =>
      'La connexion Google n\'a pas pu aboutir. Vérifiez votre connexion internet et réessayez.';

  @override
  String get languageMenuTooltip => 'Langue';

  @override
  String get chooseAvatarTitle => 'choisissez un avatar';

  @override
  String get chooseAvatarSubtitle =>
      'Vous pourrez ajouter une photo personnalisée plus tard dans Réglages.';

  @override
  String get displayNameHint => 'votre nom';

  @override
  String get displayNameSubtitle => 'c\'est ainsi que vos amis vous verront';

  @override
  String get permissionMicTitle => 'micro';

  @override
  String get permissionMicSubtitle =>
      'pour que vos amis vous entendent\nquand vous parlez...';

  @override
  String get permissionNotificationsTitle => 'notifications';

  @override
  String get permissionNotificationsSubtitle =>
      'savoir quand vos amis vous\nparlent';

  @override
  String get permissionBackgroundTitle => 'activité en arrière-plan';

  @override
  String get permissionBackgroundSubtitle =>
      'recevoir des nudges quand duo\nn\'est pas ouvert';

  @override
  String get permissionFootnote =>
      '*nous en avons besoin pour que duo fonctionne';

  @override
  String get permissionSetupFailed =>
      'La configuration n\'a pas pu aboutir. Veuillez réessayer.';

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get settingsLanguageSection => 'Langue';

  @override
  String get settingsLanguageTitle => 'Langue de l\'application';

  @override
  String get settingsLanguageSubtitle =>
      'Vous pouvez revenir à l\'anglais à tout moment.';

  @override
  String get settingsSectionGroup => 'Groupe';

  @override
  String get settingsManageGroup => 'Gérer le groupe';

  @override
  String get settingsManageGroupSubtitle => 'Groupes que vous avez créés';

  @override
  String get settingsSectionPreferences => 'Préférences';

  @override
  String get settingsAccentColorTitle => 'Couleur d\'accent';

  @override
  String get settingsAccentColorSubtitle =>
      'Choisissez la couleur utilisée dans Duo.';

  @override
  String get settingsHapticsTitle =>
      'Retours haptiques des messages vocaux entrants';

  @override
  String settingsHapticsSubtitle(String detail) {
    return 'Vibrations continues — $detail';
  }

  @override
  String get hapticsLight => 'Léger';

  @override
  String get hapticsPulse => 'Impulsion';

  @override
  String get hapticsWild => 'Intense';

  @override
  String get hapticsLightDetail => 'Deux vibrations au début et deux à la fin.';

  @override
  String get hapticsPulseDetail =>
      'Une double impulsion — deux paires rapides.';

  @override
  String get hapticsWildDetail => 'Vibration continue pendant tout le nudge.';

  @override
  String get settingsHomeBackgroundTitle => 'Fond d\'écran d\'accueil';

  @override
  String get settingsHomeBackgroundSubtitle =>
      'Choisissez le fond de l\'écran d\'accueil.';

  @override
  String get settingsHomeBackgroundDefault => 'Par défaut';

  @override
  String get settingsHomeBackgroundIllustrated => 'Illustré';

  @override
  String get settingsSaveColor => 'Enregistrer la couleur';

  @override
  String get settingsSaved => 'Réglages enregistrés';

  @override
  String settingsAppVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsSectionBackground => 'Fiabilité en arrière-plan';

  @override
  String get settingsMicPermission => 'Permission du microphone';

  @override
  String get settingsMicReady => 'Prêt';

  @override
  String get settingsMicRequired => 'Requis avant de pouvoir parler.';

  @override
  String get settingsNotificationPermission => 'Permission des notifications';

  @override
  String get settingsNotificationReady =>
      'Prêt pour l\'activité en arrière-plan';

  @override
  String get settingsNotificationRequired =>
      'Requis pour une activité en arrière-plan fiable.';

  @override
  String get settingsBatteryOptimization => 'Optimisation de la batterie';

  @override
  String get settingsBatteryUnrestricted => 'Sans restriction';

  @override
  String get settingsBatteryMayInterrupt =>
      'Votre appareil peut interrompre les longues sessions.';

  @override
  String get settingsClosedAppReceive => 'Réception appli fermée';

  @override
  String get settingsClosedAppReady =>
      'Prêt pour les nudges quand l\'app n\'est pas ouverte.';

  @override
  String get settingsClosedAppRequired =>
      'Autorisez les notifications et l\'activité en arrière-plan.';

  @override
  String get settingsSectionLegal => 'Mentions légales';

  @override
  String get settingsTerms => 'Conditions d\'utilisation';

  @override
  String get settingsPrivacy => 'Politique de confidentialité';

  @override
  String get settingsSectionSubscription => 'Abonnement';

  @override
  String get settingsDuoPro => 'Duo Pro';

  @override
  String get settingsViewPlans => 'Voir les offres';

  @override
  String settingsTrialDaysLeft(int count) {
    return '⌛ $count jours restants';
  }

  @override
  String get settingsTrialOneDayLeft => '⌛ 1 jour restant';

  @override
  String get settingsTrialLessThanADay => '⌛ Moins d\'un jour';

  @override
  String get settingsFreePlanSubtitle =>
      'Offre gratuite — la voix en direct nécessite Duo Pro';

  @override
  String get settingsDuoProActiveSubtitle => 'Vous avez Duo Pro';

  @override
  String get settingsManageSubscription => 'Gérer l\'abonnement';

  @override
  String get settingsSectionSupport => 'Assistance';

  @override
  String get settingsSendFeedback => 'Envoyer un avis';

  @override
  String get settingsDebugLogs => 'Journaux de débogage';

  @override
  String get settingsSectionAccount => 'Compte';

  @override
  String get settingsSignedInWithGoogle => 'Connecté avec Google';

  @override
  String get settingsGoogleAccount => 'Compte Google';

  @override
  String get settingsLogOut => 'Se déconnecter';

  @override
  String get settingsLogOutTitle => 'Se déconnecter ?';

  @override
  String get settingsLogOutMessage =>
      'Vous devrez vous reconnecter avec Google pour utiliser Duo.';

  @override
  String get settingsDeleteAccount => 'Supprimer le compte';

  @override
  String get settingsDeleteAccountTitle =>
      'Supprimer le compte définitivement ?';

  @override
  String get settingsDeleteAccountMessage =>
      'Votre profil Duo, les informations de l\'appareil et vos préférences seront supprimés. Cette action est irréversible.';

  @override
  String get settingsDeleteAccountFailed =>
      'La suppression du compte n\'a pas abouti. Reconnectez-vous avec Google et réessayez.';

  @override
  String get settingsCancel => 'Annuler';

  @override
  String get settingsEditProfile => 'Modifier le profil';

  @override
  String get settingsEditProfileSubtitle =>
      'C\'est ainsi que vos amis vous voient dans vos groupes.';

  @override
  String get settingsDisplayName => 'Nom affiché';

  @override
  String get settingsAvatarSection => 'AVATAR';

  @override
  String get settingsAvatar => 'Avatar';

  @override
  String get settingsPhoto => 'Photo';

  @override
  String get settingsYourPhoto => 'Votre photo';

  @override
  String get settingsNoPhoto => 'Aucune photo pour le moment';

  @override
  String get settingsChangePhoto => 'Changer de photo';

  @override
  String get settingsUploadPhoto => 'Ajouter une photo';

  @override
  String get settingsSaveProfile => 'Enregistrer le profil';

  @override
  String get settingsSaving => 'Enregistrement…';

  @override
  String get settingsDone => 'Terminé';

  @override
  String get settingsClose => 'Fermer';

  @override
  String get settingsProfileUpdated => 'Profil mis à jour';

  @override
  String get settingsWelcomeDuoPro => 'Bienvenue sur Duo Pro !';

  @override
  String get settingsPaywallFailed =>
      'Impossible d\'ouvrir les options d\'abonnement.';

  @override
  String get settingsMicGranted => 'Permission du microphone accordée.';

  @override
  String get settingsMicDenied => 'Permission du microphone refusée.';

  @override
  String get settingsNotificationGranted =>
      'Permission des notifications accordée.';

  @override
  String get settingsNotificationDenied =>
      'Permission des notifications refusée.';

  @override
  String get settingsBatteryRequestSent =>
      'Demande d\'optimisation de la batterie envoyée. Vérifiez les réglages de l\'appareil.';

  @override
  String get settingsClosedAppChecked => 'Réception appli fermée vérifiée.';

  @override
  String get settingsBeta => 'BÊTA';

  @override
  String get settingsTestingUnlocked => 'Section de test déverrouillée';

  @override
  String get settingsTestingSection => 'Tests';

  @override
  String get settingsTestingHomeTitle => 'Écran d\'accueil';

  @override
  String get settingsTestingHomeSubtitle =>
      'Looks temporaires pour évaluer les fonds. La mise en page reste la même.';

  @override
  String get accentCoral => 'Corail';

  @override
  String get accentLime => 'Citron vert';

  @override
  String get accentSky => 'Ciel';

  @override
  String get accentViolet => 'Violet';

  @override
  String get accentAmber => 'Ambre';

  @override
  String get accentPink => 'Rose';

  @override
  String get accentTeal => 'Sarcelle';

  @override
  String get accentIndigo => 'Indigo';

  @override
  String get accentOrange => 'Orange';

  @override
  String get accentMint => 'Menthe';

  @override
  String get accentYellow => 'Jaune';

  @override
  String get accentCyan => 'Cyan';

  @override
  String get homeJoinGroup => '+ rejoindre\nun groupe';

  @override
  String get homeCreateGroup => '+ créer\nun groupe';

  @override
  String get homeJoinQuestion => 'Rejoindre ?';

  @override
  String get homeNudgeTheGroup => 'Nudge le groupe';

  @override
  String get homeSendNudge => 'Envoyer un nudge';

  @override
  String get homeSettings => 'Réglages';

  @override
  String get homeSettingsSetup => 'Réglages / Configuration';

  @override
  String get homeTalk => 'Parler';

  @override
  String get homeTapToTalk => 'Appuyer pour parler';

  @override
  String get homeTapToStopTalking => 'Appuyer pour arrêter';

  @override
  String get homeStatusUnavailable =>
      'Disponible quand un autre membre rejoint';

  @override
  String get homeStatusGoAway => 'Appuyer pour passer absent';

  @override
  String get homeStatusGoOnline =>
      'Passez en ligne quand quelqu\'un est déjà en direct, ou envoyez un nudge pour y aller ensemble';

  @override
  String get homeInviteFriends => 'Inviter des amis';

  @override
  String get homeInviteFriendsSubtitle =>
      'Partagez ce lien. Votre ami ouvrira Duo et rejoindra ce groupe automatiquement.';

  @override
  String get homeShareInviteLink => 'Partager le lien d\'invitation';

  @override
  String get homeInviteLinkCopied => 'Lien d\'invitation copié';

  @override
  String get homeFallbackPinCopied => 'PIN de secours copié';

  @override
  String homeCopyPin(String code) {
    return 'Copier le PIN $code';
  }

  @override
  String homeSelectGroup(String name) {
    return 'Sélectionner le groupe $name';
  }

  @override
  String get homeSetup => 'Configuration';

  @override
  String get homeSetupReady =>
      'Prêt pour la voix au premier plan et appli fermée';

  @override
  String get homeSetupNeedGroup => 'Créez ou rejoignez un groupe.';

  @override
  String get homeSetupNeedMic =>
      'La permission du microphone n\'a pas été confirmée.';

  @override
  String get homeSetupNeedNotifications =>
      'Les notifications sont requises pour les nudges appli fermée.';

  @override
  String get homeSetupNeedPush =>
      'L\'enregistrement push n\'est pas prêt. Rouvrez l\'app en étant en ligne.';

  @override
  String get homeSetupNeedBattery =>
      'L\'optimisation de la batterie peut interrompre le mode arrière-plan.';

  @override
  String get noGroupsTitle => 'Invitez au moins un ami pour commencer';

  @override
  String get noGroupsSubtitle =>
      'ajoute tes besties, celles avec qui tu parles tous les jours 🫶';

  @override
  String get noGroupsCreate => 'Créer un groupe';

  @override
  String get noGroupsShareInvite => 'Partager une invitation';

  @override
  String get noGroupsInviteClosedOnes => 'Inviter vos proches';

  @override
  String get noGroupsHavePin =>
      'Vous avez déjà un groupe ? Utilisez le PIN d\'un ami.';

  @override
  String get noGroupsJoinPin => 'Rejoindre avec un PIN';

  @override
  String get noGroupsNeedGroupFirst => 'Rejoignez ou créez d\'abord un groupe';

  @override
  String get inviteSheetTitle => 'Inviter vos proches';

  @override
  String get inviteSheetGroupNameLabel => 'Nommez votre groupe';

  @override
  String get inviteSheetGroupNameHint => 'ex. Famille, Amis…';

  @override
  String get inviteSheetContactsHeader => 'Sélectionner qui inviter';

  @override
  String get inviteSheetSearchHint => 'Rechercher des contacts';

  @override
  String get inviteSheetNoContacts => 'Aucun contact trouvé';

  @override
  String get inviteSheetPermissionDenied =>
      'Autorisez les contacts pour voir qui inviter';

  @override
  String get inviteSheetPermissionButton => 'Autoriser l\'accès aux contacts';

  @override
  String get inviteSheetSendButton =>
      'Créer le groupe et envoyer l\'invitation';

  @override
  String get inviteSheetCreating => 'Création du groupe…';

  @override
  String get inviteSheetGroupNameRequired =>
      'Entrez un nom de groupe pour continuer';

  @override
  String get createGroupTitle => 'créer un groupe';

  @override
  String get createGroupSubtitle => 'nommez le groupe que vous voulez lancer';

  @override
  String get createGroupHint => 'Nom du groupe';

  @override
  String get joinGroupTitle => 'rejoindre par pin';

  @override
  String get joinGroupSubtitle => 'demande le pin à ton ami';

  @override
  String get joinGroupHint => 'PIN d\'invitation';

  @override
  String get backTooltip => 'Retour';

  @override
  String get subManageTitle => 'Gérer l\'abonnement';

  @override
  String get subBetaNote => 'Duo Pro est actuellement en bêta.';

  @override
  String get subManageInStore => 'Gérer dans le store';

  @override
  String get subManageInStoreSubtitle =>
      'Mettre à niveau, annuler ou restaurer via l\'App Store / Play';

  @override
  String get subContactTeam => 'Contacter l\'équipe Duo';

  @override
  String get subContactTeamSubtitle => 'Questions de facturation et assistance';

  @override
  String get subBetaFooter =>
      'Pendant la bêta, les délais de réponse peuvent varier. Pour les remboursements, utilisez Gérer dans le store si disponible.';

  @override
  String get subContactBody =>
      'Écrivez-nous pour la facturation, l\'accès ou vos retours :';

  @override
  String get subEmailCopied => 'Adresse e-mail copiée dans le presse-papiers.';

  @override
  String get subClose => 'Fermer';

  @override
  String get subCustomerCenterFailed =>
      'Impossible d\'ouvrir la gestion de l\'abonnement.';

  @override
  String get trialExpiredTitle => 'Votre essai gratuit est terminé';

  @override
  String get trialExpiredBody =>
      'Continuez à parler avec vos amis grâce à Duo Pro.';

  @override
  String get trialExpiredGetPro => 'Passer à Pro';

  @override
  String get crashTitle => 'L\'application a rencontré un problème';

  @override
  String get crashBody =>
      'Envoyez un rapport pour que nous puissions voir ce qui s\'est passé. Cela inclut les journaux récents de cet appareil.';

  @override
  String get crashSendReport => 'Envoyer le rapport';

  @override
  String get crashTryAgain => 'Réessayer';

  @override
  String get crashSendFailed =>
      'Impossible d\'envoyer le rapport. Vérifiez votre connexion et réessayez.';

  @override
  String get startupSetupFailed =>
      'Nous n\'avons pas pu terminer la configuration de votre compte.';

  @override
  String get startupTryAgain => 'Réessayer';

  @override
  String get homeMicOnMute => 'Micro activé — appuyer pour couper';

  @override
  String homeConnectedToOtherGroup(String name) {
    return 'connecté à $name • appuyer pour un nudge';
  }

  @override
  String get homeSomeoneLive =>
      'Quelqu\'un est en direct — appuyer sur Rejoindre ?';

  @override
  String get homeLiveVoiceLocked =>
      'La voix en direct nécessite Duo Pro — les nudges et le chat restent gratuits';

  @override
  String get homeInviteFriendVoice => 'invite un ami pour activer la voix';

  @override
  String get homeSendNudgeTogether =>
      'envoie un nudge pour passer en ligne ensemble';

  @override
  String get chatPresetJoin15Min => 'Je rejoins dans 15 min';

  @override
  String get chatPresetWhereEveryone => 'Où est tout le monde ?';

  @override
  String get chatPresetOnMyWay => 'J\'arrive';

  @override
  String get chatPresetGiveMe5Min => 'Donne-moi 5 min';

  @override
  String get chatMoreEmojis => 'Plus d\'emojis';

  @override
  String get chatWriteCustomMessage => 'Écrire un message personnalisé';

  @override
  String get chatMessageHint => 'Message au groupe…';

  @override
  String get feedbackSubtitle =>
      'Décrivez ce qui s\'est mal passé. Les journaux récents de l\'appareil seront joints.';

  @override
  String get feedbackHint => 'Que s\'est-il passé ? (facultatif)';

  @override
  String get feedbackThanks => 'Merci, votre rapport a été envoyé';

  @override
  String get feedbackSendFailed =>
      'Impossible d\'envoyer votre rapport. Vérifiez votre connexion et réessayez.';

  @override
  String get debugLogsReading => 'Lecture du journal du jour…';

  @override
  String get debugLogsEmpty =>
      'Aucun journal n\'a encore été créé aujourd\'hui.';

  @override
  String debugLogsTodayFile(String size, String time) {
    return 'Fichier du jour · $size · dernière mise à jour $time';
  }

  @override
  String get debugLogsShareTitle => 'Partager le fichier journal';

  @override
  String get debugLogsShareSubtitle =>
      'Ouvre la feuille de partage système avec le fichier .txt du jour';

  @override
  String get debugLogsCopyTitle => 'Copier dans le presse-papiers';

  @override
  String get debugLogsCopySubtitle =>
      'Copie le texte complet du journal du jour';

  @override
  String get debugLogsNoFile => 'Aucun journal pour le moment.';

  @override
  String get debugLogsCopied => 'Copié dans le presse-papiers';

  @override
  String get debugLogsShareSubject => 'Journaux de débogage Duo';

  @override
  String get legalLastUpdated => 'Dernière mise à jour : 12 juillet 2026';

  @override
  String get legalTerms1Title => '1. Acceptation des conditions';

  @override
  String get legalTerms1Body =>
      'En téléchargeant, en accédant ou en utilisant Duo, vous acceptez ces Conditions générales. Si vous n\'êtes pas d\'accord, n\'utilisez pas l\'application.';

  @override
  String get legalTerms2Title => '2. Le service';

  @override
  String get legalTerms2Body =>
      'Duo permet de créer ou de rejoindre des groupes privés et d\'échanger de l\'audio vocal en direct. La disponibilité, la qualité audio et la livraison en arrière-plan peuvent dépendre de l\'accès réseau, des paramètres de l\'appareil, des autorisations et des services tiers. Le service est fourni selon disponibilité.';

  @override
  String get legalTerms3Title => '3. Vos responsabilités';

  @override
  String get legalTerms3Body =>
      'Vous êtes responsable de l\'activité associée à votre installation et de la confidentialité des codes d\'invitation. Vous devez avoir le droit de partager tout nom, photo de profil, voix ou autre contenu que vous fournissez. N\'utilisez pas Duo pour harceler autrui, violer leur vie privée, usurper une identité, enfreindre la loi ou perturber le service.';

  @override
  String get legalTerms4Title => '4. Voix et autorisations';

  @override
  String get legalTerms4Body =>
      'Duo nécessite l\'accès au microphone pour transmettre la voix en direct. Vous contrôlez le début de la transmission via le contrôle de conversation dans l\'application. Des autorisations de notification et d\'arrière-plan peuvent être demandées pour prendre en charge la disponibilité et les fonctionnalités audio. Vous pouvez modifier les autorisations dans les paramètres de votre appareil.';

  @override
  String get legalTerms5Title => '5. Services tiers';

  @override
  String get legalTerms5Body =>
      'Duo s\'appuie sur des prestataires pour l\'authentification, le stockage des données, la diffusion média, l\'hébergement des photos de profil et l\'infrastructure. Leurs services peuvent être régis par des conditions distinctes et peuvent parfois être indisponibles.';

  @override
  String get legalTerms6Title => '6. Suspension et résiliation';

  @override
  String get legalTerms6Body =>
      'Nous pouvons restreindre ou mettre fin à l\'accès lorsque cela est raisonnablement nécessaire pour protéger les utilisateurs, respecter la loi, prévenir les abus ou maintenir le service. Vous pouvez cesser d\'utiliser Duo à tout moment et supprimer l\'application de votre appareil.';

  @override
  String get legalTerms7Title => '7. Exclusions et responsabilité';

  @override
  String get legalTerms7Body =>
      'Dans la mesure permise par la loi, Duo est fourni sans garantie de fonctionnement ininterrompu, sans erreur ou sécurisé. Nous ne sommes pas responsables des dommages indirects, accessoires, spéciaux, consécutifs ou punitifs découlant de l\'utilisation de l\'application. Rien dans ces conditions ne limite les droits ou responsabilités qui ne peuvent légalement être limités.';

  @override
  String get legalTerms8Title => '8. Modifications';

  @override
  String get legalTerms8Body =>
      'Nous pouvons mettre à jour ces conditions au fil de l\'évolution du service. La date de mise à jour apparaîtra en haut de cette page. L\'utilisation continue après une mise à jour signifie que vous acceptez les conditions révisées.';

  @override
  String get legalTerms9Title => '9. Contact';

  @override
  String get legalTerms9Body =>
      'Les questions concernant ces conditions peuvent être envoyées via le canal de support indiqué sur la fiche Duo de l\'App Store.';

  @override
  String get legalPrivacy1Title => '1. Aperçu';

  @override
  String get legalPrivacy1Body =>
      'Cette Politique de confidentialité explique ce que Duo collecte, pourquoi ces données sont utilisées et les choix qui s\'offrent à vous lorsque vous utilisez l\'application.';

  @override
  String get legalPrivacy2Title => '2. Informations que nous collectons';

  @override
  String get legalPrivacy2Body =>
      'Nous collectons l\'identifiant de compte et l\'adresse e-mail authentifiés via Google, le nom affiché, la photo de profil facultative, les informations d\'appartenance aux groupes et d\'invitation, les paramètres de l\'application, les identifiants de l\'appareil et de la version, le statut des autorisations, l\'état de disponibilité et les diagnostics de base du service. Lorsque vous utilisez la voix en direct, l\'audio du microphone est transmis aux autres membres actifs de votre groupe.';

  @override
  String get legalPrivacy3Title => '3. Utilisation des informations';

  @override
  String get legalPrivacy3Body =>
      'Les informations sont utilisées pour créer votre identité dans l\'application, afficher votre profil aux membres du groupe, gérer les groupes et les invitations, connecter les sessions vocales en direct, mémoriser les préférences, maintenir la disponibilité, diagnostiquer la fiabilité, prévenir les abus et exploiter et améliorer Duo.';

  @override
  String get legalPrivacy4Title => '4. Audio';

  @override
  String get legalPrivacy4Body =>
      'La voix en direct est transmise pour que les membres du groupe puissent vous entendre. Duo n\'est pas conçu pour enregistrer ou stocker le contenu de vos conversations en direct. Les prestataires de services peuvent traiter les métadonnées réseau et de connexion nécessaires à la diffusion de l\'audio.';

  @override
  String get legalPrivacy5Title => '5. Prestataires de services';

  @override
  String get legalPrivacy5Body =>
      'Duo utilise des prestataires dont Google Firebase pour l\'authentification et les données de l\'application, Cloudinary pour l\'hébergement des photos de profil, LiveKit pour l\'audio en temps réel, et des hébergeurs pour les services applicatifs. Ces prestataires traitent les informations en notre nom selon leurs propres pratiques de confidentialité et de sécurité.';

  @override
  String get legalPrivacy6Title => '6. Partage';

  @override
  String get legalPrivacy6Body =>
      'Votre nom affiché, votre photo de profil, votre disponibilité et votre voix en direct sont partagés avec les membres des groupes que vous rejoignez. Nous pouvons également divulguer des informations aux prestataires de services, pour nous conformer à la loi ou à une procédure légale valide, pour protéger les utilisateurs et le service, ou dans le cadre d\'un transfert d\'activité. Nous ne vendons pas d\'informations personnelles.';

  @override
  String get legalPrivacy7Title => '7. Conservation et sécurité';

  @override
  String get legalPrivacy7Body =>
      'Nous conservons les informations uniquement aussi longtemps que raisonnablement nécessaire pour fournir le service, respecter les obligations légales, résoudre les litiges et protéger l\'application. Nous utilisons des mesures de protection raisonnables, mais aucun service en réseau ne peut garantir une sécurité absolue.';

  @override
  String get legalPrivacy8Title => '8. Vos choix';

  @override
  String get legalPrivacy8Body =>
      'Vous pouvez modifier votre nom affiché, votre photo de profil, vos préférences d\'application et les autorisations de votre appareil. Vous pouvez quitter des groupes, vous déconnecter ou supprimer votre compte depuis les Paramètres. Les demandes d\'accès aux informations peuvent être adressées via le canal de support indiqué sur la fiche Duo de l\'App Store. Nous pouvons avoir besoin d\'informations identifiant votre installation de l\'application pour traiter une demande.';

  @override
  String get legalPrivacy9Title => '9. Enfants';

  @override
  String get legalPrivacy9Body =>
      'Duo ne s\'adresse pas aux enfants de moins de 13 ans, ou à l\'âge minimum requis par la loi locale. Nous ne collectons pas sciemment d\'informations personnelles auprès d\'enfants en dessous de cet âge.';

  @override
  String get legalPrivacy10Title => '10. Traitement international';

  @override
  String get legalPrivacy10Body =>
      'Les informations peuvent être traitées dans des pays autres que le vôtre. Lorsque requis, des garanties appropriées sont utilisées pour les transferts internationaux.';

  @override
  String get legalPrivacy11Title => '11. Modifications et contact';

  @override
  String get legalPrivacy11Body =>
      'Nous pouvons mettre à jour cette politique au fil de l\'évolution de Duo. La date de mise à jour apparaîtra ci-dessus. Les questions et demandes relatives à la confidentialité peuvent être envoyées via le canal de support indiqué sur la fiche Duo de l\'App Store.';
}
