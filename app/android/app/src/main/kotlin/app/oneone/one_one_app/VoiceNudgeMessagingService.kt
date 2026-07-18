package app.oneone.one_one_app

import android.content.Intent
import android.os.Build
import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class VoiceNudgeMessagingService : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        VoiceNudgeTokenStore.save(this, token)
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        val kind = data["type"] ?: return
        if (kind != VoiceNudgeContract.kindVoice && kind != VoiceNudgeContract.kindRing) return

        val eventId = data["eventId"] ?: return
        val senderName = data["senderName"]?.take(80).orEmpty().ifBlank { "Someone" }
        val durationMs = data["durationMs"]?.toLongOrNull()?.coerceIn(250L, 10_000L) ?: return
        if (kind == VoiceNudgeContract.kindVoice && isExpired(data["expiresAt"])) return

        val intent = Intent(this, VoiceNudgePlaybackService::class.java).apply {
            putExtra(VoiceNudgeContract.extraKind, kind)
            putExtra(VoiceNudgeContract.extraEventId, eventId)
            putExtra(VoiceNudgeContract.extraSenderName, senderName)
            putExtra(VoiceNudgeContract.extraDurationMs, durationMs)
            putExtra(VoiceNudgeContract.extraAudioUrl, data["audioUrl"])
            putExtra(VoiceNudgeContract.extraAckUrl, data["ackUrl"])
            putExtra(VoiceNudgeContract.extraDeliveryToken, data["deliveryToken"])
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (error: RuntimeException) {
            Log.e("VoiceNudge", "Unable to start voice nudge playback", error)
            val manager = getSystemService(NOTIFICATION_SERVICE) as android.app.NotificationManager
            manager.notify(
                VoiceNudgeNotifications.idFor(eventId),
                VoiceNudgeNotifications.build(
                    this,
                    senderName,
                    "Tap to open this nudge",
                    ongoing = false,
                ),
            )
        }
    }

    private fun isExpired(rawExpiry: String?): Boolean {
        val expiresAtSeconds = rawExpiry?.toLongOrNull() ?: return true
        return System.currentTimeMillis() / 1000 >= expiresAtSeconds
    }
}
