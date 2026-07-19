package app.oneone.one_one_app

import android.content.Context
import android.util.Log

object VoiceNudgeContract {
    const val flutterChannel = "app.oneone/voice_nudge"
    const val notificationChannelId = "voice_nudges"
    const val notificationChannelName = "Voice nudges"
    const val generalNotificationChannelId = "walkie_alerts_v2"
    const val generalNotificationChannelName = "One One alerts"

    const val extraKind = "kind"
    const val extraEventId = "eventId"
    const val extraSenderName = "senderName"
    const val extraDurationMs = "durationMs"
    const val extraAudioUrl = "audioUrl"
    const val extraAckUrl = "ackUrl"
    const val extraDeliveryToken = "deliveryToken"
    const val extraGroupId = "groupId"
    const val extraResponseUrl = "responseUrl"
    const val extraAction = "nudgeAction"
    const val extraNotificationId = "notificationId"
    const val extraSnoozeMinutes = "snoozeMinutes"

    const val kindVoice = "voice_nudge"
    const val kindRing = "ring_nudge"
    const val kindPush = "nudge"
    const val kindFriendLive = "friend_live"
    const val kindResponse = "nudge_response"

    const val actionAccept = "app.oneone.action.ACCEPT_NUDGE"
    const val actionConnect = "app.oneone.action.CONNECT_NUDGE"
    const val actionDecline = "app.oneone.action.DECLINE_NUDGE"
    const val actionSnooze = "app.oneone.action.SNOOZE_NUDGE"
}

object VoiceNudgeTokenStore {
    private const val preferencesName = "one_one_voice_nudge"
    private const val tokenKey = "fcm_token"

    fun save(context: Context, token: String) {
        context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
            .edit()
            .putString(tokenKey, token)
            .apply()
        Log.i(
            VoiceNudgeDiagnostics.tag,
            "[FCM-05] Registered identifier saved locally " +
                VoiceNudgeDiagnostics.describeIdentifier(token),
        )
    }
}

object VoiceNudgeDiagnostics {
    const val tag = "OneOneFCM"

    fun describeIdentifier(value: String): String =
        "length=${value.length} suffix=${value.takeLast(6)}"

    fun logFailure(checkpoint: String, error: Throwable?) {
        if (error == null) {
            Log.e(tag, "$checkpoint failed without an exception")
            return
        }

        Log.e(tag, "$checkpoint ${error.javaClass.name}: ${error.message}", error)
        var cause = error.cause
        var depth = 1
        while (cause != null && cause !== error && depth <= 6) {
            Log.e(
                tag,
                "$checkpoint cause[$depth]=${cause.javaClass.name}: ${cause.message}",
            )
            cause = cause.cause
            depth += 1
        }
    }
}
