// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get welcomeTitle => 'Benvenuto su Duo';

  @override
  String get welcomeSubtitle =>
      'Accedi o crea il tuo account prima di configurare il profilo.';

  @override
  String get continueWithGoogle => 'Continua con Google';

  @override
  String get signingIn => 'Accesso in corso…';

  @override
  String get termsFooter =>
      'Continuando, accetti i nostri termini e le nostre policy.';

  @override
  String get googleSignInCancelled => 'Accesso con Google annullato. Riprova.';

  @override
  String get googleSignInFailed =>
      'Impossibile completare l\'accesso con Google. Controlla la connessione internet e riprova.';

  @override
  String get languageMenuTooltip => 'Lingua';

  @override
  String get chooseAvatarTitle => 'scegli un avatar';

  @override
  String get chooseAvatarSubtitle =>
      'Puoi aggiungere una foto personalizzata più tardi in Impostazioni.';

  @override
  String get displayNameHint => 'il tuo nome';

  @override
  String get displayNameSubtitle => 'è così che ti vedranno i tuoi amici';

  @override
  String get permissionMicTitle => 'microfono';

  @override
  String get permissionMicSubtitle =>
      'così i tuoi amici possono sentirti\nquando parli...';

  @override
  String get permissionNotificationsTitle => 'notifiche';

  @override
  String get permissionNotificationsSubtitle =>
      'sapere quando i tuoi amici\nti stanno parlando';

  @override
  String get permissionBackgroundTitle => 'attività in background';

  @override
  String get permissionBackgroundSubtitle =>
      'ricevere nudge quando duo\nnon è aperto';

  @override
  String get permissionFootnote => '*ne abbiamo bisogno perché duo funzioni';

  @override
  String get permissionSetupFailed =>
      'Impossibile completare la configurazione. Riprova.';

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get settingsLanguageSection => 'Lingua';

  @override
  String get settingsLanguageTitle => 'Lingua dell\'app';

  @override
  String get settingsLanguageSubtitle =>
      'Puoi tornare all\'inglese in qualsiasi momento.';

  @override
  String get settingsSectionGroup => 'Gruppo';

  @override
  String get settingsManageGroup => 'Gestisci gruppo';

  @override
  String get settingsManageGroupSubtitle => 'Gruppi che hai creato';

  @override
  String get settingsSectionPreferences => 'Preferenze';

  @override
  String get settingsAccentColorTitle => 'Colore in evidenza';

  @override
  String get settingsAccentColorSubtitle => 'Scegli il colore usato in Duo.';

  @override
  String get settingsHapticsTitle => 'Haptic per messaggi vocali in arrivo';

  @override
  String settingsHapticsSubtitle(String detail) {
    return 'Vibrazioni continue — $detail';
  }

  @override
  String get hapticsLight => 'Leggero';

  @override
  String get hapticsPulse => 'Impulso';

  @override
  String get hapticsWild => 'Intenso';

  @override
  String get hapticsLightDetail => 'Due tocchi all\'inizio e due alla fine.';

  @override
  String get hapticsPulseDetail => 'Un doppio impulso: due coppie rapide.';

  @override
  String get hapticsWildDetail => 'Vibrazione continua per tutto il nudge.';

  @override
  String get settingsHomeBackgroundTitle => 'Sfondo home';

  @override
  String get settingsHomeBackgroundSubtitle =>
      'Scegli lo sfondo della schermata home.';

  @override
  String get settingsHomeBackgroundDefault => 'Predefinito';

  @override
  String get settingsHomeBackgroundIllustrated => 'Illustrato';

  @override
  String get settingsSaveColor => 'Salva colore';

  @override
  String get settingsSaved => 'Impostazioni salvate';

  @override
  String settingsAppVersion(String version) {
    return 'Versione $version';
  }

  @override
  String get settingsSectionBackground => 'Affidabilità in background';

  @override
  String get settingsMicPermission => 'Permesso microfono';

  @override
  String get settingsMicReady => 'Pronto';

  @override
  String get settingsMicRequired => 'Necessario prima di poter parlare.';

  @override
  String get settingsNotificationPermission => 'Permesso notifiche';

  @override
  String get settingsNotificationReady =>
      'Pronto per l\'attività in background';

  @override
  String get settingsNotificationRequired =>
      'Necessario per un\'attività in background affidabile.';

  @override
  String get settingsBatteryOptimization => 'Ottimizzazione batteria';

  @override
  String get settingsBatteryUnrestricted => 'Senza restrizioni';

  @override
  String get settingsBatteryMayInterrupt =>
      'Il dispositivo potrebbe interrompere le sessioni lunghe.';

  @override
  String get settingsClosedAppReceive => 'Ricezione a app chiusa';

  @override
  String get settingsClosedAppReady =>
      'Pronto per i nudge quando l\'app non è aperta.';

  @override
  String get settingsClosedAppRequired =>
      'Consenti notifiche e attività in background.';

  @override
  String get settingsSectionLegal => 'Note legali';

  @override
  String get settingsTerms => 'Termini e condizioni';

  @override
  String get settingsPrivacy => 'Informativa sulla privacy';

  @override
  String get settingsSectionSubscription => 'Abbonamento';

  @override
  String get settingsDuoPro => 'Duo Pro';

  @override
  String get settingsViewPlans => 'Vedi i piani';

  @override
  String settingsTrialDaysLeft(int count) {
    return '⌛ $count giorni rimasti';
  }

  @override
  String get settingsTrialOneDayLeft => '⌛ 1 giorno rimasto';

  @override
  String get settingsTrialLessThanADay => '⌛ Meno di un giorno';

  @override
  String get settingsFreePlanSubtitle =>
      'Piano gratuito — la voce live richiede Duo Pro';

  @override
  String get settingsDuoProActiveSubtitle => 'Hai Duo Pro';

  @override
  String get settingsManageSubscription => 'Gestisci abbonamento';

  @override
  String get settingsSectionSupport => 'Supporto';

  @override
  String get settingsSendFeedback => 'Invia feedback';

  @override
  String get settingsDebugLogs => 'Log di debug';

  @override
  String get settingsSectionAccount => 'Account';

  @override
  String get settingsSignedInWithGoogle => 'Accesso effettuato con Google';

  @override
  String get settingsGoogleAccount => 'Account Google';

  @override
  String get settingsLogOut => 'Esci';

  @override
  String get settingsLogOutTitle => 'Uscire?';

  @override
  String get settingsLogOutMessage =>
      'Dovrai accedere di nuovo con Google per usare Duo.';

  @override
  String get settingsDeleteAccount => 'Elimina account';

  @override
  String get settingsDeleteAccountTitle =>
      'Eliminare l\'account in modo permanente?';

  @override
  String get settingsDeleteAccountMessage =>
      'Il tuo profilo Duo, i dati del dispositivo e le preferenze verranno eliminati. L\'azione non è reversibile.';

  @override
  String get settingsDeleteAccountFailed =>
      'Impossibile eliminare l\'account. Accedi di nuovo con Google e riprova.';

  @override
  String get settingsCancel => 'Annulla';

  @override
  String get settingsEditProfile => 'Modifica profilo';

  @override
  String get settingsEditProfileSubtitle =>
      'È così che ti vedono gli amici nei tuoi gruppi.';

  @override
  String get settingsDisplayName => 'Nome visualizzato';

  @override
  String get settingsAvatarSection => 'AVATAR';

  @override
  String get settingsAvatar => 'Avatar';

  @override
  String get settingsPhoto => 'Foto';

  @override
  String get settingsYourPhoto => 'La tua foto';

  @override
  String get settingsNoPhoto => 'Nessuna foto caricata';

  @override
  String get settingsChangePhoto => 'Cambia foto';

  @override
  String get settingsUploadPhoto => 'Carica foto';

  @override
  String get settingsSaveProfile => 'Salva profilo';

  @override
  String get settingsSaving => 'Salvataggio…';

  @override
  String get settingsDone => 'Fatto';

  @override
  String get settingsClose => 'Chiudi';

  @override
  String get settingsProfileUpdated => 'Profilo aggiornato';

  @override
  String get settingsWelcomeDuoPro => 'Benvenuto su Duo Pro!';

  @override
  String get settingsPaywallFailed =>
      'Impossibile aprire le opzioni di abbonamento.';

  @override
  String get settingsMicGranted => 'Permesso microfono concesso.';

  @override
  String get settingsMicDenied => 'Permesso microfono negato.';

  @override
  String get settingsNotificationGranted => 'Permesso notifiche concesso.';

  @override
  String get settingsNotificationDenied => 'Permesso notifiche negato.';

  @override
  String get settingsBatteryRequestSent =>
      'Richiesta di ottimizzazione batteria inviata. Controlla le impostazioni del dispositivo.';

  @override
  String get settingsClosedAppChecked => 'Ricezione a app chiusa verificata.';

  @override
  String get settingsBeta => 'BETA';

  @override
  String get settingsTestingUnlocked => 'Sezione test sbloccata';

  @override
  String get settingsTestingSection => 'Test';

  @override
  String get settingsTestingHomeTitle => 'Schermata home';

  @override
  String get settingsTestingHomeSubtitle =>
      'Look temporanei per valutare gli sfondi. Il layout resta uguale.';

  @override
  String get accentCoral => 'Corallo';

  @override
  String get accentLime => 'Lime';

  @override
  String get accentSky => 'Cielo';

  @override
  String get accentViolet => 'Viola';

  @override
  String get accentAmber => 'Ambra';

  @override
  String get accentPink => 'Rosa';

  @override
  String get accentTeal => 'Teal';

  @override
  String get accentIndigo => 'Indaco';

  @override
  String get accentOrange => 'Arancio';

  @override
  String get accentMint => 'Menta';

  @override
  String get accentYellow => 'Giallo';

  @override
  String get accentCyan => 'Ciano';

  @override
  String get homeJoinGroup => '+ unisciti\nal gruppo';

  @override
  String get homeCreateGroup => '+ crea\ngruppo';

  @override
  String get homeJoinQuestion => 'Unirti?';

  @override
  String get homeNudgeTheGroup => 'Nudge al gruppo';

  @override
  String get homeSendNudge => 'Invia un nudge';

  @override
  String get homeSettings => 'Impostazioni';

  @override
  String get homeSettingsSetup => 'Impostazioni / Configurazione';

  @override
  String get homeTalk => 'Parla';

  @override
  String get homeTapToTalk => 'Tocca per parlare';

  @override
  String get homeTapToStopTalking => 'Tocca per smettere';

  @override
  String get homeStatusUnavailable =>
      'Disponibile dopo che un altro membro si unisce';

  @override
  String get homeStatusGoAway => 'Tocca per andare via';

  @override
  String get homeStatusGoOnline =>
      'Vai online quando qualcuno è già live, oppure invia un nudge per andarci insieme';

  @override
  String get homeInviteFriends => 'Invita amici';

  @override
  String get homeInviteFriendsSubtitle =>
      'Condividi questo link. Il tuo amico aprirà Duo e si unirà automaticamente a questo gruppo.';

  @override
  String get homeShareInviteLink => 'Condividi link di invito';

  @override
  String get homeInviteLinkCopied => 'Link di invito copiato';

  @override
  String get homeFallbackPinCopied => 'PIN di riserva copiato';

  @override
  String homeCopyPin(String code) {
    return 'Copia PIN $code';
  }

  @override
  String homeSelectGroup(String name) {
    return 'Seleziona il gruppo $name';
  }

  @override
  String get homeSetup => 'Configurazione';

  @override
  String get homeSetupReady =>
      'Pronto per la voce in primo piano e a app chiusa';

  @override
  String get homeSetupNeedGroup => 'Crea o unisciti a un gruppo.';

  @override
  String get homeSetupNeedMic =>
      'Il permesso del microfono non è stato confermato.';

  @override
  String get homeSetupNeedNotifications =>
      'Le notifiche sono necessarie per i nudge a app chiusa.';

  @override
  String get homeSetupNeedPush =>
      'La registrazione push non è pronta. Riapri l\'app mentre sei online.';

  @override
  String get homeSetupNeedBattery =>
      'L\'ottimizzazione della batteria può interrompere la modalità in background.';

  @override
  String get noGroupsTitle => 'Invita almeno un amico per iniziare';

  @override
  String get noGroupsSubtitle =>
      'aggiungi i tuoi besties, quelli con cui parli ogni giorno 🫶';

  @override
  String get noGroupsCreate => 'Crea gruppo';

  @override
  String get noGroupsShareInvite => 'Condividi un invito';

  @override
  String get noGroupsInviteClosedOnes => 'Invita i tuoi cari';

  @override
  String get noGroupsHavePin => 'Hai già un gruppo? Usa il PIN di un amico.';

  @override
  String get noGroupsJoinPin => 'Unisciti con PIN';

  @override
  String get noGroupsNeedGroupFirst => 'Unisciti o crea prima un gruppo';

  @override
  String get inviteSheetTitle => 'Invita i tuoi cari';

  @override
  String get inviteSheetGroupNameLabel => 'Dai un nome al gruppo';

  @override
  String get inviteSheetGroupNameHint => 'es. Famiglia, Amici…';

  @override
  String get inviteSheetContactsHeader => 'Seleziona chi invitare';

  @override
  String get inviteSheetSearchHint => 'Cerca contatti';

  @override
  String get inviteSheetNoContacts => 'Nessun contatto trovato';

  @override
  String get inviteSheetPermissionDenied =>
      'Consenti l\'accesso ai contatti per vedere chi invitare';

  @override
  String get inviteSheetPermissionButton => 'Consenti accesso ai contatti';

  @override
  String get inviteSheetSendButton => 'Crea gruppo e invia invito';

  @override
  String get inviteSheetCreating => 'Creazione gruppo…';

  @override
  String get inviteSheetGroupNameRequired =>
      'Inserisci un nome per il gruppo per continuare';

  @override
  String get createGroupTitle => 'crea gruppo';

  @override
  String get createGroupSubtitle => 'dai un nome al gruppo che vuoi avviare';

  @override
  String get createGroupHint => 'Nome del gruppo';

  @override
  String get joinGroupTitle => 'unisciti con pin';

  @override
  String get joinGroupSubtitle => 'chiedi il pin al tuo amico';

  @override
  String get joinGroupHint => 'PIN di invito';

  @override
  String get backTooltip => 'Indietro';

  @override
  String get subManageTitle => 'Gestisci abbonamento';

  @override
  String get subBetaNote => 'Duo Pro è attualmente in beta.';

  @override
  String get subManageInStore => 'Gestisci nello store';

  @override
  String get subManageInStoreSubtitle =>
      'Aggiorna, annulla o ripristina con App Store / Play';

  @override
  String get subContactTeam => 'Contatta il team Duo';

  @override
  String get subContactTeamSubtitle => 'Fatturazione e assistenza';

  @override
  String get subBetaFooter =>
      'In beta i tempi di risposta possono variare. Per i rimborsi dello store, usa Gestisci nello store se disponibile.';

  @override
  String get subContactBody => 'Scrivici per fatturazione, accesso o feedback:';

  @override
  String get subEmailCopied => 'Indirizzo email copiato negli appunti.';

  @override
  String get subClose => 'Chiudi';

  @override
  String get subCustomerCenterFailed =>
      'Impossibile aprire la gestione dell\'abbonamento.';

  @override
  String get trialExpiredTitle => 'La prova gratuita è terminata';

  @override
  String get trialExpiredBody =>
      'Continua a parlare con i tuoi amici con Duo Pro.';

  @override
  String get trialExpiredGetPro => 'Passa a Pro';

  @override
  String get crashTitle => 'L\'app ha riscontrato un problema';

  @override
  String get crashBody =>
      'Invia un report così possiamo capire cosa è successo. Include i log recenti di questo telefono.';

  @override
  String get crashSendReport => 'Invia report';

  @override
  String get crashTryAgain => 'Riprova';

  @override
  String get crashSendFailed =>
      'Impossibile inviare il report. Controlla la connessione e riprova.';

  @override
  String get startupSetupFailed =>
      'Non siamo riusciti a completare la configurazione dell\'account.';

  @override
  String get startupTryAgain => 'Riprova';

  @override
  String get homeMicOnMute => 'Microfono acceso — tocca per disattivare';

  @override
  String homeConnectedToOtherGroup(String name) {
    return 'connesso a $name • tocca per un nudge';
  }

  @override
  String get homeSomeoneLive => 'Qualcuno è live — tocca Unirti?';

  @override
  String get homeLiveVoiceLocked =>
      'La voce live richiede Duo Pro — nudge e chat restano gratis';

  @override
  String get homeInviteFriendVoice => 'invita un amico per abilitare la voce';

  @override
  String get homeSendNudgeTogether =>
      'invia un nudge per andare online insieme';

  @override
  String get chatPresetJoin15Min => 'Arrivo tra 15 min';

  @override
  String get chatPresetWhereEveryone => 'Dov\'è tutti?';

  @override
  String get chatPresetOnMyWay => 'Sto arrivando';

  @override
  String get chatPresetGiveMe5Min => 'Dammi 5 min';

  @override
  String get chatMoreEmojis => 'Altri emoji';

  @override
  String get chatWriteCustomMessage => 'Scrivi un messaggio personalizzato';

  @override
  String get chatMessageHint => 'Messaggio al gruppo…';

  @override
  String get feedbackSubtitle =>
      'Descrivi cosa è andato storto. Verranno allegati i log recenti del dispositivo.';

  @override
  String get feedbackHint => 'Cosa è successo? (facoltativo)';

  @override
  String get feedbackThanks => 'Grazie, la tua segnalazione è stata inviata';

  @override
  String get feedbackSendFailed =>
      'Impossibile inviare la segnalazione. Controlla la connessione e riprova.';

  @override
  String get debugLogsReading => 'Lettura del file di log di oggi…';

  @override
  String get debugLogsEmpty => 'Nessun file di log è stato ancora creato oggi.';

  @override
  String debugLogsTodayFile(String size, String time) {
    return 'File di oggi · $size · ultimo aggiornamento $time';
  }

  @override
  String get debugLogsShareTitle => 'Condividi file di log';

  @override
  String get debugLogsShareSubtitle =>
      'Apre il foglio di condivisione di sistema con il file .txt di oggi';

  @override
  String get debugLogsCopyTitle => 'Copia negli appunti';

  @override
  String get debugLogsCopySubtitle =>
      'Copia il testo completo del file di log di oggi';

  @override
  String get debugLogsNoFile => 'Nessun file di log ancora.';

  @override
  String get debugLogsCopied => 'Copiato negli appunti';

  @override
  String get debugLogsShareSubject => 'Log di debug Duo';

  @override
  String get legalLastUpdated => 'Ultimo aggiornamento: 12 luglio 2026';

  @override
  String get legalTerms1Title => '1. Accettazione dei termini';

  @override
  String get legalTerms1Body =>
      'Scaricando, accedendo o utilizzando Duo, accetti questi Termini e Condizioni. Se non sei d\'accordo, non utilizzare l\'app.';

  @override
  String get legalTerms2Title => '2. Il servizio';

  @override
  String get legalTerms2Body =>
      'Duo consente di creare o unirsi a gruppi privati e scambiare audio vocale in diretta. Disponibilità, qualità audio e consegna in background possono dipendere dall\'accesso alla rete, dalle impostazioni del dispositivo, dalle autorizzazioni e dai servizi di terze parti. Il servizio è fornito secondo disponibilità.';

  @override
  String get legalTerms3Title => '3. Le tue responsabilità';

  @override
  String get legalTerms3Body =>
      'Sei responsabile dell\'attività associata alla tua installazione e di mantenere privati i codici di invito. Devi avere il diritto di condividere qualsiasi nome, foto del profilo, voce o altro contenuto che fornisci. Non utilizzare Duo per molestare altri, violare la loro privacy, impersonare qualcuno, infrangere la legge o interferire con il servizio.';

  @override
  String get legalTerms4Title => '4. Voce e autorizzazioni';

  @override
  String get legalTerms4Body =>
      'Duo richiede l\'accesso al microfono per trasmettere la voce in diretta. Controlli quando inizia la trasmissione tramite il controllo di conversazione nell\'app. Possono essere richieste autorizzazioni per notifiche e attività in background per supportare disponibilità e funzionalità audio. Puoi modificare le autorizzazioni nelle impostazioni del dispositivo.';

  @override
  String get legalTerms5Title => '5. Servizi di terze parti';

  @override
  String get legalTerms5Body =>
      'Duo si affida a fornitori di servizi per autenticazione, archiviazione dati, consegna media, hosting delle foto del profilo e infrastruttura. I loro servizi possono essere regolati da termini separati e possono occasionalmente non essere disponibili.';

  @override
  String get legalTerms6Title => '6. Sospensione e cessazione';

  @override
  String get legalTerms6Body =>
      'Possiamo limitare o terminare l\'accesso quando ragionevolmente necessario per proteggere gli utenti, rispettare la legge, prevenire abusi o mantenere il servizio. Puoi smettere di utilizzare Duo in qualsiasi momento e rimuovere l\'app dal dispositivo.';

  @override
  String get legalTerms7Title => '7. Esclusioni e responsabilità';

  @override
  String get legalTerms7Body =>
      'Nella misura consentita dalla legge, Duo è fornito senza garanzie di funzionamento ininterrotto, privo di errori o sicuro. Non siamo responsabili per danni indiretti, incidentali, speciali, consequenziali o punitivi derivanti dall\'uso dell\'app. Nulla in questi termini limita diritti o responsabilità che non possono essere legalmente limitati.';

  @override
  String get legalTerms8Title => '8. Modifiche';

  @override
  String get legalTerms8Body =>
      'Possiamo aggiornare questi termini man mano che il servizio cambia. La data aggiornata apparirà in cima a questa pagina. L\'uso continuato dopo un aggiornamento significa che accetti i termini rivisti.';

  @override
  String get legalTerms9Title => '9. Contatto';

  @override
  String get legalTerms9Body =>
      'Le domande su questi termini possono essere inviate tramite il canale di supporto indicato nella scheda Duo dell\'App Store.';

  @override
  String get legalPrivacy1Title => '1. Panoramica';

  @override
  String get legalPrivacy1Body =>
      'Questa Informativa sulla privacy spiega cosa raccoglie Duo, perché viene utilizzato e le scelte disponibili quando usi l\'app.';

  @override
  String get legalPrivacy2Title => '2. Informazioni che raccogliamo';

  @override
  String get legalPrivacy2Body =>
      'Raccogliamo l\'identificativo dell\'account e l\'indirizzo e-mail autenticati con Google, il nome visualizzato, la foto del profilo facoltativa, le informazioni sull\'appartenenza ai gruppi e sugli inviti, le impostazioni dell\'app, gli identificativi del dispositivo e della versione dell\'app, lo stato delle autorizzazioni, lo stato di disponibilità e le diagnosi di base del servizio. Quando usi la voce in diretta, l\'audio del microfono viene trasmesso agli altri membri attivi del tuo gruppo.';

  @override
  String get legalPrivacy3Title => '3. Come vengono utilizzate le informazioni';

  @override
  String get legalPrivacy3Body =>
      'Le informazioni vengono utilizzate per creare la tua identità nell\'app, mostrare il tuo profilo ai membri del gruppo, gestire gruppi e inviti, connettere sessioni vocali in diretta, ricordare le preferenze, mantenere la disponibilità, diagnosticare l\'affidabilità, prevenire abusi e gestire e migliorare Duo.';

  @override
  String get legalPrivacy4Title => '4. Audio';

  @override
  String get legalPrivacy4Body =>
      'La voce in diretta viene trasmessa affinché i membri del gruppo possano sentirti. Duo non è progettato per registrare o archiviare il contenuto delle tue conversazioni in diretta. I fornitori di servizi possono elaborare metadati di rete e connessione necessari per consegnare l\'audio.';

  @override
  String get legalPrivacy5Title => '5. Fornitori di servizi';

  @override
  String get legalPrivacy5Body =>
      'Duo utilizza fornitori tra cui Google Firebase per autenticazione e dati dell\'app, Cloudinary per l\'hosting delle foto del profilo, LiveKit per audio in tempo reale e provider di hosting per i servizi applicativi. Questi fornitori elaborano le informazioni per nostro conto secondo le proprie pratiche di privacy e sicurezza.';

  @override
  String get legalPrivacy6Title => '6. Condivisione';

  @override
  String get legalPrivacy6Body =>
      'Il tuo nome visualizzato, la foto del profilo, la disponibilità e la voce in diretta vengono condivisi con i membri dei gruppi a cui ti unisci. Possiamo anche divulgare informazioni a fornitori di servizi, per rispettare la legge o un procedimento legale valido, per proteggere utenti e servizio, o come parte di un trasferimento aziendale. Non vendiamo informazioni personali.';

  @override
  String get legalPrivacy7Title => '7. Conservazione e sicurezza';

  @override
  String get legalPrivacy7Body =>
      'Conserviamo le informazioni solo per il tempo ragionevolmente necessario a fornire il servizio, adempiere agli obblighi legali, risolvere controversie e proteggere l\'app. Utilizziamo misure di protezione ragionevoli, ma nessun servizio in rete può garantire una sicurezza assoluta.';

  @override
  String get legalPrivacy8Title => '8. Le tue scelte';

  @override
  String get legalPrivacy8Body =>
      'Puoi modificare il nome visualizzato, la foto del profilo, le preferenze dell\'app e le autorizzazioni del dispositivo. Puoi lasciare i gruppi, disconnetterti o eliminare il tuo account dalle Impostazioni. Le richieste di accesso alle informazioni possono essere inviate tramite il canale di supporto indicato nella scheda Duo dell\'App Store. Potremmo aver bisogno di informazioni che identificano la tua installazione dell\'app per completare una richiesta.';

  @override
  String get legalPrivacy9Title => '9. Minori';

  @override
  String get legalPrivacy9Body =>
      'Duo non è destinato a minori di 13 anni, o all\'età minima richiesta dalla legge locale. Non raccogliamo consapevolmente informazioni personali da minori al di sotto di quell\'età.';

  @override
  String get legalPrivacy10Title => '10. Trattamento internazionale';

  @override
  String get legalPrivacy10Body =>
      'Le informazioni possono essere elaborate in paesi diversi dal tuo. Ove richiesto, vengono utilizzate garanzie appropriate per i trasferimenti internazionali.';

  @override
  String get legalPrivacy11Title => '11. Modifiche e contatto';

  @override
  String get legalPrivacy11Body =>
      'Possiamo aggiornare questa informativa man mano che Duo cambia. La data aggiornata apparirà sopra. Domande e richieste sulla privacy possono essere inviate tramite il canale di supporto indicato nella scheda Duo dell\'App Store.';
}
