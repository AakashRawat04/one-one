package app.oneone.one_one_app

import android.content.Context
import android.os.Handler
import android.os.Looper

/**
 * Short-lived in-widget confirmation after Ring / Notify / Accept / Decline
 * so the status pill updates immediately instead of waiting on the network.
 */
object DuoWidgetActionFeedback {
    enum class Kind {
        RINGING,
        NOTIFIED,
        JOINING,
        DECLINED,
        SENT,
    }

    private data class Entry(
        val groupId: String,
        val kind: Kind,
        val untilMs: Long,
    )

    private const val defaultVisibleMs = 2_500L
    private const val joiningVisibleMs = 8_000L
    private val mainHandler = Handler(Looper.getMainLooper())
    private val lock = Any()
    private var entry: Entry? = null
    private var clearRunnable: Runnable? = null

    fun show(context: Context, groupId: String, kind: Kind) {
        if (groupId.isBlank()) return
        val appContext = context.applicationContext
        val visibleMs = if (kind == Kind.JOINING) joiningVisibleMs else defaultVisibleMs
        val until = System.currentTimeMillis() + visibleMs
        synchronized(lock) {
            clearRunnable?.let { mainHandler.removeCallbacks(it) }
            entry = Entry(groupId, kind, until)
            val clear = Runnable {
                synchronized(lock) {
                    if (entry?.groupId == groupId && entry?.kind == kind) {
                        entry = null
                    }
                }
                DuoWidgetRenderer.updateAll(appContext)
            }
            clearRunnable = clear
            mainHandler.postDelayed(clear, visibleMs)
        }
        DuoWidgetRenderer.updateAll(appContext)
    }

    fun currentFor(groupId: String): Kind? {
        if (groupId.isBlank()) return null
        val now = System.currentTimeMillis()
        synchronized(lock) {
            val current = entry ?: return null
            if (current.groupId != groupId) return null
            if (now >= current.untilMs) {
                entry = null
                return null
            }
            return current.kind
        }
    }
}
