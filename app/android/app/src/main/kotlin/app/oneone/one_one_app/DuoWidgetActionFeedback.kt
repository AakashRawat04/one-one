package app.oneone.one_one_app

import android.content.Context
import android.os.Handler
import android.os.Looper

/**
 * Short-lived in-widget confirmation after Ring / Notify is tapped, so the
 * status pill updates immediately instead of waiting on the network toast.
 */
object DuoWidgetActionFeedback {
    enum class Kind { RINGING, NOTIFIED }

    private data class Entry(
        val groupId: String,
        val kind: Kind,
        val untilMs: Long,
    )

    private const val visibleMs = 2_500L
    private val mainHandler = Handler(Looper.getMainLooper())
    private val lock = Any()
    private var entry: Entry? = null
    private var clearRunnable: Runnable? = null

    fun show(context: Context, groupId: String, kind: Kind) {
        if (groupId.isBlank()) return
        val appContext = context.applicationContext
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
