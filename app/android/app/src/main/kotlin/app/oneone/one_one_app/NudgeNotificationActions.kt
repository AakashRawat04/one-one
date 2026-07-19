package app.oneone.one_one_app

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.firebase.auth.FirebaseAuth
import io.flutter.plugin.common.MethodChannel
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

data class PendingNudgeAction(
    val action: String,
    val eventId: String,
    val groupId: String,
) {
    fun toMap(): Map<String, String> = mapOf(
        "action" to action,
        "eventId" to eventId,
        "groupId" to groupId,
    )
}

object NudgeActionStore {
    private const val preferencesName = "one_one_nudge_actions"
    private const val actionKey = "action"
    private const val eventIdKey = "event_id"
    private const val groupIdKey = "group_id"

    fun save(context: Context, action: PendingNudgeAction) {
        context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
            .edit()
            .putString(actionKey, action.action)
            .putString(eventIdKey, action.eventId)
            .putString(groupIdKey, action.groupId)
            .apply()
    }

    fun take(context: Context): PendingNudgeAction? {
        val preferences = context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
        val action = preferences.getString(actionKey, null) ?: return null
        val eventId = preferences.getString(eventIdKey, null) ?: return null
        val groupId = preferences.getString(groupIdKey, null) ?: return null
        preferences.edit().clear().apply()
        return PendingNudgeAction(action, eventId, groupId)
    }
}

object NudgeActionDispatcher {
    @Volatile
    private var channel: MethodChannel? = null

    fun attach(methodChannel: MethodChannel) {
        channel = methodChannel
    }

    fun detach(methodChannel: MethodChannel) {
        if (channel === methodChannel) channel = null
    }

    fun signal() {
        Handler(Looper.getMainLooper()).post {
            channel?.invokeMethod("onNudgeActionAvailable", null)
        }
    }

    fun signalRegistrationRenewed() {
        Handler(Looper.getMainLooper()).post {
            channel?.invokeMethod("onFcmRegistrationRenewed", null)
        }
    }
}

class NudgeNotificationActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val responseAction = when (intent.action) {
            VoiceNudgeContract.actionDecline -> "decline"
            VoiceNudgeContract.actionSnooze -> "snooze"
            else -> return
        }
        val responseUrl = intent.getStringExtra(VoiceNudgeContract.extraResponseUrl) ?: return
        val eventId = intent.getStringExtra(VoiceNudgeContract.extraEventId) ?: return
        val senderName = intent.getStringExtra(VoiceNudgeContract.extraSenderName) ?: "Friend"
        val notificationId = intent.getIntExtra(
            VoiceNudgeContract.extraNotificationId,
            VoiceNudgeNotifications.idFor(eventId),
        )
        val pendingResult = goAsync()
        val appContext = context.applicationContext
        val user = FirebaseAuth.getInstance().currentUser
        if (user == null) {
            Log.w(VoiceNudgeDiagnostics.tag, "[NUDGE-ACTION-W1] No signed-in Firebase user")
            pendingResult.finish()
            return
        }

        user.getIdToken(false).addOnCompleteListener { tokenTask ->
            val idToken = if (tokenTask.isSuccessful) tokenTask.result?.token else null
            if (idToken.isNullOrBlank()) {
                VoiceNudgeDiagnostics.logFailure(
                    "[NUDGE-ACTION-E1] Firebase ID token",
                    tokenTask.exception,
                )
                pendingResult.finish()
                return@addOnCompleteListener
            }
            executor.execute {
                try {
                    postResponse(responseUrl, idToken, responseAction)
                    val text = if (responseAction == "snooze") {
                        "You asked $senderName to wait 5 minutes"
                    } else {
                        "You declined $senderName's nudge"
                    }
                    val manager = appContext.getSystemService(NotificationManager::class.java)
                    manager.notify(
                        notificationId,
                        VoiceNudgeNotifications.buildGeneral(
                            appContext,
                            "Nudge answered",
                            text,
                        ),
                    )
                    Log.i(
                        VoiceNudgeDiagnostics.tag,
                        "[NUDGE-ACTION-01] response=$responseAction eventSuffix=${eventId.takeLast(6)}",
                    )
                } catch (error: Exception) {
                    VoiceNudgeDiagnostics.logFailure("[NUDGE-ACTION-E2] Response upload", error)
                } finally {
                    pendingResult.finish()
                }
            }
        }
    }

    private fun postResponse(responseUrl: String, idToken: String, action: String) {
        val connection = URL(responseUrl).openConnection() as HttpURLConnection
        try {
            connection.connectTimeout = 8_000
            connection.readTimeout = 8_000
            connection.requestMethod = "POST"
            connection.doOutput = true
            connection.setRequestProperty("authorization", "Bearer $idToken")
            connection.setRequestProperty("content-type", "application/json")
            connection.outputStream.use {
                it.write("{\"action\":\"$action\"}".toByteArray())
            }
            val responseCode = connection.responseCode
            if (responseCode !in 200..299) {
                throw IllegalStateException("Nudge response failed with HTTP $responseCode")
            }
        } finally {
            connection.disconnect()
        }
    }

    companion object {
        private val executor = Executors.newCachedThreadPool()
    }
}
