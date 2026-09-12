package app.oneone.one_one_app

import java.time.Instant

const val FCM_HANDLING_FAILURE_REASON = "fcm_notification_handling_failure"

const val FCM_USER_DELIVERY_FAILURE =
    "Couldn't deliver notification."

private val checkpointCode = Regex(
    """\[OneOneFCM\]""" +
        """|[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)*-[WE]\d+""" +
        """|\[(?:FCM|DART|NUDGE)[^\]]*\]""" +
        """|walkie_alerts(?:_v\d+)?""" +
        """|\bvoice_nudges\b""",
    RegexOption.IGNORE_CASE,
)

private val workerPhrase = Regex(
    """\bW\d+\b(?:\s*(?:and|/|,)\s*\bW\d+\b)*.{0,40}""" +
        """(?:notification|handling|worker|checkpoint|FCM)""" +
        """|(?:notification|handling|worker|checkpoint|FCM).{0,40}\bW\d+\b""",
    RegexOption.IGNORE_CASE,
)

internal fun containsInternalFcmIdentifier(text: String): Boolean =
    checkpointCode.containsMatchIn(text) || workerPhrase.containsMatchIn(text)

internal fun sanitizeNotificationCopy(text: String, fallback: String): String =
    if (text.isBlank() || containsInternalFcmIdentifier(text)) fallback else text

internal fun fcmHandlingInformation(
    worker: String,
    groupId: String?,
    eventId: String?,
    kind: String?,
    inBackground: Boolean,
    timestamp: String = Instant.now().toString(),
): List<String> = listOf(
    "worker: $worker",
    "groupId: ${groupId?.takeIf { it.isNotBlank() } ?: "-"}",
    "eventId: ${eventId?.takeIf { it.isNotBlank() } ?: "-"}",
    "kind: ${kind?.takeIf { it.isNotBlank() } ?: "-"}",
    "timestamp: $timestamp",
    "appState: ${if (inBackground) "background" else "foreground"}",
)
