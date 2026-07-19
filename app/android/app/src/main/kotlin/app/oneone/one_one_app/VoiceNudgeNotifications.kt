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
    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(VoiceNudgeContract.notificationChannelId) == null) {
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
        if (
            manager.getNotificationChannel(VoiceNudgeContract.generalNotificationChannelId) == null
        ) {
            val channel = NotificationChannel(
                VoiceNudgeContract.generalNotificationChannelId,
                VoiceNudgeContract.generalNotificationChannelName,
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Nudges and activity from your One One groups"
                enableVibration(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            manager.createNotificationChannel(channel)
        }
    }

    fun build(
        context: Context,
        eventId: String,
        groupId: String,
        responseUrl: String?,
        senderName: String,
        status: String,
        ongoing: Boolean,
    ): Notification {
        ensureChannels(context)
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
            .addNudgeActions(
                context = context,
                eventId = eventId,
                groupId = groupId,
                responseUrl = responseUrl,
                senderName = senderName,
            )
            .build()
    }

    fun buildActionable(
        context: Context,
        eventId: String,
        groupId: String,
        responseUrl: String?,
        senderName: String,
        title: String,
        body: String,
    ): Notification {
        ensureChannels(context)
        val notificationId = idFor(eventId)
        val openIntent = acceptIntent(context, eventId, groupId, notificationId)
        val contentIntent = PendingIntent.getActivity(
            context,
            requestCode(eventId, "open"),
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, VoiceNudgeContract.generalNotificationChannelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        return builder
            .setSmallIcon(R.drawable.ic_voice_nudge)
            .setContentTitle(title)
            .setContentText(body)
            .setColor(Color.rgb(248, 190, 3))
            .setCategory(Notification.CATEGORY_MESSAGE)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setPriority(Notification.PRIORITY_HIGH)
            .setContentIntent(contentIntent)
            .setAutoCancel(true)
            .addNudgeActions(
                context = context,
                eventId = eventId,
                groupId = groupId,
                responseUrl = responseUrl,
                senderName = senderName,
            )
            .build()
    }

    fun buildResponse(
        context: Context,
        eventId: String,
        groupId: String,
        responderName: String,
        responseAction: String,
    ): Notification {
        ensureChannels(context)
        val accepted = responseAction == "accept"
        val body = when (responseAction) {
            "accept" -> "Tap Connect to join together"
            "snooze" -> "They asked you to wait 5 minutes"
            else -> "They can’t join right now"
        }
        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            if (accepted) {
                action = VoiceNudgeContract.actionConnect
                putExtra(VoiceNudgeContract.extraEventId, eventId)
                putExtra(VoiceNudgeContract.extraGroupId, groupId)
                putExtra(VoiceNudgeContract.extraNotificationId, idFor(eventId))
            }
        }
        val contentIntent = PendingIntent.getActivity(
            context,
            requestCode(eventId, "response"),
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, VoiceNudgeContract.generalNotificationChannelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        builder
            .setSmallIcon(R.drawable.ic_voice_nudge)
            .setContentTitle("$responderName answered your nudge")
            .setContentText(body)
            .setColor(Color.rgb(248, 190, 3))
            .setCategory(Notification.CATEGORY_SOCIAL)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setPriority(Notification.PRIORITY_HIGH)
            .setContentIntent(contentIntent)
            .setAutoCancel(true)
        if (accepted) {
            builder.addAction(
                Notification.Action.Builder(0, "Connect", contentIntent).build(),
            )
        }
        return builder.build()
    }

    fun buildGeneral(
        context: Context,
        title: String,
        body: String,
    ): Notification {
        ensureChannels(context)
        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentIntent = PendingIntent.getActivity(
            context,
            7002,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, VoiceNudgeContract.generalNotificationChannelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        return builder
            .setSmallIcon(R.drawable.ic_voice_nudge)
            .setContentTitle(title)
            .setContentText(body)
            .setColor(Color.rgb(248, 190, 3))
            .setCategory(Notification.CATEGORY_SOCIAL)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setPriority(Notification.PRIORITY_HIGH)
            .setContentIntent(contentIntent)
            .setAutoCancel(true)
            .build()
    }

    fun idFor(eventId: String): Int = eventId.hashCode() and 0x7fffffff

    private fun Notification.Builder.addNudgeActions(
        context: Context,
        eventId: String,
        groupId: String,
        responseUrl: String?,
        senderName: String,
    ): Notification.Builder {
        if (responseUrl.isNullOrBlank()) return this
        val notificationId = idFor(eventId)
        val acceptPendingIntent = PendingIntent.getActivity(
            context,
            requestCode(eventId, "accept"),
            acceptIntent(context, eventId, groupId, notificationId),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val declinePendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode(eventId, "decline"),
            responseIntent(
                context,
                VoiceNudgeContract.actionDecline,
                eventId,
                responseUrl,
                senderName,
                notificationId,
            ),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val snoozePendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode(eventId, "snooze"),
            responseIntent(
                context,
                VoiceNudgeContract.actionSnooze,
                eventId,
                responseUrl,
                senderName,
                notificationId,
            ),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return addAction(Notification.Action.Builder(0, "Accept", acceptPendingIntent).build())
            .addAction(Notification.Action.Builder(0, "Busy 5 min", snoozePendingIntent).build())
            .addAction(Notification.Action.Builder(0, "Decline", declinePendingIntent).build())
    }

    private fun acceptIntent(
        context: Context,
        eventId: String,
        groupId: String,
        notificationId: Int,
    ) = Intent(context, MainActivity::class.java).apply {
        action = VoiceNudgeContract.actionAccept
        flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        putExtra(VoiceNudgeContract.extraEventId, eventId)
        putExtra(VoiceNudgeContract.extraGroupId, groupId)
        putExtra(VoiceNudgeContract.extraNotificationId, notificationId)
    }

    private fun responseIntent(
        context: Context,
        actionName: String,
        eventId: String,
        responseUrl: String,
        senderName: String,
        notificationId: Int,
    ) = Intent(context, NudgeNotificationActionReceiver::class.java).apply {
        action = actionName
        putExtra(VoiceNudgeContract.extraEventId, eventId)
        putExtra(VoiceNudgeContract.extraResponseUrl, responseUrl)
        putExtra(VoiceNudgeContract.extraSenderName, senderName)
        putExtra(VoiceNudgeContract.extraNotificationId, notificationId)
    }

    private fun requestCode(eventId: String, action: String): Int =
        "$eventId:$action".hashCode() and 0x7fffffff
}
