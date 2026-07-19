package app.oneone.one_one_app

import android.content.Intent
import android.os.Build
import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class VoiceNudgeMessagingService : FirebaseMessagingService() {
    override fun onRegistered(installationId: String) {
        Log.i(
            VoiceNudgeDiagnostics.tag,
            "[FCM-06] onRegistered callback " +
                VoiceNudgeDiagnostics.describeIdentifier(installationId),
        )
        VoiceNudgeTokenStore.save(this, installationId)
        NudgeActionDispatcher.signalRegistrationRenewed()
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        Log.i(
            VoiceNudgeDiagnostics.tag,
            "[FCM-07] Message received id=${message.messageId ?: "none"} " +
                "keys=${data.keys.sorted().joinToString(",")}",
        )
        val kind = data["type"]
        if (kind == null) {
            Log.w(VoiceNudgeDiagnostics.tag, "[FCM-W1] Ignored message without type")
            return
        }
        when (kind) {
            VoiceNudgeContract.kindPush -> {
                showActionableNotification(message)
                return
            }
            VoiceNudgeContract.kindFriendLive -> {
                showForegroundNotification(message, kind)
                return
            }
            VoiceNudgeContract.kindResponse -> {
                showNudgeResponse(message)
                return
            }
            VoiceNudgeContract.kindVoice,
            VoiceNudgeContract.kindRing -> Unit
            else -> {
                Log.w(VoiceNudgeDiagnostics.tag, "[FCM-W2] Ignored unknown message type=$kind")
                return
            }
        }

        val eventId = data["eventId"]
        if (eventId == null) {
            Log.w(VoiceNudgeDiagnostics.tag, "[FCM-W3] Ignored $kind without eventId")
            return
        }
        val groupId = data["groupId"]?.takeIf { it.isNotBlank() }
        if (groupId == null) {
            Log.w(VoiceNudgeDiagnostics.tag, "[FCM-W10] Ignored $kind without groupId")
            return
        }
        val senderName = data["senderName"]?.take(80).orEmpty().ifBlank { "Someone" }
        val durationMs = data["durationMs"]?.toLongOrNull()?.coerceIn(250L, 10_000L)
        if (durationMs == null) {
            Log.w(VoiceNudgeDiagnostics.tag, "[FCM-W4] Ignored $kind with invalid duration")
            return
        }
        if (kind == VoiceNudgeContract.kindVoice && isExpired(data["expiresAt"])) {
            Log.w(VoiceNudgeDiagnostics.tag, "[FCM-W5] Ignored expired voice nudge")
            return
        }

        val intent = Intent(this, VoiceNudgePlaybackService::class.java).apply {
            putExtra(VoiceNudgeContract.extraKind, kind)
            putExtra(VoiceNudgeContract.extraEventId, eventId)
            putExtra(VoiceNudgeContract.extraSenderName, senderName)
            putExtra(VoiceNudgeContract.extraDurationMs, durationMs)
            putExtra(VoiceNudgeContract.extraAudioUrl, data["audioUrl"])
            putExtra(VoiceNudgeContract.extraAckUrl, data["ackUrl"])
            putExtra(VoiceNudgeContract.extraDeliveryToken, data["deliveryToken"])
            putExtra(VoiceNudgeContract.extraGroupId, groupId)
            putExtra(VoiceNudgeContract.extraResponseUrl, data["responseUrl"])
        }

        try {
            Log.i(
                VoiceNudgeDiagnostics.tag,
                "[FCM-09] Starting native playback kind=$kind eventSuffix=${eventId.takeLast(6)}",
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (error: RuntimeException) {
            VoiceNudgeDiagnostics.logFailure("[FCM-E3] Native playback start", error)
            val manager = getSystemService(NOTIFICATION_SERVICE) as android.app.NotificationManager
            manager.notify(
                VoiceNudgeNotifications.idFor(eventId),
                VoiceNudgeNotifications.build(
                    this,
                    eventId,
                    groupId,
                    data["responseUrl"],
                    senderName,
                    "Tap to open this nudge",
                    ongoing = false,
                ),
            )
        }
    }

    override fun onDeletedMessages() {
        Log.w(
            VoiceNudgeDiagnostics.tag,
            "[FCM-W7] FCM deleted pending messages before delivery",
        )
    }

    private fun showForegroundNotification(message: RemoteMessage, kind: String) {
        val senderName = message.data["senderName"]?.take(80).orEmpty().ifBlank { "Someone" }
        val fallbackTitle = if (kind == VoiceNudgeContract.kindFriendLive) {
            "$senderName is live"
        } else {
            "$senderName nudged you"
        }
        val fallbackBody = if (kind == VoiceNudgeContract.kindFriendLive) {
            "Tap to open One One"
        } else {
            "Come online on One One"
        }
        val manager = getSystemService(NOTIFICATION_SERVICE) as android.app.NotificationManager
        val notificationKey = message.messageId ?: "${kind}_${message.sentTime}"
        manager.notify(
            VoiceNudgeNotifications.idFor(notificationKey),
            VoiceNudgeNotifications.buildGeneral(
                this,
                message.notification?.title ?: fallbackTitle,
                message.notification?.body ?: fallbackBody,
            ),
        )
        Log.i(
            VoiceNudgeDiagnostics.tag,
            "[FCM-08] Foreground notification displayed type=$kind",
        )
    }

    private fun showActionableNotification(message: RemoteMessage) {
        val data = message.data
        val eventId = data["eventId"] ?: run {
            Log.w(VoiceNudgeDiagnostics.tag, "[FCM-W8] Push nudge has no eventId")
            return
        }
        val groupId = data["groupId"] ?: run {
            Log.w(VoiceNudgeDiagnostics.tag, "[FCM-W9] Push nudge has no groupId")
            return
        }
        val senderName = data["senderName"]?.take(80).orEmpty().ifBlank { "Someone" }
        val manager = getSystemService(NOTIFICATION_SERVICE) as android.app.NotificationManager
        manager.notify(
            VoiceNudgeNotifications.idFor(eventId),
            VoiceNudgeNotifications.buildActionable(
                this,
                eventId,
                groupId,
                data["responseUrl"],
                senderName,
                "$senderName nudged you",
                "Accept, wait 5 minutes, or decline",
            ),
        )
        Log.i(VoiceNudgeDiagnostics.tag, "[FCM-08] Actionable push notification displayed")
    }

    private fun showNudgeResponse(message: RemoteMessage) {
        val data = message.data
        val eventId = data["eventId"] ?: return
        val groupId = data["groupId"] ?: return
        val responseAction = data["responseAction"] ?: return
        val responderName = data["responderName"]?.take(80).orEmpty().ifBlank { "Your friend" }
        if (responseAction == "accept") {
            NudgeActionStore.save(
                this,
                PendingNudgeAction("connect", eventId, groupId),
            )
            NudgeActionDispatcher.signal()
        }
        val manager = getSystemService(NOTIFICATION_SERVICE) as android.app.NotificationManager
        manager.notify(
            VoiceNudgeNotifications.idFor(eventId),
            VoiceNudgeNotifications.buildResponse(
                this,
                eventId,
                groupId,
                responderName,
                responseAction,
            ),
        )
        Log.i(
            VoiceNudgeDiagnostics.tag,
            "[NUDGE-ACTION-03] sender received response=$responseAction",
        )
    }

    private fun isExpired(rawExpiry: String?): Boolean {
        val expiresAtSeconds = rawExpiry?.toLongOrNull() ?: return true
        return System.currentTimeMillis() / 1000 >= expiresAtSeconds
    }
}
