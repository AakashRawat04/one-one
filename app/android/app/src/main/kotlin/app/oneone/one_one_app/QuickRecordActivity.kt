package app.oneone.one_one_app

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.media.MediaRecorder
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.MotionEvent
import android.view.View
import android.widget.ImageView
import android.widget.TextView
import android.widget.Toast
import androidx.core.content.ContextCompat
import java.io.File
import java.util.concurrent.Executors

/**
 * Native, transparent, Assistant-style overlay for one-tap voice nudges from
 * the home-screen widget. Recording auto-starts once RECORD_AUDIO is
 * granted; the mic format matches the in-app sender exactly (AAC-LC M4A,
 * 32kbps, 16kHz mono) so both paths produce interchangeable files.
 */
class QuickRecordActivity : Activity() {
    private var recorder: MediaRecorder? = null
    private var outputFile: File? = null
    private var recordingStartedAtMs = 0L
    private var stopped = false
    private var sending = false
    private var groupId: String? = null
    private var groupName: String? = null

    private lateinit var visualizer: AssistantOrbView
    private lateinit var hintText: TextView
    private lateinit var targetText: TextView
    private lateinit var recordingBadge: TextView
    private lateinit var controlsRow: View
    private lateinit var sheet: View
    private lateinit var cancelButton: ImageView
    private lateinit var sendButton: ImageView

    private val mainHandler = Handler(Looper.getMainLooper())
    private val ioExecutor = Executors.newSingleThreadExecutor()
    private val amplitudePoll = object : Runnable {
        override fun run() {
            val current = recorder
            if (current != null && !stopped) {
                val amplitude = try {
                    current.maxAmplitude
                } catch (_: Exception) {
                    0
                }
                // MediaRecorder amplitude is roughly 0..32767 for 16-bit PCM.
                val level = (amplitude / 9000f).coerceIn(0f, 1f)
                visualizer.setLevel(level)
                mainHandler.postDelayed(this, 50)
            }
        }
    }
    private val autoStopRunnable = Runnable { onSendTapped() }

    private val permissionRequestCode = 4821

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_quick_record)
        groupId = intent.getStringExtra(extraGroupId)
        groupName = intent.getStringExtra(extraGroupName)?.takeIf { it.isNotBlank() }
        DuoWidgetLog.i(
            "Q-01",
            "QuickRecord onCreate groupSuffix=${groupId?.takeLast(6) ?: "none"} " +
                "hasMicPerm=${hasRecordPermission()}",
        )

        visualizer = findViewById(R.id.visualizer)
        hintText = findViewById(R.id.hint_text)
        targetText = findViewById(R.id.target_text)
        recordingBadge = findViewById(R.id.recording_badge)
        controlsRow = findViewById(R.id.controls_row)
        sheet = findViewById(R.id.quick_record_sheet)
        cancelButton = findViewById(R.id.btn_cancel)
        sendButton = findViewById(R.id.btn_send)

        val displayName = groupName ?: "this group"
        targetText.text = displayName

        if (isGroupLive(groupId)) {
            DuoWidgetLog.w("Q-02", "QuickRecord aborted — group already live")
            Toast.makeText(this, "They're already live — no voice nudge needed.", Toast.LENGTH_SHORT)
                .show()
            finish()
            return
        }

        // Widget accent is user-customizable, but the overlay itself always
        // reads as Duo's own surface — brand yellow, not whatever accent
        // the group happens to be tinted.
        visualizer.setAccentColor(android.graphics.Color.parseColor("#F8BE03"))

        findViewById<View>(R.id.quick_record_root).setOnTouchListener { _, event ->
            if (event.action == MotionEvent.ACTION_DOWN) {
                val within = isPointInsideView(sheet, event.rawX, event.rawY)
                if (!within) {
                    onCancelTapped()
                    return@setOnTouchListener true
                }
            }
            false
        }
        cancelButton.setOnClickListener { onCancelTapped() }
        sendButton.setOnClickListener { onSendTapped() }

        if (hasRecordPermission()) {
            startRecording()
        } else {
            requestRecordPermission()
        }
    }

    private fun isGroupLive(groupId: String?): Boolean {
        if (groupId.isNullOrBlank()) return false
        val selfLive = ActiveVoiceSessionStore.readGroupId(this) == groupId
        if (selfLive) return true
        val selfUserId = DuoWidgetSnapshotStore.userId(this)
        val group = DuoWidgetSnapshotStore.readGroups(this)
            .firstOrNull { it.groupId == groupId }
        return group?.members?.any { member ->
            member.online && (selfUserId.isNullOrBlank() || member.userId != selfUserId)
        } == true
    }

    private fun isPointInsideView(view: View, rawX: Float, rawY: Float): Boolean {
        val location = IntArray(2)
        view.getLocationOnScreen(location)
        return rawX >= location[0] && rawX <= location[0] + view.width &&
            rawY >= location[1] && rawY <= location[1] + view.height
    }

    private fun hasRecordPermission(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    private fun requestRecordPermission() {
        hintText.text = "Allow microphone access"
        recordingBadge.text = "Permission needed"
        recordingBadge.setTextColor(
            ContextCompat.getColor(this, R.color.widget_text_secondary),
        )
        visualizer.reset()
        requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), permissionRequestCode)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != permissionRequestCode) return
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            startRecording()
        } else {
            Toast.makeText(this, "Microphone permission is needed to send a voice nudge.", Toast.LENGTH_LONG).show()
            finish()
        }
    }

    private fun startRecording() {
        val groupIdSnapshot = groupId
        if (groupIdSnapshot.isNullOrBlank()) {
            Toast.makeText(this, "No group selected for this widget.", Toast.LENGTH_SHORT).show()
            finish()
            return
        }
        recordingBadge.visibility = View.VISIBLE
        recordingBadge.text = "Recording…"
        recordingBadge.setTextColor(
            ContextCompat.getColor(this, R.color.widget_online_green),
        )
        hintText.text = "Your voice is being recorded"
        controlsRow.visibility = View.VISIBLE
        val file = File(cacheDir, "widget_voice_nudge_${System.currentTimeMillis()}.m4a")
        outputFile = file
        try {
            val mediaRecorder = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                MediaRecorder(this)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }
            mediaRecorder.setAudioSource(MediaRecorder.AudioSource.MIC)
            mediaRecorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            mediaRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            mediaRecorder.setAudioEncodingBitRate(32_000)
            mediaRecorder.setAudioSamplingRate(16_000)
            mediaRecorder.setAudioChannels(1)
            mediaRecorder.setOutputFile(file.absolutePath)
            mediaRecorder.prepare()
            mediaRecorder.start()
            recorder = mediaRecorder
            recordingStartedAtMs = System.currentTimeMillis()
            stopped = false
            mainHandler.post(amplitudePoll)
            mainHandler.postDelayed(autoStopRunnable, maxRecordingMs)
        } catch (error: Exception) {
            DeviceLog.warn("QuickRecord", "Failed to start recording: ${error.message}")
            Toast.makeText(this, "Couldn't start recording.", Toast.LENGTH_SHORT).show()
            finish()
        }
    }

    private fun stopRecordingIfNeeded(): File? {
        if (stopped) return outputFile
        stopped = true
        mainHandler.removeCallbacks(amplitudePoll)
        mainHandler.removeCallbacks(autoStopRunnable)
        val current = recorder
        recorder = null
        return try {
            current?.stop()
            current?.release()
            outputFile
        } catch (error: Exception) {
            DeviceLog.warn("QuickRecord", "Failed to stop recording: ${error.message}")
            try {
                current?.release()
            } catch (_: Exception) {
                // already released
            }
            null
        }
    }

    private fun onCancelTapped() {
        if (sending) return
        stopRecordingIfNeeded()
        outputFile?.delete()
        finish()
    }

    private fun onSendTapped() {
        if (sending) return
        val durationMs = System.currentTimeMillis() - recordingStartedAtMs
        val file = stopRecordingIfNeeded()
        if (file == null || !file.exists()) {
            Toast.makeText(this, "Recording failed.", Toast.LENGTH_SHORT).show()
            finish()
            return
        }
        if (durationMs < minRecordingMs) {
            file.delete()
            Toast.makeText(this, "Hold on a little longer to send a nudge.", Toast.LENGTH_SHORT).show()
            finish()
            return
        }
        sending = true
        visualizer.reset()
        recordingBadge.text = "Sending…"
        recordingBadge.setTextColor(
            ContextCompat.getColor(this, R.color.widget_text_secondary),
        )
        hintText.text = "Sending voice nudge…"
        sendButton.isEnabled = false
        cancelButton.isEnabled = false
        val groupIdSnapshot = groupId
        if (groupIdSnapshot.isNullOrBlank()) {
            DuoWidgetLog.e("Q-10", "send aborted — blank groupId")
            finish()
            return
        }
        val clampedDurationMs = durationMs.coerceAtMost(maxRecordingMs).coerceAtLeast(minRecordingMs)
        DuoWidgetLog.i(
            "Q-11",
            "send start groupSuffix=${groupIdSnapshot.takeLast(6)} " +
                "durationMs=$clampedDurationMs fileBytes=${file.length()}",
        )
        // Keep a copy so we can retry-log if delete races.
        val sendFile = file
        val displayName = groupName?.takeIf { it.isNotBlank() } ?: "group"
        ioExecutor.execute {
            val result = try {
                DuoWidgetApi.sendVoice(
                    applicationContext,
                    groupIdSnapshot,
                    sendFile,
                    clampedDurationMs,
                )
            } catch (error: Exception) {
                DuoWidgetLog.e("Q-12", "sendVoice threw", error)
                DuoWidgetApiResult.Failure(error.message ?: "send_threw")
            }
            try {
                sendFile.delete()
            } catch (_: Exception) {
                // ignore
            }
            mainHandler.post {
                when (result) {
                    is DuoWidgetApiResult.Success -> {
                        DuoWidgetLog.i("Q-20", "voice nudge sent OK")
                        showSentConfirmation(displayName)
                        DuoWidgetRenderer.updateAll(applicationContext)
                        mainHandler.postDelayed({ finish() }, 1_200)
                    }
                    is DuoWidgetApiResult.Failure -> {
                        DuoWidgetLog.e("Q-21", "voice nudge send failed: ${result.message}")
                        Toast.makeText(
                            this,
                            "Couldn't send: ${result.message}",
                            Toast.LENGTH_LONG,
                        ).show()
                        sending = false
                        sendButton.isEnabled = true
                        cancelButton.isEnabled = true
                        recordingBadge.text = "Failed"
                        hintText.text = "Couldn't send — close and try again"
                        finish()
                    }
                }
            }
        }
    }

    private fun showSentConfirmation(displayName: String) {
        recordingBadge.text = "Sent"
        recordingBadge.setTextColor(
            ContextCompat.getColor(this, R.color.widget_online_green),
        )
        hintText.text = "Voice nudge sent to $displayName"
        hintText.setTextColor(
            ContextCompat.getColor(this, R.color.widget_text_primary),
        )
        controlsRow.visibility = View.GONE
    }

    override fun onDestroy() {
        stopRecordingIfNeeded()
        outputFile?.takeIf { !sending }?.delete()
        super.onDestroy()
    }

    companion object {
        const val extraGroupId = "quick_record_group_id"
        const val extraGroupName = "quick_record_group_name"
        private const val maxRecordingMs = 5_000L
        private const val minRecordingMs = 250L
    }
}
