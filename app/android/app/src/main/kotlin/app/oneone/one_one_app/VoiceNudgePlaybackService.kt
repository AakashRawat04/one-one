package app.oneone.one_one_app

import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.media.AudioAttributes as PlatformAudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
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
import kotlin.math.PI
import kotlin.math.sin

class VoiceNudgePlaybackService : Service() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val networkExecutor = Executors.newSingleThreadExecutor()
    private val queue = ArrayDeque<NudgeRequest>()
    private var active: NudgeRequest? = null
    private var player: ExoPlayer? = null
    private var ringTrack: AudioTrack? = null
    private var playbackWakeLock: PowerManager.WakeLock? = null

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
            VoiceNudgeNotifications.build(
                this,
                request.eventId,
                request.groupId,
                request.responseUrl,
                request.senderName,
                "Preparing nudge…",
                true,
            ),
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
        releaseWakeLock()
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
        holdWakeLock()
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
            val samples = buildNudgeRing(request.durationMs)
            val attributes = PlatformAudioAttributes.Builder()
                .setUsage(PlatformAudioAttributes.USAGE_ALARM)
                .setContentType(PlatformAudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            val format = AudioFormat.Builder()
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .setSampleRate(ringSampleRate)
                .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                .build()
            @Suppress("DEPRECATION")
            ringTrack = AudioTrack(
                attributes,
                format,
                samples.size * 2,
                AudioTrack.MODE_STATIC,
                AudioManager.AUDIO_SESSION_ID_GENERATE,
            ).also { track ->
                val written = track.write(samples, 0, samples.size)
                check(written == samples.size) {
                    "Nudge ring buffer write failed: $written/${samples.size} samples"
                }
                track.setVolume(0.86f)
                track.play()
            }
            // The PCM buffer itself is exactly the requested length. This
            // callback owns service and notification cleanup at that boundary.
            mainHandler.postDelayed({ finishActive(success = true) }, request.durationMs)
        } catch (error: RuntimeException) {
            VoiceNudgeDiagnostics.logFailure("[FCM-E4] Ring playback", error)
            finishActive(success = false)
        }
    }

    /**
     * Builds One One's own ring instead of delegating to the phone ringtone.
     * Each phrase is two short rising chimes followed by breathing space.
     */
    private fun buildNudgeRing(durationMs: Long): ShortArray {
        val sampleCount = ((durationMs * ringSampleRate) / 1_000L).toInt()
        return ShortArray(sampleCount) { sampleIndex ->
            val elapsedMs = sampleIndex * 1_000.0 / ringSampleRate
            val phraseMs = elapsedMs % ringPhraseMs
            val pulse = when {
                phraseMs < 190.0 -> RingPulse(phraseMs, 190.0, 784.0, 1_176.0)
                phraseMs >= 250.0 && phraseMs < 520.0 ->
                    RingPulse(phraseMs - 250.0, 270.0, 988.0, 1_482.0)
                else -> null
            }
            if (pulse == null) {
                0
            } else {
                val phraseEnvelope = pulseEnvelope(pulse.elapsedMs, pulse.durationMs)
                val finalFade = ((durationMs - elapsedMs) / 45.0).coerceIn(0.0, 1.0)
                val envelope = phraseEnvelope * finalFade
                val seconds = elapsedMs / 1_000.0
                val fundamental = sin(2.0 * PI * pulse.frequencyHz * seconds)
                val harmonic = sin(2.0 * PI * pulse.harmonicHz * seconds) * 0.24
                ((fundamental + harmonic) * envelope * Short.MAX_VALUE * 0.56)
                    .toInt()
                    .coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt())
                    .toShort()
            }
        }
    }

    private fun pulseEnvelope(elapsedMs: Double, durationMs: Double): Double {
        val attack = (elapsedMs / 18.0).coerceIn(0.0, 1.0)
        val release = ((durationMs - elapsedMs) / 55.0).coerceIn(0.0, 1.0)
        return attack * release
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
        var currentUrl = requireNotNull(request.audioUrl) { "Missing audio URL" }
        var redirects = 0
        while (true) {
            val connection = URL(currentUrl).openConnection() as HttpURLConnection
            // Manual redirects so the delivery-token header is never forwarded
            // to Cloud Storage signed URLs (would break V4 signature checks).
            connection.instanceFollowRedirects = false
            connection.connectTimeout = 8_000
            connection.readTimeout = 8_000
            connection.requestMethod = "GET"
            connection.setRequestProperty("accept", "audio/mp4")
            if (isBackendAudioProxyUrl(currentUrl)) {
                val deliveryToken = requireNotNull(request.deliveryToken) {
                    "Missing delivery token"
                }
                connection.setRequestProperty("x-one-one-delivery-token", deliveryToken)
            }
            try {
                val responseCode = connection.responseCode
                Log.i(
                    VoiceNudgeDiagnostics.tag,
                    "[FCM-13A] Voice audio HTTP response=$responseCode",
                )
                if (responseCode in 300..399) {
                    val location = connection.getHeaderField("Location")
                        ?: throw IllegalStateException("Audio redirect missing Location")
                    if (redirects >= 3) {
                        throw IllegalStateException("Too many audio download redirects")
                    }
                    currentUrl = location
                    redirects += 1
                    continue
                }
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
                            if (total > maxAudioBytes) {
                                throw IllegalStateException("Voice nudge is too large")
                            }
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
    }

    private fun isBackendAudioProxyUrl(url: String): Boolean {
        return url.contains("/v1/voice-nudges/") && url.contains("/audio")
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
        val finalStatus = when {
            !success -> "Nudge could not be played"
            request.kind == VoiceNudgeContract.kindRing ->
                "${request.durationMs / 1000}-second ring received"
            else -> "Voice nudge received"
        }
        if (queue.isEmpty()) {
            releaseWakeLock()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_DETACH)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(false)
            }
            manager.notify(
                VoiceNudgeNotifications.idFor(request.eventId),
                VoiceNudgeNotifications.build(
                    this,
                    request.eventId,
                    request.groupId,
                    request.responseUrl,
                    request.senderName,
                    finalStatus,
                    false,
                ),
            )
            stopSelf()
        } else {
            manager.notify(
                VoiceNudgeNotifications.idFor(request.eventId),
                VoiceNudgeNotifications.build(
                    this,
                    request.eventId,
                    request.groupId,
                    request.responseUrl,
                    request.senderName,
                    finalStatus,
                    false,
                ),
            )
            processNext()
        }
    }

    private fun releasePlayback() {
        player?.release()
        player = null
        try {
            ringTrack?.stop()
        } catch (_: IllegalStateException) {
            // A completed static track may already be stopped.
        }
        ringTrack?.release()
        ringTrack = null
    }

    private fun holdWakeLock() {
        try {
            val lock = playbackWakeLock ?: run {
                val powerManager = getSystemService(PowerManager::class.java)
                powerManager.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK,
                    "$packageName:VoiceNudgePlayback",
                ).apply {
                    setReferenceCounted(false)
                    playbackWakeLock = this
                }
            }
            if (lock.isHeld) lock.release()
            lock.acquire(maxWakeLockDurationMs)
            Log.i(VoiceNudgeDiagnostics.tag, "[FCM-11A] Playback wake lock acquired")
        } catch (error: RuntimeException) {
            VoiceNudgeDiagnostics.logFailure("[FCM-E8] Playback wake lock", error)
        }
    }

    private fun releaseWakeLock() {
        try {
            playbackWakeLock?.takeIf { it.isHeld }?.release()
        } catch (error: RuntimeException) {
            VoiceNudgeDiagnostics.logFailure("[FCM-E9] Playback wake lock release", error)
        }
    }

    private fun notify(request: NudgeRequest, status: String) {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(
            VoiceNudgeNotifications.idFor(request.eventId),
            VoiceNudgeNotifications.build(
                this,
                request.eventId,
                request.groupId,
                request.responseUrl,
                request.senderName,
                status,
                true,
            ),
        )
    }

    private fun Intent.toRequest(): NudgeRequest? {
        val kind = getStringExtra(VoiceNudgeContract.extraKind) ?: return null
        val eventId = getStringExtra(VoiceNudgeContract.extraEventId) ?: return null
        val senderName = getStringExtra(VoiceNudgeContract.extraSenderName) ?: "Someone"
        val suppliedDurationMs = getLongExtra(VoiceNudgeContract.extraDurationMs, 0)
        val durationMs = if (kind == VoiceNudgeContract.kindRing) {
            suppliedDurationMs.takeIf { it in supportedRingDurationsMs } ?: return null
        } else {
            suppliedDurationMs.coerceIn(250, 10_000)
        }
        val groupId = getStringExtra(VoiceNudgeContract.extraGroupId) ?: return null
        return NudgeRequest(
            kind = kind,
            eventId = eventId,
            senderName = senderName,
            durationMs = durationMs,
            audioUrl = getStringExtra(VoiceNudgeContract.extraAudioUrl),
            ackUrl = getStringExtra(VoiceNudgeContract.extraAckUrl),
            deliveryToken = getStringExtra(VoiceNudgeContract.extraDeliveryToken),
            groupId = groupId,
            responseUrl = getStringExtra(VoiceNudgeContract.extraResponseUrl),
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
        val groupId: String,
        val responseUrl: String?,
    )

    private data class RingPulse(
        val elapsedMs: Double,
        val durationMs: Double,
        val frequencyHz: Double,
        val harmonicHz: Double,
    )

    companion object {
        private const val ringSampleRate = 44_100
        private const val ringPhraseMs = 900.0
        private val supportedRingDurationsMs = setOf(3_000L, 5_000L, 10_000L)
        private const val maxAudioBytes = 128 * 1024
        private const val maxWakeLockDurationMs = 30_000L
    }
}
