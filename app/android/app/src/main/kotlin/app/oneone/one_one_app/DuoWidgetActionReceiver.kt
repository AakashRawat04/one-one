package app.oneone.one_one_app

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.widget.Toast
import java.util.concurrent.ConcurrentHashMap

/**
 * Handles every tappable action on the Duo home-screen widget. Actions that
 * hit the network run on [DuoWidgetApi]'s background executor via
 * [android.content.BroadcastReceiver.goAsync] so onReceive can return
 * immediately without blocking the widget host.
 */
class DuoWidgetActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val appWidgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        )
        val groupId = intent.getStringExtra(extraGroupId)
        val appContext = context.applicationContext
        DuoWidgetLog.i(
            "A-00",
            "action=${intent.action} widgetId=$appWidgetId " +
                "groupIdSuffix=${groupId?.takeLast(6) ?: "none"}",
        )
        when (intent.action) {
            actionNextGroup -> {
                if (appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                    DuoWidgetSnapshotStore.cycleNextGroup(appContext, appWidgetId)
                    DuoWidgetRenderer.updateWidget(
                        appContext,
                        AppWidgetManager.getInstance(appContext),
                        appWidgetId,
                    )
                }
            }

            actionRing -> {
                if (groupId.isNullOrBlank()) {
                    DuoWidgetLog.w("A-10", "RING ignored — blank groupId")
                    return
                }
                DuoWidgetActionFeedback.show(
                    appContext,
                    groupId,
                    DuoWidgetActionFeedback.Kind.RINGING,
                )
                val pendingResult = goAsync()
                DuoWidgetApi.submit {
                    try {
                        DuoWidgetLog.i("A-11", "RING sending groupSuffix=${groupId.takeLast(6)}")
                        val result = DuoWidgetApi.sendRing(appContext, groupId)
                        onNetworkResult(appContext, result, "Ring sent", "Couldn't send ring nudge")
                    } finally {
                        pendingResult.finish()
                    }
                }
            }

            actionNotify -> {
                if (groupId.isNullOrBlank()) {
                    DuoWidgetLog.w("A-20", "NOTIFY ignored — blank groupId")
                    return
                }
                if (isOnCooldown(groupId)) {
                    DuoWidgetLog.w("A-22", "NOTIFY throttled groupSuffix=${groupId.takeLast(6)}")
                    Handler(Looper.getMainLooper()).post {
                        Toast.makeText(appContext, "Already notified — try again in a bit", Toast.LENGTH_SHORT).show()
                    }
                    return
                }
                DuoWidgetActionFeedback.show(
                    appContext,
                    groupId,
                    DuoWidgetActionFeedback.Kind.NOTIFIED,
                )
                val pendingResult = goAsync()
                DuoWidgetApi.submit {
                    try {
                        DuoWidgetLog.i("A-21", "NOTIFY sending groupSuffix=${groupId.takeLast(6)}")
                        val result = DuoWidgetApi.sendPush(appContext, groupId)
                        onNetworkResult(appContext, result, "Notification sent", "Couldn't send notification")
                    } finally {
                        pendingResult.finish()
                    }
                }
            }

            actionAccept -> {
                if (groupId.isNullOrBlank()) {
                    DuoWidgetLog.w("A-30", "ACCEPT ignored — blank groupId")
                    return
                }
                val pending = IncomingNudgeStore.pendingForGroup(appContext, groupId)
                DuoWidgetLog.i(
                    "A-31",
                    "ACCEPT pendingEvent=${pending?.get("eventId")?.takeLast(6) ?: "none"}",
                )
                val eventId = pending?.get("eventId")
                if (eventId != null) {
                    NudgeExpiryTracker.cancelExpiry(appContext, eventId)
                    IncomingNudgeStore.markStatus(appContext, eventId, "accepted")
                    IncomingNudgeDispatcher.signalStatus(eventId, "accepted")
                }
                DuoWidgetActionFeedback.show(
                    appContext,
                    groupId,
                    DuoWidgetActionFeedback.Kind.JOINING,
                )
                val senderUserId = pending?.get("senderUserId")
                val notificationId = eventId?.let { VoiceNudgeNotifications.idFor(it) }
                val openIntent = Intent(appContext, MainActivity::class.java).apply {
                    action = VoiceNudgeContract.actionAccept
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    putExtra(VoiceNudgeContract.extraEventId, eventId ?: "")
                    putExtra(VoiceNudgeContract.extraGroupId, groupId)
                    if (!senderUserId.isNullOrBlank()) {
                        putExtra(VoiceNudgeContract.extraSenderUserId, senderUserId)
                    }
                    if (notificationId != null) {
                        putExtra(VoiceNudgeContract.extraNotificationId, notificationId)
                    }
                }
                appContext.startActivity(openIntent)
                if (appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                    DuoWidgetRenderer.updateWidget(
                        appContext,
                        AppWidgetManager.getInstance(appContext),
                        appWidgetId,
                    )
                }
            }

            actionDecline -> {
                if (groupId.isNullOrBlank()) {
                    DuoWidgetLog.w("A-40", "DECLINE ignored — blank groupId")
                    return
                }
                val pending = IncomingNudgeStore.pendingForGroup(appContext, groupId)
                val eventId = pending?.get("eventId")
                val responseUrl = intent.getStringExtra(extraResponseUrl)
                    ?: pending?.get("responseUrl")
                DuoWidgetLog.i(
                    "A-41",
                    "DECLINE event=${eventId?.takeLast(6) ?: "none"} " +
                        "hasResponseUrl=${!responseUrl.isNullOrBlank()}",
                )
                if (eventId != null) {
                    NudgeExpiryTracker.cancelExpiry(appContext, eventId)
                    IncomingNudgeStore.markStatus(appContext, eventId, "declined")
                    IncomingNudgeDispatcher.signalStatus(eventId, "declined")
                }
                DuoWidgetActionFeedback.show(
                    appContext,
                    groupId,
                    DuoWidgetActionFeedback.Kind.DECLINED,
                )
                if (responseUrl.isNullOrBlank()) {
                    refreshWidget(appContext, appWidgetId)
                    return
                }
                val pendingResult = goAsync()
                DuoWidgetApi.submit {
                    try {
                        val result = DuoWidgetApi.respond(appContext, responseUrl, "decline")
                        onNetworkResult(appContext, result, "Declined", "Couldn't send response")
                    } finally {
                        pendingResult.finish()
                    }
                }
            }

            actionOpenMic -> {
                if (groupId.isNullOrBlank()) {
                    DuoWidgetLog.w("A-50", "OPEN_MIC ignored — blank groupId")
                    return
                }
                DuoWidgetLog.i("A-51", "OPEN_MIC groupSuffix=${groupId.takeLast(6)}")
                val micIntent = Intent(appContext, QuickRecordActivity::class.java).apply {
                    putExtra(QuickRecordActivity.extraGroupId, groupId)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                appContext.startActivity(micIntent)
            }

            else -> DuoWidgetLog.w("A-99", "unhandled action=${intent.action}")
        }
    }

    private fun onNetworkResult(
        context: Context,
        result: DuoWidgetApiResult,
        successMessage: String,
        failureMessage: String,
    ) {
        when (result) {
            is DuoWidgetApiResult.Success ->
                DuoWidgetLog.i("A-80", "network OK — $successMessage")
            is DuoWidgetApiResult.Failure ->
                DuoWidgetLog.e("A-81", "network FAIL — $failureMessage: ${result.message}")
        }
        val text = when (result) {
            is DuoWidgetApiResult.Success -> successMessage
            is DuoWidgetApiResult.Failure -> "$failureMessage: ${result.message}"
        }
        Handler(Looper.getMainLooper()).post {
            Toast.makeText(context, text, Toast.LENGTH_SHORT).show()
        }
        DuoWidgetRenderer.updateAll(context)
    }

    private fun refreshWidget(context: Context, appWidgetId: Int) {
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            DuoWidgetRenderer.updateAll(context)
        } else {
            DuoWidgetRenderer.updateWidget(
                context,
                AppWidgetManager.getInstance(context),
                appWidgetId,
            )
        }
    }

    companion object {
        const val actionRing = "app.oneone.action.WIDGET_RING"
        const val actionNotify = "app.oneone.action.WIDGET_NOTIFY"
        const val actionAccept = "app.oneone.action.WIDGET_ACCEPT"
        const val actionDecline = "app.oneone.action.WIDGET_DECLINE"
        const val actionNextGroup = "app.oneone.action.WIDGET_NEXT_GROUP"
        const val actionOpenMic = "app.oneone.action.WIDGET_OPEN_MIC"

        const val extraGroupId = "widget_group_id"
        const val extraResponseUrl = "widget_response_url"

        /** Per-group cooldown so a rapid-tap message icon can't 429 the backend. */
        private const val notifyCooldownMs = 15_000L
        private val lastNotifyAtMs = ConcurrentHashMap<String, Long>()

        private fun isOnCooldown(groupId: String): Boolean {
            val now = System.currentTimeMillis()
            val last = lastNotifyAtMs[groupId]
            if (last != null && now - last < notifyCooldownMs) return true
            lastNotifyAtMs[groupId] = now
            return false
        }
    }
}
