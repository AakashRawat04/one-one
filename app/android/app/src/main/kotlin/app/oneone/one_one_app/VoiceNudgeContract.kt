package app.oneone.one_one_app

import android.content.Context

object VoiceNudgeContract {
    const val flutterChannel = "app.oneone/voice_nudge"
    const val notificationChannelId = "voice_nudges"
    const val notificationChannelName = "Voice nudges"

    const val extraKind = "kind"
    const val extraEventId = "eventId"
    const val extraSenderName = "senderName"
    const val extraDurationMs = "durationMs"
    const val extraAudioUrl = "audioUrl"
    const val extraAckUrl = "ackUrl"
    const val extraDeliveryToken = "deliveryToken"

    const val kindVoice = "voice_nudge"
    const val kindRing = "ring_nudge"
}

object VoiceNudgeTokenStore {
    private const val preferencesName = "one_one_voice_nudge"
    private const val tokenKey = "fcm_token"

    fun save(context: Context, token: String) {
        context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
            .edit()
            .putString(tokenKey, token)
            .apply()
    }
}
