package app.oneone.one_one_app

import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.drawable.Icon
import android.os.Build
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Rational
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.core.splashscreen.SplashScreenViewProvider
import com.google.firebase.FirebaseApp
import com.google.firebase.installations.FirebaseInstallations
import com.google.firebase.messaging.FirebaseMessaging
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : FlutterFragmentActivity() {
    private lateinit var voiceNudgeChannel: MethodChannel
    private lateinit var inviteLinkChannel: MethodChannel
    private lateinit var voicePipChannel: MethodChannel
    private var audioOutputChannel: MethodChannel? = null
    private var audioOutputMonitor: AudioOutputMonitor? = null
    private var proximityScreenControl: ProximityScreenControl? = null
    private var voiceOverlayAnnouncer: VoiceOverlayAnnouncer? = null
    private var voiceSessionActive = false
    private var voiceSessionTalking = false

    // Held true until Flutter reports real content is on screen (see the
    // "app/splash" channel below). A generous failsafe timeout guarantees
    // the splash can never get stuck forever if that signal is ever lost.
    @Volatile private var isFlutterReady = false
    private var heldSplashView: SplashScreenViewProvider? = null
    private val splashFailsafeHandler = Handler(Looper.getMainLooper())
    private val splashFailsafeRunnable = Runnable {
        Log.w(
            VoiceNudgeDiagnostics.tag,
            "[SPLASH-01] flutterReady signal not received within failsafe window; releasing splash",
        )
        releaseSplash()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // installSplashScreen + keep-on-screen must both run before
        // super.onCreate(). FlutterFragmentActivity can attach the Flutter
        // view and request a draw during onCreate; if the keep-condition is
        // still the default at that point, Android 12+ dismisses the native
        // splash at first frame and the Flutter underlay (previously a
        // second, larger logo) flashes through.
        val splashScreen = installSplashScreen()
        splashScreen.setKeepOnScreenCondition { !isFlutterReady }
        splashScreen.setOnExitAnimationListener { splashView ->
            if (isFlutterReady) {
                splashView.remove()
            } else {
                // Some OEM/API combinations start the splash exit before
                // keepOnScreenCondition is honoured. Hold this view until
                // Flutter signals the first real screen is painted.
                Log.w(
                    VoiceNudgeDiagnostics.tag,
                    "[SPLASH-02] splash exit requested before flutterReady; holding splash view",
                )
                heldSplashView = splashView
            }
        }
        super.onCreate(savedInstanceState)
        splashFailsafeHandler.postDelayed(splashFailsafeRunnable, SPLASH_FAILSAFE_TIMEOUT_MS)
    }

    private fun releaseSplash() {
        isFlutterReady = true
        heldSplashView?.remove()
        heldSplashView = null
    }

    private fun attachAudioOutputChannel(flutterEngine: FlutterEngine) {
        audioOutputMonitor?.stop()
        proximityScreenControl?.setEnabled(false)
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AudioOutputContract.flutterChannel,
        )
        audioOutputChannel = channel
        val proximity = ProximityScreenControl(this)
        proximityScreenControl = proximity
        val monitor = AudioOutputMonitor(this) {
            channel.invokeMethod(
                AudioOutputContract.methodOnStateChanged,
                AudioOutput.readState(this),
            )
        }
        audioOutputMonitor = monitor
        monitor.start()
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                AudioOutputContract.methodGetState ->
                    result.success(AudioOutput.readState(this))
                AudioOutputContract.methodSetMuted -> {
                    val (muted, showUi) = when (val args = call.arguments) {
                        is Map<*, *> -> Pair(
                            args["muted"] == true,
                            args["showUi"] != false,
                        )
                        else -> Pair(args == true, true)
                    }
                    MediaVolume.setMuted(this, muted, showUi)
                    result.success(AudioOutput.readState(this))
                }
                AudioOutputContract.methodSetProximityMonitoring -> {
                    proximity.setEnabled(call.arguments == true)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app/splash",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "flutterReady" -> {
                    splashFailsafeHandler.removeCallbacks(splashFailsafeRunnable)
                    releaseSplash()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        VoiceNudgeNotifications.ensureChannels(this)
        VoiceNudgeNotifications.cancelStaleChatPiles(this)
        NudgeExpiryTracker.reconcile(this)
        if (BuildConfig.DEBUG) logFirebaseRuntimeConfiguration()
        voiceNudgeChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            VoiceNudgeContract.flutterChannel,
        )
        NudgeActionDispatcher.attach(voiceNudgeChannel)
        NudgeDeliveryResultDispatcher.attach(voiceNudgeChannel)
        NudgeResponseDispatcher.attach(voiceNudgeChannel)
        NudgeReceivedDispatcher.attach(voiceNudgeChannel)
        IncomingNudgeDispatcher.attach(voiceNudgeChannel)
        captureNudgeAction(intent)
        captureChatPileOpen(intent)
        inviteLinkChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            InviteLinkContract.flutterChannel,
        )
        captureInviteLink(intent)
        // Recover an invite code from a Play Store referrer on fresh installs.
        // Must run after captureInviteLink so a direct App Link tap wins.
        InstallReferrerReader.readOnce(this)
        voicePipChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            VoicePipContract.flutterChannel,
        )
        VoicePipActionDispatcher.attach(voicePipChannel)
        VoiceSessionTeardownDispatcher.attach(voicePipChannel)
        attachAudioOutputChannel(flutterEngine)
        voiceOverlayAnnouncer?.shutdown()
        val overlayAnnouncer = VoiceOverlayAnnouncer(this)
        voiceOverlayAnnouncer = overlayAnnouncer
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            VoiceOverlayContract.flutterChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                VoiceOverlayContract.methodAnnounceCallModeTimeout -> {
                    overlayAnnouncer.announceCallModeTimeout()
                    result.success(null)
                }
                VoiceOverlayContract.methodWarmup -> {
                    overlayAnnouncer.warmup()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app.oneone/device_log",
        ).setMethodCallHandler { call, result ->
            DeviceLog.init(this)
            when (call.method) {
                "setIdentity" -> {
                    val arguments = call.arguments as? Map<*, *>
                    DeviceLog.setIdentity(
                        arguments?.get("userId")?.toString(),
                        arguments?.get("groupId")?.toString(),
                    )
                    result.success(null)
                }
                "getDeviceMeta" -> result.success(DeviceLog.deviceMeta())
                "getNetworkMeta" -> result.success(DeviceLog.networkMeta())
                else -> result.notImplemented()
            }
        }
        voicePipChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "setSessionState" -> {
                    val arguments = call.arguments as? Map<*, *>
                    val wasActive = voiceSessionActive
                    voiceSessionActive = arguments?.get("active") == true
                    voiceSessionTalking = arguments?.get("isTalking") == true
                    if (voiceSessionActive) {
                        ActiveVoiceSessionStore.save(
                            this,
                            groupId = arguments?.get("groupId")?.toString(),
                            userId = arguments?.get("userId")?.toString(),
                            deviceId = arguments?.get("deviceId")?.toString(),
                            serviceSessionId = arguments?.get("serviceSessionId")?.toString(),
                            livekitSessionId = arguments?.get("livekitSessionId")?.toString(),
                        )
                    } else {
                        ActiveVoiceSessionStore.clear(this)
                    }
                    val serviceSessionId = arguments?.get("serviceSessionId")?.toString()
                    if (voiceSessionActive && !wasActive) {
                        VoiceSessionService.start(this, serviceSessionId)
                    } else if (!voiceSessionActive && wasActive) {
                        VoiceSessionService.stop(this)
                    }
                    updatePictureInPictureParams()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        voiceNudgeChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                // Keep the channel name for compatibility with existing Dart and
                // database records. New SDKs return the registered Firebase
                // Installation ID rather than a legacy registration token.
                "getFcmToken" -> {
                    Log.i(
                        VoiceNudgeDiagnostics.tag,
                        "[FCM-02] Flutter requested FCM installation registration",
                    )
                    FirebaseMessaging.getInstance().register()
                        .addOnCompleteListener registration@{ registrationTask ->
                            if (!registrationTask.isSuccessful) {
                                VoiceNudgeDiagnostics.logFailure(
                                    "[FCM-E1] FCM installation registration",
                                    registrationTask.exception,
                                )
                                result.error(
                                    "fcm_registration_failed",
                                    registrationTask.exception?.message
                                        ?: "FCM installation registration failed.",
                                    null,
                                )
                                return@registration
                            }

                            Log.i(
                                VoiceNudgeDiagnostics.tag,
                                "[FCM-03] FCM backend registration completed",
                            )
                            FirebaseInstallations.getInstance().id
                                .addOnCompleteListener idLookup@{ idTask ->
                                    val installationId =
                                        if (idTask.isSuccessful) idTask.result else null
                                    if (idTask.isSuccessful && !installationId.isNullOrBlank()) {
                                        Log.i(
                                            VoiceNudgeDiagnostics.tag,
                                            "[FCM-04] Firebase Installation ID resolved " +
                                                VoiceNudgeDiagnostics.describeIdentifier(
                                                    installationId,
                                                ),
                                        )
                                        VoiceNudgeTokenStore.save(this, installationId)
                                        result.success(installationId)
                                        return@idLookup
                                    }

                                    VoiceNudgeDiagnostics.logFailure(
                                        "[FCM-E2] Firebase Installation ID lookup",
                                        idTask.exception,
                                    )
                                    result.error(
                                        "fcm_installation_id_unavailable",
                                        idTask.exception?.message
                                            ?: "Firebase Installation ID is unavailable.",
                                        null,
                                    )
                                }
                        }
                }

                "takePendingNudgeAction" -> {
                    result.success(NudgeActionStore.take(this)?.toMap())
                }

                "listIncomingNudges" -> {
                    result.success(IncomingNudgeStore.list(this))
                }

                "dismissIncomingNudge" -> {
                    val eventId = call.arguments?.toString()
                    if (!eventId.isNullOrBlank()) {
                        // In-app Accept/Decline also uses this path — cancel the
                        // 10-min expiry so it cannot fire after a successful
                        // session (or decline) once the room later goes offline.
                        val batch = RingNudgeBatchStore.batchForEvent(this, eventId)
                        if (batch != null) {
                            for (memberId in batch.eventIds) {
                                NudgeExpiryTracker.cancelExpiry(this, memberId)
                            }
                            NudgeExpiryTracker.cancelExpiry(this, batch.expiryKey)
                            (getSystemService(NOTIFICATION_SERVICE) as android.app.NotificationManager)
                                .cancel(batch.notificationId)
                            RingNudgeBatchStore.clearBatch(this, batch.groupId)
                        } else {
                            NudgeExpiryTracker.cancelExpiry(this, eventId)
                            (getSystemService(NOTIFICATION_SERVICE) as android.app.NotificationManager)
                                .cancel(VoiceNudgeNotifications.idFor(eventId))
                        }
                    }
                    result.success(null)
                }

                "eventIdsSharingNotification" -> {
                    val eventId = call.arguments?.toString()
                    if (eventId.isNullOrBlank()) {
                        result.success(emptyList<String>())
                    } else {
                        val members = RingNudgeBatchStore.memberEventIds(this, eventId)
                        result.success(
                            if (members.isEmpty()) listOf(eventId) else members,
                        )
                    }
                }

                "takePendingChatPileOpen" -> {
                    result.success(ChatPileStore.takeOpened(this))
                }

                "getMediaVolumePercent" -> {
                    result.success(MediaVolume.readPercent(this))
                }

                // B5: Sender schedules a 10-min expiry alarm for a nudge they
                // just sent. Called from Flutter after the backend accepts the
                // send. Cancelled on accept / decline / snooze only.
                "scheduleSenderNudgeExpiry" -> {
                    val args = call.arguments as? Map<*, *> ?: return@setMethodCallHandler
                    val eventId = args["eventId"]?.toString() ?: return@setMethodCallHandler
                    val recipientName = args["recipientName"]?.toString() ?: "Your friend"
                    val recipientUserId = args["recipientUserId"]?.toString() ?: return@setMethodCallHandler
                    NudgeExpiryTracker.scheduleExpiry(
                        context = this,
                        eventId = eventId,
                        senderName = recipientName,
                        recipientUserId = recipientUserId,
                        groupId = null,
                        recipientName = "You (sender)",
                        isSenderSide = true,
                    )
                    Log.i(
                        VoiceNudgeDiagnostics.tag,
                        "[NUDGE-EXPIRY-02] Sender scheduled expiry eventSuffix=${eventId.takeLast(6)}",
                    )
                    result.success(null)
                }

                // Cancel a sender-side expiry alarm — accept / decline / snooze.
                "cancelSenderNudgeExpiry" -> {
                    val eventId = call.arguments?.toString()
                    if (eventId != null) {
                        NudgeExpiryTracker.cancelExpiry(this, eventId)
                    }
                    result.success(null)
                }

                "clearChatPile" -> {
                    val groupId = call.arguments?.toString()
                    if (!groupId.isNullOrBlank()) {
                        VoiceNudgeNotifications.cancelChatPile(this, groupId)
                    }
                    result.success(null)
                }

                "setHapticsIntensity" -> {
                    HapticsPreferenceStore.save(
                        this,
                        call.arguments?.toString().orEmpty(),
                    )
                    result.success(null)
                }

                // Shown by Flutter after a background auto-connect succeeds:
                // the sender's app never came to the foreground, so a shade
                // notification is the only confirmation they get.
                "showYouAreOnlineNotification" -> {
                    val args = call.arguments as? Map<*, *>
                    val groupId = args?.get("groupId")?.toString()
                    val groupName = args?.get("groupName")?.toString()
                    val manager =
                        getSystemService(NOTIFICATION_SERVICE) as android.app.NotificationManager
                    try {
                        manager.notify(
                            VoiceNudgeNotifications.idFor("online_$groupId"),
                            VoiceNudgeNotifications.buildGeneral(
                                this,
                                "🟢 You are online",
                                if (groupName.isNullOrBlank()) {
                                    "You're live together now."
                                } else {
                                    "You're live in $groupName."
                                },
                                groupId,
                            ),
                        )
                        Log.i(
                            VoiceNudgeDiagnostics.tag,
                            "[NUDGE-ACTION-05] posted sender 'you are online' notification " +
                                "groupSuffix=${groupId?.takeLast(6) ?: "none"}",
                        )
                    } catch (error: SecurityException) {
                        VoiceNudgeDiagnostics.logFailure("[NUDGE-E12] Notification permission", error)
                    }
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DuoWidgetSyncContract.flutterChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "syncSnapshot" -> {
                    val args = call.arguments as? Map<*, *>
                    if (args == null) {
                        DuoWidgetLog.w("F-01", "syncSnapshot called with null args")
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    val groups = (args["groups"] as? List<*>).orEmpty().mapNotNull { raw ->
                        val groupMap = raw as? Map<*, *> ?: return@mapNotNull null
                        val groupId = groupMap["groupId"]?.toString() ?: return@mapNotNull null
                        val members = (groupMap["members"] as? List<*>).orEmpty().mapNotNull { rawMember ->
                            val memberMap = rawMember as? Map<*, *> ?: return@mapNotNull null
                            val userId = memberMap["userId"]?.toString() ?: return@mapNotNull null
                            DuoWidgetMember(
                                userId = userId,
                                displayName = memberMap["displayName"]?.toString() ?: "Friend",
                                photoUrl = memberMap["photoUrl"]?.toString()
                                    ?.takeIf { it.isNotBlank() },
                                avatarAsset = memberMap["avatarAsset"]?.toString()
                                    ?.takeIf { it.isNotBlank() },
                                online = memberMap["online"] == true,
                            )
                        }
                        DuoWidgetGroup(
                            groupId = groupId,
                            name = groupMap["name"]?.toString() ?: "Friends",
                            members = members,
                        )
                    }
                    val memberCount = groups.sumOf { it.members.size }
                    val photoCount = groups.sumOf { g ->
                        g.members.count { !it.photoUrl.isNullOrBlank() }
                    }
                    val assetCount = groups.sumOf { g ->
                        g.members.count { !it.avatarAsset.isNullOrBlank() }
                    }
                    DuoWidgetLog.i(
                        "F-02",
                        "syncSnapshot from Flutter groups=${groups.size} " +
                            "members=$memberCount photos=$photoCount assets=$assetCount " +
                            "lastActive=${args["lastActiveGroupId"]?.toString()?.takeLast(6) ?: "none"}",
                    )
                    DuoWidgetSnapshotStore.saveSnapshot(
                        this,
                        userId = args["userId"]?.toString(),
                        apiBaseUrl = args["apiBaseUrl"]?.toString(),
                        accentKey = args["accentKey"]?.toString(),
                        lastActiveGroupId = args["lastActiveGroupId"]?.toString(),
                        groups = groups,
                    )
                    DuoWidgetRenderer.updateAll(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        inviteLinkChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "peekPendingInviteCode" -> {
                    result.success(InviteLinkContract.peekPendingCode(this))
                }
                "clearPendingInviteCode" -> {
                    val code = call.arguments as? String
                    if (code.isNullOrBlank()) {
                        result.error("invalid_invite_code", "Invite code is required.", null)
                    } else {
                        InviteLinkContract.clearPendingCode(this, code)
                        result.success(null)
                    }
                }
                "shareInviteLink" -> {
                    val inviteUrl = call.arguments as? String
                    if (inviteUrl.isNullOrBlank()) {
                        result.error("invalid_invite_url", "Invite URL is required.", null)
                    } else {
                        val shareIntent = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_SUBJECT, "Join my Duo group")
                            putExtra(
                                Intent.EXTRA_TEXT,
                                "Join my group on Duo: $inviteUrl",
                            )
                        }
                        startActivity(Intent.createChooser(shareIntent, "Share group invite"))
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureNudgeAction(intent)
        captureChatPileOpen(intent)
        captureInviteLink(intent)
    }

    override fun onUserLeaveHint() {
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            Build.VERSION.SDK_INT < Build.VERSION_CODES.S &&
            voiceSessionActive &&
            !isInPictureInPictureMode
        ) {
            enterPictureInPictureMode(buildPictureInPictureParams())
        }
        super.onUserLeaveHint()
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        if (::voicePipChannel.isInitialized) {
            voicePipChannel.invokeMethod(
                "onPipModeChanged",
                isInPictureInPictureMode,
            )
        }
    }

    override fun onDestroy() {
        splashFailsafeHandler.removeCallbacks(splashFailsafeRunnable)
        heldSplashView?.remove()
        heldSplashView = null
        if (isFinishing) {
            teardownVoiceSession("activity finishing")
        }
        if (::voiceNudgeChannel.isInitialized) {
            NudgeActionDispatcher.detach(voiceNudgeChannel)
            NudgeDeliveryResultDispatcher.detach(voiceNudgeChannel)
            NudgeResponseDispatcher.detach(voiceNudgeChannel)
            NudgeReceivedDispatcher.detach(voiceNudgeChannel)
            IncomingNudgeDispatcher.detach(voiceNudgeChannel)
        }
        if (::voicePipChannel.isInitialized) {
            VoicePipActionDispatcher.detach(voicePipChannel)
            VoiceSessionTeardownDispatcher.detach(voicePipChannel)
        }
        voiceOverlayAnnouncer?.shutdown()
        voiceOverlayAnnouncer = null
        proximityScreenControl?.setEnabled(false)
        proximityScreenControl = null
        audioOutputMonitor?.stop()
        audioOutputMonitor = null
        audioOutputChannel?.setMethodCallHandler(null)
        audioOutputChannel = null
        super.onDestroy()
    }

    private fun teardownVoiceSession(reason: String) {
        if (!voiceSessionActive) return
        DeviceLog.info("VoiceSessionService", "Requesting LiveKit teardown ($reason)")
        VoiceSessionTeardownDispatcher.requestTeardown()
        VoiceSessionService.stop(this)
        voiceSessionActive = false
    }

    private fun updatePictureInPictureParams() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            setPictureInPictureParams(buildPictureInPictureParams())
        }
    }

    private fun buildPictureInPictureParams(): PictureInPictureParams {
        val builder = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(1, 1))
            .setActions(pictureInPictureActions())
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder
                .setAutoEnterEnabled(voiceSessionActive)
                .setSeamlessResizeEnabled(false)
        }
        return builder.build()
    }

    private fun pictureInPictureActions(): List<RemoteAction> {
        val toggleAction = RemoteAction(
            Icon.createWithResource(
                this,
                if (voiceSessionTalking) R.drawable.ic_mic_off else R.drawable.ic_voice_nudge,
            ),
            if (voiceSessionTalking) "Stop talking" else "Talk",
            if (voiceSessionTalking) "Stop talking" else "Talk",
            pipActionIntent(VoicePipContract.actionToggleMicrophone, 1),
        )
        return listOf(toggleAction)
    }

    private fun pipActionIntent(action: String, requestCode: Int): PendingIntent {
        return PendingIntent.getBroadcast(
            this,
            requestCode,
            Intent(this, VoicePipActionReceiver::class.java).setAction(action),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun captureChatPileOpen(intent: Intent?) {
        if (intent?.action != VoiceNudgeContract.actionOpenChatPile) return
        val groupId = intent.getStringExtra(VoiceNudgeContract.extraGroupId) ?: return
        VoiceNudgeNotifications.cancelChatPile(this, groupId)
        ChatPileStore.markOpened(this, groupId)
        Log.i(
            VoiceNudgeDiagnostics.tag,
            "[FCM-09] Chat pile opened groupSuffix=${groupId.takeLast(6)}",
        )
    }

    private fun captureNudgeAction(intent: Intent?) {
        if (intent == null) return
        // Returning from Recents redelivers the original notification intent.
        // That is not a new Accept/Connect tap — ignore it.
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) {
            return
        }
        val action = when (intent.action) {
            VoiceNudgeContract.actionAccept -> "accept"
            VoiceNudgeContract.actionConnect -> "connect"
            VoiceNudgeContract.actionOpenNudge -> "open"
            else -> return
        }
        val eventId = intent.getStringExtra(VoiceNudgeContract.extraEventId) ?: return
        val groupId = intent.getStringExtra(VoiceNudgeContract.extraGroupId) ?: return
        val senderUserId = intent.getStringExtra(VoiceNudgeContract.extraSenderUserId)
        val notificationId = intent.getIntExtra(
            VoiceNudgeContract.extraNotificationId,
            RingNudgeBatchStore.notificationIdForEvent(this, eventId)
                ?: VoiceNudgeNotifications.idFor(eventId),
        )
        (getSystemService(NOTIFICATION_SERVICE) as android.app.NotificationManager)
            .cancel(notificationId)
        if (action != "open") {
            val batch = RingNudgeBatchStore.batchForEvent(this, eventId)
            VoiceNudgeAudioCache.delete(this, eventId)
            // B5: Cancel the 10-minute expiry alarm since the user took action.
            NudgeExpiryTracker.cancelExpiry(this, eventId)
            IncomingNudgeStore.markStatus(this, eventId, "accepted")
            IncomingNudgeDispatcher.signalStatus(eventId, "accepted")
            if (batch != null) {
                // Cancel the shared ring-batch window; leave sibling members
                // pending so Flutter `_acceptSiblingNudges` can still POST accept.
                for (memberId in batch.eventIds) {
                    if (memberId != eventId) {
                        NudgeExpiryTracker.cancelExpiry(this, memberId)
                    }
                }
                NudgeExpiryTracker.cancelExpiry(this, batch.expiryKey)
                RingNudgeBatchStore.clearBatch(this, batch.groupId)
            }
        }
        NudgeActionStore.save(
            this,
            PendingNudgeAction(action, eventId, groupId, senderUserId),
        )
        NudgeActionDispatcher.signal()
        // Consume the launch intent so a later process recreation / cold
        // start does not re-queue the same Accept/Connect tap and auto-join.
        consumeNudgeActionIntent(intent)
        Log.i(
            VoiceNudgeDiagnostics.tag,
            "[NUDGE-ACTION-02] queued action=$action eventSuffix=${eventId.takeLast(6)}",
        )
    }

    private fun consumeNudgeActionIntent(intent: Intent?) {
        if (intent == null) return
        if (
            intent.action != VoiceNudgeContract.actionAccept &&
            intent.action != VoiceNudgeContract.actionConnect
        ) {
            return
        }
        intent.action = null
        intent.removeExtra(VoiceNudgeContract.extraEventId)
        intent.removeExtra(VoiceNudgeContract.extraGroupId)
        intent.removeExtra(VoiceNudgeContract.extraNotificationId)
        intent.removeExtra(VoiceNudgeContract.extraAction)
        setIntent(intent)
    }

    private fun captureInviteLink(intent: Intent?) {
        if (intent?.action != Intent.ACTION_VIEW) return
        val uri = intent.data ?: return
        val isCustomInvite =
            uri.scheme.equals(InviteLinkContract.customScheme, ignoreCase = true) &&
                uri.host.equals(InviteLinkContract.inviteHost, ignoreCase = true)
        val isHttpsInvite =
            uri.scheme.equals("https", ignoreCase = true) &&
                uri.host.equals(InviteLinkContract.httpsHost, ignoreCase = true) &&
                uri.pathSegments.firstOrNull().equals("invite", ignoreCase = true)
        if (!isCustomInvite && !isHttpsInvite) return
        val codeIndex = if (isCustomInvite) 0 else 1
        val code = uri.pathSegments.getOrNull(codeIndex)
            ?.trim()
            ?.uppercase()
            ?.takeIf { it.matches(Regex("[A-Z0-9_-]{4,64}")) }
            ?: return
        InviteLinkContract.savePendingCode(this, code)
        if (::inviteLinkChannel.isInitialized) {
            inviteLinkChannel.invokeMethod("onInviteLinkAvailable", null)
        }
        Log.i("OneOneInvite", "Invite link captured codeSuffix=${code.takeLast(4)}")
    }

    @Suppress("DEPRECATION")
    private fun logFirebaseRuntimeConfiguration() {
        try {
            val firebaseApp = FirebaseApp.getInstance()
            val options = firebaseApp.options
            val applicationInfo = packageManager.getApplicationInfo(
                packageName,
                PackageManager.GET_META_DATA,
            )
            val installationIdEnabled = applicationInfo.metaData?.getBoolean(
                "firebase_messaging_installation_id_enabled",
                false,
            ) ?: false
            val buildType = if (
                applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE != 0
            ) {
                "debug"
            } else {
                "release"
            }
            val googlePlayServicesVersion = try {
                packageManager.getPackageInfo("com.google.android.gms", 0).versionName
            } catch (_: PackageManager.NameNotFoundException) {
                "missing"
            }

            Log.i(
                VoiceNudgeDiagnostics.tag,
                "[FCM-01] runtime configuration " +
                    "package=$packageName " +
                    "build=$buildType " +
                    "signingSha1=${signingCertificateSha1() ?: "unavailable"} " +
                    "firebaseAppId=${options.applicationId} " +
                    "projectId=${options.projectId} " +
                    "senderId=${options.gcmSenderId} " +
                    "installationIdEnabled=$installationIdEnabled " +
                    "autoInit=${FirebaseMessaging.getInstance().isAutoInitEnabled} " +
                    "googlePlayServices=$googlePlayServicesVersion",
            )
        } catch (error: RuntimeException) {
            VoiceNudgeDiagnostics.logFailure(
                "[FCM-E0] Firebase runtime configuration",
                error,
            )
        }
    }

    @Suppress("DEPRECATION")
    private fun signingCertificateSha1(): String? {
        val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageManager.getPackageInfo(
                packageName,
                PackageManager.GET_SIGNING_CERTIFICATES,
            )
        } else {
            packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
        }
        val signature = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageInfo.signingInfo?.apkContentsSigners?.firstOrNull()
        } else {
            packageInfo.signatures?.firstOrNull()
        } ?: return null
        return MessageDigest.getInstance("SHA-1")
            .digest(signature.toByteArray())
            .joinToString(":") { byte -> "%02X".format(byte) }
    }

    private companion object {
        // Upper bound on how long the native splash can stay up waiting for
        // Flutter — well beyond any realistic boot time, purely a safety
        // net so a bug can never brick the launch screen.
        const val SPLASH_FAILSAFE_TIMEOUT_MS = 8_000L
    }
}
