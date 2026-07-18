package app.oneone.one_one_app

import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.media.AudioManager
import android.media.ToneGenerator
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.ArrayDeque
import java.util.concurrent.Executors

class VoiceNudgePlaybackService : Service() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val networkExecutor = Executors.newSingleThreadExecutor()
    private val queue = ArrayDeque<NudgeRequest>()
    private var active: NudgeRequest? = null
    private var player: ExoPlayer? = null
    private var toneGenerator: ToneGenerator? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val request = intent?.toRequest()
        if (request == null) {
            Log.w(VoiceNudgeDiagnostics.tag, "[FCM-W6] Playback service received invalid intent")
            return START_NOT_STICKY
        }
        Log.i(
            VoiceNudgeDiagnostics.tag,
            "[FCM-10] Playback service accepted kind=${request.kind} " +
                "eventSuffix=${request.eventId.takeLast(6)}",
        )
        startForeground(
            VoiceNudgeNotifications.idFor(request.eventId),
            VoiceNudgeNotifications.build(this, request.senderName, "Preparing nudge…", true),
        )
        if (active?.eventId != request.eventId && queue.none { it.eventId == request.eventId }) {
            queue.add(request)
        }
        processNext()
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        mainHandler.removeCallbacksAndMessages(null)
        releasePlayback()
        networkExecutor.shutdownNow()
        super.onDestroy()
    }

    private fun processNext() {
        if (active != null || queue.isEmpty()) return
        val request = queue.removeFirst()
        active = request
        Log.i(
            VoiceNudgeDiagnostics.tag,
            "[FCM-11] Processing queued nudge kind=${request.kind}",
        )
        notify(request, if (request.kind == VoiceNudgeContract.kindRing) "Ringing…" else "Downloading voice nudge…")
        if (request.kind == VoiceNudgeContract.kindRing) {
            playRing(request)
        } else {
            downloadAndPlay(request)
        }
    }

    private fun playRing(request: NudgeRequest) {
        try {
            Log.i(
                VoiceNudgeDiagnostics.tag,
                "[FCM-12] Starting ring durationMs=${request.durationMs}",
            )
            toneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, 90).also {
                it.startTone(ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD, request.durationMs.toInt())
            }
            mainHandler.postDelayed({ finishActive(success = true) }, request.durationMs)
        } catch (error: RuntimeException) {
            VoiceNudgeDiagnostics.logFailure("[FCM-E4] Ring playback", error)
            finishActive(success = false)
        }
    }

    private fun downloadAndPlay(request: NudgeRequest) {
        networkExecutor.execute {
            try {
                val file = downloadAudio(request)
                Log.i(
                    VoiceNudgeDiagnostics.tag,
                    "[FCM-13] Voice audio downloaded bytes=${file.length()}",
                )
                mainHandler.post { startPlayer(request, file) }
            } catch (error: Exception) {
                VoiceNudgeDiagnostics.logFailure("[FCM-E5] Voice audio download", error)
                acknowledge(request, "failed") { finishActive(success = false) }
            }
        }
    }

    private fun downloadAudio(request: NudgeRequest): File {
        val audioUrl = requireNotNull(request.audioUrl) { "Missing audio URL" }
        val deliveryToken = requireNotNull(request.deliveryToken) { "Missing delivery token" }
        val connection = URL(audioUrl).openConnection() as HttpURLConnection
        connection.connectTimeout = 8_000
        connection.readTimeout = 8_000
        connection.requestMethod = "GET"
        connection.setRequestProperty("x-one-one-delivery-token", deliveryToken)
        connection.setRequestProperty("accept", "audio/mp4")
        try {
            val responseCode = connection.responseCode
            Log.i(
                VoiceNudgeDiagnostics.tag,
                "[FCM-13A] Voice audio HTTP response=$responseCode",
            )
            if (responseCode !in 200..299) {
                throw IllegalStateException("Audio download failed with HTTP $responseCode")
            }
            val output = File(cacheDir, "voice_nudge_${request.eventId.safeFileName()}.m4a")
            connection.inputStream.use { input ->
                FileOutputStream(output).use { sink ->
                    val buffer = ByteArray(8 * 1024)
                    var total = 0
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        total += count
                        if (total > maxAudioBytes) throw IllegalStateException("Voice nudge is too large")
                        sink.write(buffer, 0, count)
                    }
                    if (total == 0) throw IllegalStateException("Voice nudge is empty")
                }
            }
            return output
        } finally {
            connection.disconnect()
        }
    }

    private fun startPlayer(request: NudgeRequest, file: File) {
        if (active?.eventId != request.eventId) {
            file.delete()
            return
        }
        notify(request, "Playing voice nudge…")
        Log.i(VoiceNudgeDiagnostics.tag, "[FCM-14] Preparing voice audio player")
        player = ExoPlayer.Builder(this).build().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(C.USAGE_MEDIA)
                    .setContentType(C.AUDIO_CONTENT_TYPE_SPEECH)
                    .build(),
                true,
            )
            setWakeMode(C.WAKE_MODE_LOCAL)
            addListener(object : Player.Listener {
                override fun onPlaybackStateChanged(playbackState: Int) {
                    if (playbackState == Player.STATE_ENDED) {
                        Log.i(VoiceNudgeDiagnostics.tag, "[FCM-15] Voice playback completed")
                        acknowledge(request, "played") {
                            file.delete()
                            finishActive(success = true)
                        }
                    }
                }

                override fun onPlayerError(error: PlaybackException) {
                    VoiceNudgeDiagnostics.logFailure("[FCM-E6] Voice playback", error)
                    acknowledge(request, "failed") {
                        file.delete()
                        finishActive(success = false)
                    }
                }
            })
            setMediaItem(MediaItem.fromUri(Uri.fromFile(file)))
            prepare()
            play()
        }
    }

    private fun acknowledge(request: NudgeRequest, status: String, after: () -> Unit) {
        val ackUrl = request.ackUrl
        val deliveryToken = request.deliveryToken
        if (ackUrl == null || deliveryToken == null) {
            mainHandler.post(after)
            return
        }
        networkExecutor.execute {
            var connection: HttpURLConnection? = null
            try {
                val opened = URL(ackUrl).openConnection() as HttpURLConnection
                connection = opened
                opened.connectTimeout = 5_000
                opened.readTimeout = 5_000
                opened.requestMethod = "POST"
                opened.doOutput = true
                opened.setRequestProperty("content-type", "application/json")
                opened.setRequestProperty("x-one-one-delivery-token", deliveryToken)
                opened.outputStream.use { it.write("{\"status\":\"$status\"}".toByteArray()) }
                val responseCode = opened.responseCode
                Log.i(
                    VoiceNudgeDiagnostics.tag,
                    "[FCM-16] Delivery acknowledgement status=$status HTTP=$responseCode",
                )
            } catch (error: Exception) {
                VoiceNudgeDiagnostics.logFailure("[FCM-E7] Delivery acknowledgement", error)
            } finally {
                connection?.disconnect()
                mainHandler.post(after)
            }
        }
    }

    private fun finishActive(success: Boolean) {
        val request = active ?: return
        Log.i(
            VoiceNudgeDiagnostics.tag,
            "[FCM-17] Nudge finished kind=${request.kind} success=$success",
        )
        releasePlayback()
        active = null
        val manager = getSystemService(NotificationManager::class.java)
        if (!success) {
            manager.notify(
                VoiceNudgeNotifications.idFor(request.eventId),
                VoiceNudgeNotifications.build(this, request.senderName, "Nudge could not be played", false),
            )
        } else {
            manager.cancel(VoiceNudgeNotifications.idFor(request.eventId))
        }
        if (queue.isEmpty()) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
            stopSelf()
        } else {
            processNext()
        }
    }

    private fun releasePlayback() {
        player?.release()
        player = null
        toneGenerator?.stopTone()
        toneGenerator?.release()
        toneGenerator = null
    }

    private fun notify(request: NudgeRequest, status: String) {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(
            VoiceNudgeNotifications.idFor(request.eventId),
            VoiceNudgeNotifications.build(this, request.senderName, status, true),
        )
    }

    private fun Intent.toRequest(): NudgeRequest? {
        val kind = getStringExtra(VoiceNudgeContract.extraKind) ?: return null
        val eventId = getStringExtra(VoiceNudgeContract.extraEventId) ?: return null
        val senderName = getStringExtra(VoiceNudgeContract.extraSenderName) ?: "Someone"
        val durationMs = getLongExtra(VoiceNudgeContract.extraDurationMs, 0).coerceIn(250, 10_000)
        return NudgeRequest(
            kind = kind,
            eventId = eventId,
            senderName = senderName,
            durationMs = durationMs,
            audioUrl = getStringExtra(VoiceNudgeContract.extraAudioUrl),
            ackUrl = getStringExtra(VoiceNudgeContract.extraAckUrl),
            deliveryToken = getStringExtra(VoiceNudgeContract.extraDeliveryToken),
        )
    }

    private fun String.safeFileName() = replace(Regex("[^A-Za-z0-9_-]"), "_")

    private data class NudgeRequest(
        val kind: String,
        val eventId: String,
        val senderName: String,
        val durationMs: Long,
        val audioUrl: String?,
        val ackUrl: String?,
        val deliveryToken: String?,
    )

    companion object {
        private const val maxAudioBytes = 128 * 1024
    }
}
