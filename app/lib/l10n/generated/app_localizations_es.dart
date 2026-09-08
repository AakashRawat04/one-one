// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get welcomeTitle => 'Bienvenido a Duo';

  @override
  String get welcomeSubtitle =>
      'Inicia sesión o crea tu cuenta antes de configurar tu perfil.';

  @override
  String get continueWithGoogle => 'Continuar con Google';

  @override
  String get signingIn => 'Iniciando sesión…';

  @override
  String get termsFooter =>
      'Al continuar, aceptas nuestros términos y políticas.';

  @override
  String get googleSignInCancelled =>
      'Se canceló el inicio de sesión de Google. Inténtalo de nuevo.';

  @override
  String get googleSignInFailed =>
      'No se pudo completar el inicio de sesión de Google. Comprueba tu conexión a internet e inténtalo de nuevo.';

  @override
  String get languageMenuTooltip => 'Idioma';

  @override
  String get chooseAvatarTitle => 'elige un avatar';

  @override
  String get chooseAvatarSubtitle =>
      'Puedes añadir una foto personalizada más tarde en Ajustes.';

  @override
  String get displayNameHint => 'tu nombre';

  @override
  String get displayNameSubtitle => 'así es como te verán tus amigos';

  @override
  String get permissionMicTitle => 'micrófono';

  @override
  String get permissionMicSubtitle =>
      'para que tus amigos te oigan\ncuando hables...';

  @override
  String get permissionNotificationsTitle => 'notificaciones';

  @override
  String get permissionNotificationsSubtitle =>
      'entérate cuando tus amigos\nte hablen';

  @override
  String get permissionBackgroundTitle => 'actividad en segundo plano';

  @override
  String get permissionBackgroundSubtitle =>
      'recibe nudges cuando duo\nno esté abierto';

  @override
  String get permissionFootnote => '*los necesitamos para que duo funcione';

  @override
  String get permissionSetupFailed =>
      'No se pudo completar la configuración. Inténtalo de nuevo.';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsLanguageSection => 'Idioma';

  @override
  String get settingsLanguageTitle => 'Idioma de la app';

  @override
  String get settingsLanguageSubtitle =>
      'Puedes volver al inglés en cualquier momento.';

  @override
  String get settingsSectionGroup => 'Grupo';

  @override
  String get settingsManageGroup => 'Gestionar grupo';

  @override
  String get settingsManageGroupSubtitle => 'Grupos que creaste';

  @override
  String get settingsSectionPreferences => 'Preferencias';

  @override
  String get settingsAccentColorTitle => 'Color de acento';

  @override
  String get settingsAccentColorSubtitle => 'Elige el color que se usa en Duo.';

  @override
  String get settingsHapticsTitle => 'Hápticos para mensajes de voz entrantes';

  @override
  String settingsHapticsSubtitle(String detail) {
    return 'Vibraciones continuas — $detail';
  }

  @override
  String get hapticsLight => 'Suave';

  @override
  String get hapticsPulse => 'Pulso';

  @override
  String get hapticsWild => 'Intenso';

  @override
  String get hapticsLightDetail => 'Dos toques al inicio y dos al final.';

  @override
  String get hapticsPulseDetail => 'Un pulso doble: dos pares rápidos.';

  @override
  String get hapticsWildDetail => 'Vibración continua durante todo el nudge.';

  @override
  String get settingsSaveColor => 'Guardar color';

  @override
  String get settingsSaved => 'Ajustes guardados';

  @override
  String get settingsSectionBackground => 'Fiabilidad en segundo plano';

  @override
  String get settingsMicPermission => 'Permiso del micrófono';

  @override
  String get settingsMicReady => 'Listo';

  @override
  String get settingsMicRequired => 'Necesario antes de poder hablar.';

  @override
  String get settingsNotificationPermission => 'Permiso de notificaciones';

  @override
  String get settingsNotificationReady =>
      'Listo para la actividad en segundo plano';

  @override
  String get settingsNotificationRequired =>
      'Necesario para una actividad en segundo plano fiable.';

  @override
  String get settingsBatteryOptimization => 'Optimización de batería';

  @override
  String get settingsBatteryUnrestricted => 'Sin restricciones';

  @override
  String get settingsBatteryMayInterrupt =>
      'Tu dispositivo puede interrumpir las sesiones largas.';

  @override
  String get settingsClosedAppReceive => 'Recepción con la app cerrada';

  @override
  String get settingsClosedAppReady =>
      'Listo para nudges cuando la app no está abierta.';

  @override
  String get settingsClosedAppRequired =>
      'Permite notificaciones y actividad en segundo plano.';

  @override
  String get settingsSectionLegal => 'Legal';

  @override
  String get settingsTerms => 'Términos y condiciones';

  @override
  String get settingsPrivacy => 'Política de privacidad';

  @override
  String get settingsSectionSubscription => 'Suscripción';

  @override
  String get settingsDuoPro => 'Duo Pro';

  @override
  String get settingsViewPlans => 'Ver planes';

  @override
  String settingsTrialDaysLeft(int count) {
    return '$count días restantes de la prueba gratis';
  }

  @override
  String get settingsTrialOneDayLeft => '1 día restante de la prueba gratis';

  @override
  String get settingsTrialLessThanADay => 'Menos de un día de prueba gratis';

  @override
  String get settingsFreePlanSubtitle =>
      'Plan gratis — la voz en vivo requiere Duo Pro';

  @override
  String get settingsDuoProActiveSubtitle => 'Tienes Duo Pro';

  @override
  String get settingsManageSubscription => 'Gestionar suscripción';

  @override
  String get settingsSectionSupport => 'Ayuda';

  @override
  String get settingsSendFeedback => 'Enviar comentarios';

  @override
  String get settingsDebugLogs => 'Registros de depuración';

  @override
  String get settingsSectionAccount => 'Cuenta';

  @override
  String get settingsSignedInWithGoogle => 'Sesión iniciada con Google';

  @override
  String get settingsGoogleAccount => 'Cuenta de Google';

  @override
  String get settingsLogOut => 'Cerrar sesión';

  @override
  String get settingsLogOutTitle => '¿Cerrar sesión?';

  @override
  String get settingsLogOutMessage =>
      'Tendrás que iniciar sesión con Google para usar Duo de nuevo.';

  @override
  String get settingsDeleteAccount => 'Eliminar cuenta';

  @override
  String get settingsDeleteAccountTitle =>
      '¿Eliminar la cuenta de forma permanente?';

  @override
  String get settingsDeleteAccountMessage =>
      'Tu perfil de Duo, la información del dispositivo y tus preferencias se eliminarán. Esta acción no se puede deshacer.';

  @override
  String get settingsDeleteAccountFailed =>
      'No se pudo eliminar la cuenta. Inicia sesión con Google e inténtalo de nuevo.';

  @override
  String get settingsCancel => 'Cancelar';

  @override
  String get settingsEditProfile => 'Editar perfil';

  @override
  String get settingsEditProfileSubtitle =>
      'Así te ven tus amigos en tus grupos.';

  @override
  String get settingsDisplayName => 'Nombre visible';

  @override
  String get settingsAvatarSection => 'AVATAR';

  @override
  String get settingsAvatar => 'Avatar';

  @override
  String get settingsPhoto => 'Foto';

  @override
  String get settingsYourPhoto => 'Tu foto subida';

  @override
  String get settingsNoPhoto => 'Aún no hay foto';

  @override
  String get settingsChangePhoto => 'Cambiar foto';

  @override
  String get settingsUploadPhoto => 'Subir foto';

  @override
  String get settingsSaveProfile => 'Guardar perfil';

  @override
  String get settingsSaving => 'Guardando…';

  @override
  String get settingsDone => 'Listo';

  @override
  String get settingsClose => 'Cerrar';

  @override
  String get settingsProfileUpdated => 'Perfil actualizado';

  @override
  String get settingsWelcomeDuoPro => '¡Bienvenido a Duo Pro!';

  @override
  String get settingsPaywallFailed =>
      'No se pudieron abrir las opciones de suscripción.';

  @override
  String get settingsMicGranted => 'Permiso del micrófono concedido.';

  @override
  String get settingsMicDenied => 'Se denegó el permiso del micrófono.';

  @override
  String get settingsNotificationGranted =>
      'Permiso de notificaciones concedido.';

  @override
  String get settingsNotificationDenied =>
      'Se denegó el permiso de notificaciones.';

  @override
  String get settingsBatteryRequestSent =>
      'Solicitud de optimización de batería enviada. Revisa los ajustes del dispositivo.';

  @override
  String get settingsClosedAppChecked =>
      'Recepción con la app cerrada comprobada.';

  @override
  String get settingsBeta => 'BETA';

  @override
  String get settingsTestingUnlocked => 'Sección de pruebas desbloqueada';

  @override
  String get settingsTestingSection => 'Pruebas';

  @override
  String get settingsTestingHomeTitle => 'Pantalla de inicio';

  @override
  String get settingsTestingHomeSubtitle =>
      'Looks temporales para evaluar fondos. El diseño no cambia.';

  @override
  String get accentCoral => 'Coral';

  @override
  String get accentLime => 'Lima';

  @override
  String get accentSky => 'Cielo';

  @override
  String get accentViolet => 'Violeta';

  @override
  String get accentAmber => 'Ámbar';

  @override
  String get accentPink => 'Rosa';

  @override
  String get accentTeal => 'Verde azulado';

  @override
  String get accentIndigo => 'Índigo';

  @override
  String get accentOrange => 'Naranja';

  @override
  String get accentMint => 'Menta';

  @override
  String get accentYellow => 'Amarillo';

  @override
  String get accentCyan => 'Cian';

  @override
  String get homeJoinGroup => '+ unirse\nal grupo';

  @override
  String get homeCreateGroup => '+ crear\ngrupo';

  @override
  String get homeJoinQuestion => '¿Unirse?';

  @override
  String get homeNudgeTheGroup => 'Nudge al grupo';

  @override
  String get homeSendNudge => 'Enviar un nudge';

  @override
  String get homeSettings => 'Ajustes';

  @override
  String get homeSettingsSetup => 'Ajustes / Configuración';

  @override
  String get homeTalk => 'Hablar';

  @override
  String get homeTapToTalk => 'Toca para hablar';

  @override
  String get homeTapToStopTalking => 'Toca para dejar de hablar';

  @override
  String get homeStatusUnavailable => 'Disponible cuando otro miembro se una';

  @override
  String get homeStatusGoAway => 'Toca para ausentarte';

  @override
  String get homeStatusGoOnline =>
      'Ponte en línea cuando alguien ya esté en directo, o envía un nudge para ir juntos';

  @override
  String get homeInviteFriends => 'Invitar amigos';

  @override
  String get homeInviteFriendsSubtitle =>
      'Comparte este enlace. Tu amigo abrirá Duo y se unirá a este grupo automáticamente.';

  @override
  String get homeShareInviteLink => 'Compartir enlace de invitación';

  @override
  String get homeInviteLinkCopied => 'Enlace de invitación copiado';

  @override
  String get homeFallbackPinCopied => 'PIN alternativo copiado';

  @override
  String homeCopyPin(String code) {
    return 'Copiar PIN $code';
  }

  @override
  String homeSelectGroup(String name) {
    return 'Seleccionar el grupo $name';
  }

  @override
  String get homeSetup => 'Configuración';

  @override
  String get homeSetupReady =>
      'Listo para voz en primer plano y con la app cerrada';

  @override
  String get homeSetupNeedGroup => 'Crea o únete a un grupo.';

  @override
  String get homeSetupNeedMic =>
      'El permiso del micrófono no se ha confirmado.';

  @override
  String get homeSetupNeedNotifications =>
      'Se necesitan notificaciones para los nudges con la app cerrada.';

  @override
  String get homeSetupNeedPush =>
      'El registro push no está listo. Vuelve a abrir la app con conexión.';

  @override
  String get homeSetupNeedBattery =>
      'La optimización de batería puede interrumpir el segundo plano.';

  @override
  String get noGroupsTitle => 'Invita al menos a un amigo para empezar';

  @override
  String get noGroupsSubtitle =>
      'añade a tus besties, con las que hablas todos los días 🫶';

  @override
  String get noGroupsCreate => 'Crear grupo';

  @override
  String get noGroupsShareInvite => 'Compartir una invitación';

  @override
  String get noGroupsInviteClosedOnes => 'Invita a tus seres queridos';

  @override
  String get noGroupsHavePin => '¿Ya tienes un grupo? Usa el PIN de un amigo.';

  @override
  String get noGroupsJoinPin => 'Unirse con PIN';

  @override
  String get noGroupsNeedGroupFirst => 'Únete o crea un grupo primero';

  @override
  String get inviteSheetTitle => 'Invita a tus seres queridos';

  @override
  String get inviteSheetGroupNameLabel => 'Nombra tu grupo';

  @override
  String get inviteSheetGroupNameHint => 'p. ej. Familia, Amigos…';

  @override
  String get inviteSheetContactsHeader => 'Selecciona a quién invitar';

  @override
  String get inviteSheetSearchHint => 'Buscar contactos';

  @override
  String get inviteSheetNoContacts => 'No se encontraron contactos';

  @override
  String get inviteSheetPermissionDenied =>
      'Permite el acceso a contactos para ver a quién invitar';

  @override
  String get inviteSheetPermissionButton => 'Permitir acceso a contactos';

  @override
  String get inviteSheetSendButton => 'Crear grupo y enviar invitación';

  @override
  String get inviteSheetCreating => 'Creando grupo…';

  @override
  String get inviteSheetGroupNameRequired =>
      'Ingresa un nombre de grupo para continuar';

  @override
  String get createGroupTitle => 'crear grupo';

  @override
  String get createGroupSubtitle => 'ponle nombre al grupo que quieres empezar';

  @override
  String get createGroupHint => 'Nombre del grupo';

  @override
  String get joinGroupTitle => 'unirse con pin';

  @override
  String get joinGroupSubtitle => 'pídele el pin a tu amigo';

  @override
  String get joinGroupHint => 'PIN de invitación';

  @override
  String get backTooltip => 'Atrás';

  @override
  String get subManageTitle => 'Gestionar suscripción';

  @override
  String get subBetaNote => 'Duo Pro está actualmente en beta.';

  @override
  String get subManageInStore => 'Gestionar en la tienda';

  @override
  String get subManageInStoreSubtitle =>
      'Mejorar, cancelar o restaurar con App Store / Play';

  @override
  String get subContactTeam => 'Contactar al equipo Duo';

  @override
  String get subContactTeamSubtitle => 'Facturación y soporte';

  @override
  String get subBetaFooter =>
      'Durante la beta, los tiempos de respuesta pueden variar. Para reembolsos, usa Gestionar en la tienda si está disponible.';

  @override
  String get subContactBody =>
      'Escríbenos sobre facturación, acceso o comentarios:';

  @override
  String get subEmailCopied => 'Dirección de correo copiada al portapapeles.';

  @override
  String get subClose => 'Cerrar';

  @override
  String get subCustomerCenterFailed =>
      'No se pudo abrir la gestión de suscripción.';

  @override
  String get trialExpiredTitle => 'Tu prueba gratuita ha terminado';

  @override
  String get trialExpiredBody =>
      'Sigue hablando con tus amigos continuando con Duo Pro.';

  @override
  String get trialExpiredGetPro => 'Obtener Pro';

  @override
  String get crashTitle => 'La app se encontró con un problema';

  @override
  String get crashBody =>
      'Envía un informe para que podamos revisar qué ocurrió. Incluye registros recientes de este teléfono.';

  @override
  String get crashSendReport => 'Enviar informe';

  @override
  String get crashTryAgain => 'Reintentar';

  @override
  String get crashSendFailed =>
      'No se pudo enviar el informe. Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get startupSetupFailed =>
      'No pudimos terminar de configurar tu cuenta.';

  @override
  String get startupTryAgain => 'Reintentar';

  @override
  String get homeMicOnMute => 'Micrófono activo — toca para silenciar';

  @override
  String homeConnectedToOtherGroup(String name) {
    return 'conectado a $name • toca para enviar un nudge';
  }

  @override
  String get homeSomeoneLive => 'Alguien está en directo — toca ¿Unirse?';

  @override
  String get homeLiveVoiceLocked =>
      'La voz en vivo requiere Duo Pro — los nudges y el chat siguen siendo gratis';

  @override
  String get homeInviteFriendVoice => 'invita a un amigo para activar la voz';

  @override
  String get homeSendNudgeTogether =>
      'envía un nudge para estar en línea juntos';

  @override
  String get chatPresetJoin15Min => 'Me uno en 15 min';

  @override
  String get chatPresetWhereEveryone => '¿Dónde está todo el mundo?';

  @override
  String get chatPresetOnMyWay => 'Voy de camino';

  @override
  String get chatPresetGiveMe5Min => 'Dame 5 min';

  @override
  String get chatMoreEmojis => 'Más emojis';

  @override
  String get chatWriteCustomMessage => 'Escribir un mensaje personalizado';

  @override
  String get chatMessageHint => 'Mensaje al grupo…';

  @override
  String get feedbackSubtitle =>
      'Describe qué salió mal. Se adjuntarán los registros recientes del dispositivo.';

  @override
  String get feedbackHint => '¿Qué ocurrió? (opcional)';

  @override
  String get feedbackThanks => 'Gracias, tu informe se ha enviado';

  @override
  String get feedbackSendFailed =>
      'No se pudo enviar tu informe. Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get debugLogsReading => 'Leyendo el archivo de registro de hoy…';

  @override
  String get debugLogsEmpty =>
      'Aún no se ha creado ningún archivo de registro hoy.';

  @override
  String debugLogsTodayFile(String size, String time) {
    return 'Archivo de hoy · $size · última actualización $time';
  }

  @override
  String get debugLogsShareTitle => 'Compartir archivo de registro';

  @override
  String get debugLogsShareSubtitle =>
      'Abre la hoja de compartir del sistema con el archivo .txt de hoy';

  @override
  String get debugLogsCopyTitle => 'Copiar al portapapeles';

  @override
  String get debugLogsCopySubtitle =>
      'Copia el texto completo del archivo de registro de hoy';

  @override
  String get debugLogsNoFile => 'Aún no hay archivo de registro.';

  @override
  String get debugLogsCopied => 'Copiado al portapapeles';

  @override
  String get debugLogsShareSubject => 'Registros de depuración de Duo';

  @override
  String get legalLastUpdated => 'Última actualización: 12 de julio de 2026';

  @override
  String get legalTerms1Title => '1. Aceptación de los términos';

  @override
  String get legalTerms1Body =>
      'Al descargar, acceder o usar Duo, aceptas estos Términos y Condiciones. Si no estás de acuerdo, no uses la aplicación.';

  @override
  String get legalTerms2Title => '2. El servicio';

  @override
  String get legalTerms2Body =>
      'Duo permite crear o unirse a grupos privados e intercambiar audio de voz en directo. La disponibilidad, la calidad del audio y la entrega en segundo plano pueden depender del acceso a la red, la configuración del dispositivo, los permisos y los servicios de terceros. El servicio se proporciona según disponibilidad.';

  @override
  String get legalTerms3Title => '3. Tus responsabilidades';

  @override
  String get legalTerms3Body =>
      'Eres responsable de la actividad asociada a tu instalación y de mantener privados los códigos de invitación. Debes tener derecho a compartir cualquier nombre, foto de perfil, voz u otro contenido que proporciones. No uses Duo para acosar a otros, violar su privacidad, suplantar identidades, infringir la ley o interferir con el servicio.';

  @override
  String get legalTerms4Title => '4. Voz y permisos';

  @override
  String get legalTerms4Body =>
      'Duo requiere acceso al micrófono para transmitir voz en directo. Tú controlas cuándo comienza la transmisión mediante el control de conversación en la aplicación. Se pueden solicitar permisos de notificación y de segundo plano para admitir la disponibilidad y las funciones de audio. Puedes cambiar los permisos en la configuración de tu dispositivo.';

  @override
  String get legalTerms5Title => '5. Servicios de terceros';

  @override
  String get legalTerms5Body =>
      'Duo depende de proveedores de servicios para la autenticación, el almacenamiento de datos, la entrega de medios, el alojamiento de fotos de perfil y la infraestructura. Sus servicios pueden regirse por términos independientes y pueden estar ocasionalmente no disponibles.';

  @override
  String get legalTerms6Title => '6. Suspensión y terminación';

  @override
  String get legalTerms6Body =>
      'Podemos restringir o finalizar el acceso cuando sea razonablemente necesario para proteger a los usuarios, cumplir la ley, prevenir abusos o mantener el servicio. Puedes dejar de usar Duo en cualquier momento y eliminar la aplicación de tu dispositivo.';

  @override
  String get legalTerms7Title => '7. Exenciones y responsabilidad';

  @override
  String get legalTerms7Body =>
      'En la medida permitida por la ley, Duo se proporciona sin garantías de funcionamiento ininterrumpido, libre de errores o seguro. No somos responsables de daños indirectos, incidentales, especiales, consecuentes o punitivos derivados del uso de la aplicación. Nada en estos términos limita derechos o responsabilidades que no puedan limitarse legalmente.';

  @override
  String get legalTerms8Title => '8. Cambios';

  @override
  String get legalTerms8Body =>
      'Podemos actualizar estos términos a medida que el servicio cambie. La fecha actualizada aparecerá en la parte superior de esta página. El uso continuado tras una actualización significa que aceptas los términos revisados.';

  @override
  String get legalTerms9Title => '9. Contacto';

  @override
  String get legalTerms9Body =>
      'Las preguntas sobre estos términos pueden enviarse a través del canal de soporte que aparece en la ficha de Duo en la App Store.';

  @override
  String get legalPrivacy1Title => '1. Resumen';

  @override
  String get legalPrivacy1Body =>
      'Esta Política de Privacidad explica qué recopila Duo, por qué se utiliza y las opciones disponibles para ti cuando usas la aplicación.';

  @override
  String get legalPrivacy2Title => '2. Información que recopilamos';

  @override
  String get legalPrivacy2Body =>
      'Recopilamos el identificador de cuenta y la dirección de correo electrónico autenticados con Google, el nombre para mostrar, la foto de perfil opcional, la información de pertenencia a grupos e invitaciones, la configuración de la aplicación, los identificadores del dispositivo y de la versión de la aplicación, el estado de los permisos, el estado de disponibilidad y los diagnósticos básicos del servicio. Cuando usas voz en directo, el audio del micrófono se transmite a los demás miembros activos de tu grupo.';

  @override
  String get legalPrivacy3Title => '3. Cómo se utiliza la información';

  @override
  String get legalPrivacy3Body =>
      'La información se utiliza para crear tu identidad en la aplicación, mostrar tu perfil a los miembros del grupo, gestionar grupos e invitaciones, conectar sesiones de voz en directo, recordar preferencias, mantener la disponibilidad, diagnosticar la fiabilidad, prevenir el uso indebido y operar y mejorar Duo.';

  @override
  String get legalPrivacy4Title => '4. Audio';

  @override
  String get legalPrivacy4Body =>
      'La voz en directo se transmite para que los miembros del grupo puedan oírte. Duo no está diseñado para grabar ni almacenar el contenido de tus conversaciones en directo. Los proveedores de servicios pueden procesar metadatos de red y conexión necesarios para entregar el audio.';

  @override
  String get legalPrivacy5Title => '5. Proveedores de servicios';

  @override
  String get legalPrivacy5Body =>
      'Duo utiliza proveedores como Google Firebase para la autenticación y los datos de la aplicación, Cloudinary para el alojamiento de fotos de perfil, LiveKit para audio en tiempo real y proveedores de alojamiento para los servicios de la aplicación. Estos proveedores procesan la información en nuestro nombre según sus propias prácticas de privacidad y seguridad.';

  @override
  String get legalPrivacy6Title => '6. Compartir';

  @override
  String get legalPrivacy6Body =>
      'Tu nombre para mostrar, tu foto de perfil, tu disponibilidad y tu voz en directo se comparten con los miembros de los grupos a los que te unes. También podemos divulgar información a proveedores de servicios, para cumplir la ley o un proceso legal válido, para proteger a los usuarios y el servicio, o como parte de una transferencia comercial. No vendemos información personal.';

  @override
  String get legalPrivacy7Title => '7. Retención y seguridad';

  @override
  String get legalPrivacy7Body =>
      'Conservamos la información solo el tiempo razonablemente necesario para prestar el servicio, cumplir obligaciones legales, resolver disputas y proteger la aplicación. Utilizamos medidas de protección razonables, pero ningún servicio en red puede garantizar una seguridad absoluta.';

  @override
  String get legalPrivacy8Title => '8. Tus opciones';

  @override
  String get legalPrivacy8Body =>
      'Puedes cambiar tu nombre para mostrar, tu foto de perfil, las preferencias de la aplicación y los permisos del dispositivo. Puedes abandonar grupos, cerrar sesión o eliminar tu cuenta desde Ajustes. Las solicitudes de acceso a la información pueden realizarse a través del canal de soporte que aparece en la ficha de Duo en la App Store. Es posible que necesitemos información que identifique tu instalación de la aplicación para completar una solicitud.';

  @override
  String get legalPrivacy9Title => '9. Menores';

  @override
  String get legalPrivacy9Body =>
      'Duo no está dirigido a menores de 13 años, o la edad mínima exigida por la ley local. No recopilamos conscientemente información personal de menores por debajo de esa edad.';

  @override
  String get legalPrivacy10Title => '10. Procesamiento internacional';

  @override
  String get legalPrivacy10Body =>
      'La información puede procesarse en países distintos al tuyo. Cuando sea necesario, se utilizan garantías adecuadas para las transferencias internacionales.';

  @override
  String get legalPrivacy11Title => '11. Cambios y contacto';

  @override
  String get legalPrivacy11Body =>
      'Podemos actualizar esta política a medida que Duo cambie. La fecha actualizada aparecerá arriba. Las preguntas y solicitudes sobre privacidad pueden enviarse a través del canal de soporte que aparece en la ficha de Duo en la App Store.';
}
