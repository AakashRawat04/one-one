package app.oneone.one_one_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build

object VoiceNudgeNotifications {
    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(VoiceNudgeContract.notificationChannelId) != null) return

        val channel = NotificationChannel(
            VoiceNudgeContract.notificationChannelId,
            VoiceNudgeContract.notificationChannelName,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Urgent rings and short voice messages from your groups"
            enableVibration(true)
            setSound(null, null)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        manager.createNotificationChannel(channel)
    }

    fun build(
        context: Context,
        senderName: String,
        status: String,
        ongoing: Boolean,
    ): Notification {
        ensureChannel(context)
        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentIntent = PendingIntent.getActivity(
            context,
            7001,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, VoiceNudgeContract.notificationChannelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        return builder
            .setSmallIcon(R.drawable.ic_voice_nudge)
            .setContentTitle("$senderName nudged you")
            .setContentText(status)
            .setColor(Color.rgb(248, 190, 3))
            .setCategory(Notification.CATEGORY_MESSAGE)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setPriority(Notification.PRIORITY_HIGH)
            .setContentIntent(contentIntent)
            .setOngoing(ongoing)
            .setAutoCancel(!ongoing)
            .build()
    }

    fun idFor(eventId: String): Int = eventId.hashCode() and 0x7fffffff
}
