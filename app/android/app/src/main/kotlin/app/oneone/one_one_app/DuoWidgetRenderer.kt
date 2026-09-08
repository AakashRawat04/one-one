package app.oneone.one_one_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger

/** Rendering-time state a single widget instance is currently showing. */
private enum class DuoWidgetState { IDLE, PENDING, ONLINE }

/**
 * Builds and pushes [RemoteViews] for every Duo home-screen widget instance.
 *
 * Avatar photos are bound as tiny copied bitmaps (never the notification
 * cache object). Missing photos prefetch once, then a single debounced
 * [updateAll] refreshes every instance.
 */
object DuoWidgetRenderer {
    private const val avatarPx = 72
    private const val prefetchDebounceMs = 500L

    /**
     * Minimum dp a layout may occupy. Keys for [RemoteViews] size mapping
     * (API 31+) and for the pre-S fallback picker.
     *
     * Medium must sit *below* every OEM 4x2 cell we have measured
     * (Motorola ~159, Pixel ~180, Samsung ~223). Large must sit *above*
     * every 4x2 cell so a two-row widget never gets the tall layout —
     * that was the Samsung clip: `minHeight >= 220` classified a 223dp
     * 4x2 as large, and One UI clipped the mic.
     */
    private const val smallMinW = 110f
    private const val smallMinH = 70f
    private const val mediumMinW = 180f
    private const val mediumMinH = 110f
    private const val largeMinW = 250f
    private const val largeMinH = 280f

    private val avatarIds = intArrayOf(
        R.id.avatar_1,
        R.id.avatar_2,
        R.id.avatar_3,
        R.id.avatar_4,
        R.id.avatar_5,
    )

    private val avatarMonoIds = intArrayOf(
        R.id.avatar_1_mono,
        R.id.avatar_2_mono,
        R.id.avatar_3_mono,
        R.id.avatar_4_mono,
        R.id.avatar_5_mono,
    )

    private val mainHandler = Handler(Looper.getMainLooper())
    private val attemptedPhotoUrls = ConcurrentHashMap.newKeySet<String>()
    private val prefetchLock = Any()
    private val inFlightPhotos = AtomicInteger(0)
    private var prefetchRefreshConsumed = false
    private var prefetchDebouncePosted = false
    private var prefetchContext: Context? = null

    private val prefetchDebounceRunnable = Runnable {
        flushPhotoRefresh("debounce")
    }

    fun updateAll(context: Context) {
        val appContext = context.applicationContext
        val manager = AppWidgetManager.getInstance(appContext)
        val ids = manager.getAppWidgetIds(
            ComponentName(appContext, DuoHomeWidgetProvider::class.java),
        )
        DuoWidgetLog.i("R-00", "updateAll count=${ids.size} ids=${ids.toList()}")
        for (appWidgetId in ids) {
            updateWidget(appContext, manager, appWidgetId)
        }
    }

    /** Pushes [updateAll] onto the main looper so callers (method channels,
     *  broadcast receivers) can return before bitmap copies run. */
    fun scheduleUpdateAll(context: Context, delayMs: Long = 50L) {
        val appContext = context.applicationContext
        mainHandler.postDelayed({ updateAll(appContext) }, delayMs)
    }

    fun updateWidget(context: Context, manager: AppWidgetManager, appWidgetId: Int) {
        val appContext = context.applicationContext
        var stage = "start"
        try {
            stage = "readOptions"
            val options = manager.getAppWidgetOptions(appWidgetId)
            logSizeOptions(appWidgetId, options)

            stage = "bindLayouts"
            val small = boundViews(
                appContext, appWidgetId, R.layout.duo_widget_small, verbose = false,
            )
            val medium = boundViews(
                appContext, appWidgetId, R.layout.duo_widget_medium, verbose = true,
            )
            val large = boundViews(
                appContext, appWidgetId, R.layout.duo_widget_large, verbose = false,
            )

            stage = "updateAppWidget"
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                try {
                    val mapping = mapOf(
                        SizeF(smallMinW, smallMinH) to small,
                        SizeF(mediumMinW, mediumMinH) to medium,
                        SizeF(largeMinW, largeMinH) to large,
                    )
                    manager.updateAppWidget(appWidgetId, RemoteViews(mapping))
                    DuoWidgetLog.i("R-02", "pushed id=$appWidgetId layout=responsive OK")
                    return
                } catch (error: Exception) {
                    DuoWidgetLog.w(
                        "R-02b",
                        "responsive map failed, falling back to single layout",
                        error,
                    )
                }
            }

            val layoutId = pickLayout(options)
            val views = when (layoutId) {
                R.layout.duo_widget_small -> small
                R.layout.duo_widget_large -> large
                else -> medium
            }
            manager.updateAppWidget(appWidgetId, views)
            DuoWidgetLog.i(
                "R-02",
                "pushed id=$appWidgetId layout=${DuoWidgetLog.layoutName(layoutId)} OK",
            )
        } catch (error: Exception) {
            DuoWidgetLog.e(
                "R-99",
                "updateWidget FAILED id=$appWidgetId stage=$stage " +
                    "type=${error.javaClass.name}",
                error,
            )
            pushFallback(appContext, manager, appWidgetId)
        }
    }

    private fun boundViews(
        context: Context,
        appWidgetId: Int,
        layoutId: Int,
        verbose: Boolean,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, layoutId)
        bindWidget(context, views, appWidgetId, layoutId, verbose)
        return views
    }

    /**
     * Pre-API 31: pick the largest layout whose *minimum* size fits the
     * host's reported min width/height. Unknown 0x0 (Samsung first paint)
     * defaults to medium — the 4x2 target.
     */
    private fun pickLayout(options: Bundle): Int {
        val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
        val layoutId = when {
            minWidth <= 0 || minHeight <= 0 -> R.layout.duo_widget_medium
            minWidth >= largeMinW && minHeight >= largeMinH -> R.layout.duo_widget_large
            minWidth >= mediumMinW && minHeight >= mediumMinH -> R.layout.duo_widget_medium
            else -> R.layout.duo_widget_small
        }
        DuoWidgetLog.d(
            "R-01a",
            "id fallback size=${minWidth}x${minHeight} -> ${DuoWidgetLog.layoutName(layoutId)}",
        )
        return layoutId
    }

    private fun logSizeOptions(appWidgetId: Int, options: Bundle) {
        val minW = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        val minH = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
        val maxW = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 0)
        val maxH = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
        val sizes = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            widgetSizes(options).joinToString { "${it.width.toInt()}x${it.height.toInt()}" }
        } else {
            "n/a"
        }
        DuoWidgetLog.i(
            "R-01a",
            "id=$appWidgetId min=${minW}x${minH} max=${maxW}x${maxH} sizes=[$sizes]",
        )
    }

    private fun widgetSizes(options: Bundle): List<SizeF> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return emptyList()
        val list: ArrayList<SizeF>? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            options.getParcelableArrayList(AppWidgetManager.OPTION_APPWIDGET_SIZES, SizeF::class.java)
        } else {
            @Suppress("DEPRECATION")
            options.getParcelableArrayList(AppWidgetManager.OPTION_APPWIDGET_SIZES)
        }
        return list.orEmpty()
    }

    private fun bindWidget(
        context: Context,
        views: RemoteViews,
        appWidgetId: Int,
        layoutId: Int,
        verbose: Boolean,
    ) {
        val group = DuoWidgetSnapshotStore.groupForWidget(context, appWidgetId)
        if (group == null) {
            if (verbose) {
                DuoWidgetLog.w(
                    "R-10",
                    "id=$appWidgetId no group snapshot — signed-out chrome " +
                        "(groups=${DuoWidgetSnapshotStore.readGroups(context).size})",
                )
            }
            renderSignedOut(context, views)
            return
        }

        if (verbose) {
            DuoWidgetLog.i(
                "R-11",
                "id=$appWidgetId group=${group.name} " +
                    "groupIdSuffix=${group.groupId.takeLast(6)} members=${group.members.size}",
            )
        }
        trySetText(views, R.id.group_name, group.name)

        if (layoutId == R.layout.duo_widget_small) {
            hideAvatars(views)
        } else {
            bindAvatars(context, views, group.members, prefetch = verbose)
        }

        val pending = IncomingNudgeStore.pendingForGroup(context, group.groupId)
        val liveGroupId = ActiveVoiceSessionStore.readGroupId(context)
        val selfLive = liveGroupId != null && liveGroupId == group.groupId
        val selfUserId = DuoWidgetSnapshotStore.userId(context)
        // Ignore the local user's own online flag — ActiveVoiceSessionStore is
        // the immediate source of truth for self, and a stale snapshot must
        // not keep LIVE after the session ends.
        val friendsLive = group.members.any { member ->
            member.online && (selfUserId.isNullOrBlank() || member.userId != selfUserId)
        }
        // Live when this device is in-session OR the snapshot says a friend is.
        // Clearing either source must drop the LIVE chrome immediately.
        val isOnline = selfLive || friendsLive
        val state = when {
            isOnline -> DuoWidgetState.ONLINE
            pending != null -> DuoWidgetState.PENDING
            else -> DuoWidgetState.IDLE
        }
        if (verbose) {
            DuoWidgetLog.i(
                "R-12",
                "id=$appWidgetId state=$state " +
                    "pendingEvent=${pending?.get("eventId")?.takeLast(6) ?: "none"} " +
                    "liveGroup=${liveGroupId?.takeLast(6) ?: "none"} " +
                    "selfLive=$selfLive friendsLive=$friendsLive",
            )
        }
        val feedback = DuoWidgetActionFeedback.currentFor(group.groupId)
        renderState(views, state, pending, feedback)
        setActionIntents(
            context,
            views,
            appWidgetId,
            group.groupId,
            group.name,
            pending?.get("responseUrl"),
            voiceNudgeEnabled = state != DuoWidgetState.ONLINE,
        )
    }

    /**
     * Bind up to 5 member avatars. Photos use a 36px copied bitmap; any
     * failure falls back to a locally drawn monogram bitmap, then a
     * TextView sibling.
     */
    private fun bindAvatars(
        context: Context,
        views: RemoteViews,
        members: List<DuoWidgetMember>,
        prefetch: Boolean,
    ) {
        val logo = NotificationAvatarHelper.appLogoBitmap(context)
        val pendingUrls = ArrayList<String>()
        var shown = 0
        var photoHits = 0
        var assetHits = 0

        for ((slot, viewId) in avatarIds.withIndex()) {
            val monoId = avatarMonoIds.getOrNull(slot) ?: 0
            if (slot >= members.size) {
                trySetVisibility(views, viewId, View.GONE)
                if (monoId != 0) trySetVisibility(views, monoId, View.GONE)
                continue
            }
            val member = members[slot]
            val url = member.photoUrl?.trim().orEmpty()
            val asset = member.avatarAsset?.trim().orEmpty()
            // Match in-app ProfileImage: a bundled preset wins over a photo
            // URL so the widget does not wait on Cloudinary for people who
            // picked an avatar from the pack.
            val bundled = if (asset.isNotEmpty()) {
                NotificationAvatarHelper.bundledAvatar(context, asset)
            } else {
                null
            }
            if (prefetch && asset.isNotEmpty() && bundled == null) {
                DuoWidgetLog.w("R-21a", "bundled avatar miss ${asset.takeLast(32)}")
            }
            val hasCachedPhoto = url.isNotEmpty() &&
                NotificationAvatarHelper.hasCachedPhoto(url)
            val cachedPhoto = if (hasCachedPhoto) {
                NotificationAvatarHelper.largeIcon(context, url, member.displayName)
            } else {
                null
            }
            val source = when {
                bundled != null -> {
                    assetHits++
                    bundled
                }
                cachedPhoto != null && cachedPhoto !== logo -> {
                    photoHits++
                    cachedPhoto
                }
                else -> {
                    if (url.isNotEmpty()) pendingUrls.add(url)
                    monogramBitmap(member.displayName)
                }
            }
            val bound = bindAvatarSlot(views, viewId, monoId, source, member.displayName)
            if (bound) shown++
        }

        val overflow = members.size - avatarIds.size
        if (overflow > 0) {
            trySetVisibility(views, R.id.avatar_overflow, View.VISIBLE)
            trySetText(views, R.id.avatar_overflow, "+$overflow")
        } else {
            trySetVisibility(views, R.id.avatar_overflow, View.GONE)
        }
        if (prefetch) {
            DuoWidgetLog.i(
                "R-21",
                "avatars bound shown=$shown overflow=${overflow.coerceAtLeast(0)} " +
                    "photos=$photoHits assets=$assetHits " +
                    "pendingPhotos=${pendingUrls.size} members=${members.size} " +
                    "withUrl=${members.count { !it.photoUrl.isNullOrBlank() }} " +
                    "withAsset=${members.count { !it.avatarAsset.isNullOrBlank() }}",
            )
            prefetchPhotos(context, pendingUrls)
        }
    }

    private fun bindAvatarSlot(
        views: RemoteViews,
        imageId: Int,
        monoId: Int,
        source: Bitmap,
        displayName: String,
    ): Boolean {
        val copy = copyWidgetBitmap(source)
        if (copy != null) {
            try {
                views.setImageViewBitmap(imageId, copy)
                trySetVisibility(views, imageId, View.VISIBLE)
                if (monoId != 0) trySetVisibility(views, monoId, View.GONE)
                return true
            } catch (error: Exception) {
                DuoWidgetLog.w(
                    "R-20",
                    "setImageViewBitmap failed id=0x${Integer.toHexString(imageId)}",
                    error,
                )
            }
        }
        try {
            views.setImageViewResource(imageId, R.drawable.bg_widget_btn_oval)
            trySetVisibility(views, imageId, View.VISIBLE)
        } catch (_: Exception) {
            trySetVisibility(views, imageId, View.GONE)
        }
        if (monoId != 0) {
            trySetVisibility(views, monoId, View.VISIBLE)
            trySetText(views, monoId, monogram(displayName))
            return true
        }
        return false
    }

    /**
     * Scale to a binder-safe size, clip to a circle, and flatten onto an
     * opaque card-colored plate. Several OEM hosts (Motorola among them)
     * drop RemoteViews bitmaps that have an alpha channel — [toCircular]
     * produces transparent corners — so every pixel must stay opaque.
     * Drawing onto #151515 matches [R.color.widget_glass_card_fill].
     *
     * The circular clip keeps adjacent avatars from reading as stacked
     * squares when the row is laid out tightly. The result is a new bitmap
     * so the launcher recycling the parcel cannot poison
     * [NotificationAvatarHelper]'s cache.
     */
    private fun copyWidgetBitmap(source: Bitmap): Bitmap? {
        return try {
            if (source.isRecycled) return null
            val out = Bitmap.createBitmap(avatarPx, avatarPx, Bitmap.Config.ARGB_8888)
            // RGB of widget_glass_card_fill (#E6151515) with alpha forced on
            // so the parcelled bitmap has no transparent pixels.
            out.eraseColor(0xFF151515.toInt())
            val canvas = Canvas(out)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { isFilterBitmap = true }
            val bounds = RectF(0f, 0f, avatarPx.toFloat(), avatarPx.toFloat())
            val clip = Path().apply {
                addCircle(avatarPx / 2f, avatarPx / 2f, avatarPx / 2f, Path.Direction.CW)
            }
            canvas.save()
            canvas.clipPath(clip)
            canvas.drawBitmap(source, null, bounds, paint)
            canvas.restore()
            // Hairline ring so neighbouring circles stay distinct.
            val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = avatarPx * 0.06f
                color = 0xFF151515.toInt()
            }
            canvas.drawCircle(
                avatarPx / 2f,
                avatarPx / 2f,
                avatarPx / 2f - stroke.strokeWidth / 2f,
                stroke,
            )
            out
        } catch (error: Exception) {
            DuoWidgetLog.w("R-20", "copyWidgetBitmap failed", error)
            null
        }
    }

    private fun monogramBitmap(displayName: String): Bitmap {
        val size = avatarPx
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            // Matches bg_widget_btn_oval's frosted-glass chip fill so a
            // monogram fallback doesn't look like a flat leftover from the
            // old solid-black theme.
            color = Color.parseColor("#33302D")
            style = Paint.Style.FILL
        }
        canvas.drawCircle(size / 2f, size / 2f, size / 2f, paint)
        paint.color = Color.parseColor("#F0EDE8")
        paint.textAlign = Paint.Align.CENTER
        paint.textSize = size * 0.42f
        paint.isFakeBoldText = true
        val letter = monogram(displayName)
        val textY = size / 2f - (paint.descent() + paint.ascent()) / 2f
        canvas.drawText(letter, size / 2f, textY, paint)
        return bitmap
    }

    private fun prefetchPhotos(context: Context, urls: List<String>) {
        val unique = urls.map { it.trim() }.filter { it.isNotEmpty() }.distinct()
            .filter { attemptedPhotoUrls.add(it) }
        if (unique.isEmpty()) return
        val appContext = context.applicationContext
        synchronized(prefetchLock) {
            prefetchContext = appContext
            prefetchRefreshConsumed = false
            inFlightPhotos.addAndGet(unique.size)
            if (!prefetchDebouncePosted) {
                prefetchDebouncePosted = true
                mainHandler.postDelayed(prefetchDebounceRunnable, prefetchDebounceMs)
            }
        }
        DuoWidgetLog.d("R-22", "prefetch start count=${unique.size}")
        for (url in unique) {
            NotificationAvatarHelper.loadAsync(appContext, url, "", null) {
                // A transient failure (network blip, bad thumbnail params)
                // must not permanently blacklist this url — un-mark it so
                // the next updateAll (next tap, next foreground) retries.
                // Without this, a member's real photo could stay stuck on
                // the logo/monogram fallback for the rest of the process.
                if (!NotificationAvatarHelper.hasCachedPhoto(url)) {
                    attemptedPhotoUrls.remove(url)
                }
                onPhotoReady()
            }
        }
    }

    private fun onPhotoReady() {
        val remaining = inFlightPhotos.updateAndGet { (it - 1).coerceAtLeast(0) }
        if (remaining == 0) {
            flushPhotoRefresh("all-ready")
        }
    }

    private fun flushPhotoRefresh(reason: String) {
        val ctx: Context
        synchronized(prefetchLock) {
            if (prefetchRefreshConsumed) return
            prefetchRefreshConsumed = true
            prefetchDebouncePosted = false
            mainHandler.removeCallbacks(prefetchDebounceRunnable)
            ctx = prefetchContext ?: return
        }
        DuoWidgetLog.i("R-22", "photo refresh reason=$reason")
        mainHandler.post { updateAll(ctx) }
    }

    private fun monogram(displayName: String): String {
        val trimmed = displayName.trim()
        if (trimmed.isEmpty()) return "?"
        val parts = trimmed.split(Regex("\\s+"))
        return if (parts.size >= 2) {
            "${parts[0].first().uppercaseChar()}${parts[1].first().uppercaseChar()}"
        } else {
            trimmed.first().uppercaseChar().toString()
        }
    }

    private fun renderSignedOut(context: Context, views: RemoteViews) {
        trySetText(views, R.id.group_name, "Open Duo")
        trySetText(views, R.id.status_pill, "Sign in to set up your widget")
        hideAvatars(views)
        trySetVisibility(views, R.id.btn_decline, View.GONE)
        trySetVisibility(views, R.id.btn_accept, View.GONE)
        trySetVisibility(views, R.id.btn_ring, View.GONE)
        trySetVisibility(views, R.id.btn_notify, View.GONE)
        trySetVisibility(views, R.id.btn_mic, View.GONE)
        trySetVisibility(views, R.id.btn_next, View.GONE)
        trySetVisibility(views, R.id.live_label, View.GONE)
        trySetClick(views, R.id.widget_root, openAppIntent(context))
    }

    private fun hideAvatars(views: RemoteViews) {
        for (viewId in avatarIds) {
            trySetVisibility(views, viewId, View.GONE)
        }
        for (viewId in avatarMonoIds) {
            trySetVisibility(views, viewId, View.GONE)
        }
        trySetVisibility(views, R.id.avatar_overflow, View.GONE)
    }

    private fun renderState(
        views: RemoteViews,
        state: DuoWidgetState,
        pending: Map<String, String>?,
        feedback: DuoWidgetActionFeedback.Kind?,
    ) {
        when (state) {
            DuoWidgetState.ONLINE -> {
                trySetText(views, R.id.status_pill, "Live now")
                trySetVisibility(views, R.id.status_pill, View.VISIBLE)
                trySetVisibility(views, R.id.live_label, View.VISIBLE)
                trySetVisibility(views, R.id.btn_decline, View.GONE)
                trySetVisibility(views, R.id.btn_accept, View.GONE)
                trySetVisibility(views, R.id.btn_ring, View.GONE)
                trySetVisibility(views, R.id.btn_notify, View.GONE)
                // Already live — voice nudge is not offered from the widget.
                trySetVisibility(views, R.id.btn_mic, View.GONE)
            }
            DuoWidgetState.PENDING -> {
                val senderName = pending?.get("senderName") ?: "A friend"
                trySetText(views, R.id.status_pill, "$senderName nudged you")
                trySetVisibility(views, R.id.status_pill, View.VISIBLE)
                trySetVisibility(views, R.id.live_label, View.GONE)
                trySetVisibility(views, R.id.btn_decline, View.VISIBLE)
                trySetVisibility(views, R.id.btn_accept, View.VISIBLE)
                trySetVisibility(views, R.id.btn_ring, View.GONE)
                trySetVisibility(views, R.id.btn_notify, View.GONE)
                trySetVisibility(views, R.id.btn_mic, View.VISIBLE)
            }
            DuoWidgetState.IDLE -> {
                when (feedback) {
                    DuoWidgetActionFeedback.Kind.RINGING -> {
                        trySetText(views, R.id.status_pill, "Ringing…")
                        trySetVisibility(views, R.id.status_pill, View.VISIBLE)
                    }
                    DuoWidgetActionFeedback.Kind.NOTIFIED -> {
                        trySetText(views, R.id.status_pill, "Notified")
                        trySetVisibility(views, R.id.status_pill, View.VISIBLE)
                    }
                    null -> trySetVisibility(views, R.id.status_pill, View.GONE)
                }
                trySetVisibility(views, R.id.live_label, View.GONE)
                trySetVisibility(views, R.id.btn_decline, View.GONE)
                trySetVisibility(views, R.id.btn_accept, View.GONE)
                trySetVisibility(views, R.id.btn_ring, View.VISIBLE)
                trySetVisibility(views, R.id.btn_notify, View.VISIBLE)
                trySetVisibility(views, R.id.btn_mic, View.VISIBLE)
            }
        }
    }

    private fun setActionIntents(
        context: Context,
        views: RemoteViews,
        appWidgetId: Int,
        groupId: String,
        groupName: String,
        responseUrl: String?,
        voiceNudgeEnabled: Boolean,
    ) {
        trySetClick(
            views,
            R.id.btn_next,
            broadcastIntent(context, appWidgetId, 1, DuoWidgetActionReceiver.actionNextGroup, groupId, null),
        )
        trySetClick(
            views,
            R.id.btn_ring,
            broadcastIntent(context, appWidgetId, 2, DuoWidgetActionReceiver.actionRing, groupId, null),
        )
        trySetClick(
            views,
            R.id.btn_notify,
            broadcastIntent(context, appWidgetId, 3, DuoWidgetActionReceiver.actionNotify, groupId, null),
        )
        trySetClick(
            views,
            R.id.btn_decline,
            broadcastIntent(context, appWidgetId, 4, DuoWidgetActionReceiver.actionDecline, groupId, responseUrl),
        )
        trySetClick(
            views,
            R.id.btn_accept,
            broadcastIntent(context, appWidgetId, 5, DuoWidgetActionReceiver.actionAccept, groupId, responseUrl),
        )
        if (voiceNudgeEnabled) {
            val micIntent = Intent(context, QuickRecordActivity::class.java).apply {
                putExtra(QuickRecordActivity.extraGroupId, groupId)
                putExtra(QuickRecordActivity.extraGroupName, groupName)
                // Overlay is singleInstance + empty affinity. CLEAR_TOP would
                // also resume the existing app task on some OEMs.
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            val micPendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId * 10 + 6,
                micIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            trySetClick(views, R.id.btn_mic, micPendingIntent)
        }
        // Do NOT also click-bind widget_root when children have actions —
        // some OEM hosts mishandle nested PendingIntents.
    }

    private fun broadcastIntent(
        context: Context,
        appWidgetId: Int,
        actionSlot: Int,
        action: String,
        groupId: String,
        responseUrl: String?,
    ): PendingIntent {
        val intent = Intent(context, DuoWidgetActionReceiver::class.java).apply {
            this.action = action
            // Unique data URI so OEM hosts cannot coalesce or accidentally
            // fire this PendingIntent when a sibling widget is rebound.
            data = android.net.Uri.parse("app.oneone.widget://$appWidgetId/$actionSlot")
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            putExtra(DuoWidgetActionReceiver.extraGroupId, groupId)
            if (!responseUrl.isNullOrBlank()) {
                putExtra(DuoWidgetActionReceiver.extraResponseUrl, responseUrl)
            }
        }
        return PendingIntent.getBroadcast(
            context,
            appWidgetId * 10 + actionSlot,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun openAppIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        return PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun pushFallback(
        context: Context,
        manager: AppWidgetManager,
        appWidgetId: Int,
    ) {
        DuoWidgetLog.w("R-90", "pushing fallback layout for id=$appWidgetId")
        try {
            val views = RemoteViews(context.packageName, R.layout.duo_widget_fallback)
            views.setTextViewText(R.id.group_name, "Duo")
            views.setTextViewText(R.id.status_pill, "Open the app")
            views.setOnClickPendingIntent(R.id.widget_root, openAppIntent(context))
            manager.updateAppWidget(appWidgetId, views)
            DuoWidgetLog.i("R-91", "fallback pushed OK id=$appWidgetId")
        } catch (error: Exception) {
            DuoWidgetLog.e("R-92", "fallback bind failed id=$appWidgetId", error)
            try {
                manager.updateAppWidget(
                    appWidgetId,
                    RemoteViews(context.packageName, R.layout.duo_widget_fallback),
                )
                DuoWidgetLog.i("R-93", "bare fallback pushed id=$appWidgetId")
            } catch (ignored: Exception) {
                DuoWidgetLog.e("R-94", "bare fallback FAILED id=$appWidgetId", ignored)
            }
        }
    }

    private fun trySetText(views: RemoteViews, id: Int, text: CharSequence) {
        try {
            views.setTextViewText(id, text)
        } catch (error: Exception) {
            DuoWidgetLog.w("R-30", "setTextViewText 0x${Integer.toHexString(id)}", error)
        }
    }

    private fun trySetVisibility(views: RemoteViews, id: Int, visibility: Int) {
        try {
            views.setViewVisibility(id, visibility)
        } catch (error: Exception) {
            DuoWidgetLog.w("R-31", "setViewVisibility 0x${Integer.toHexString(id)}", error)
        }
    }

    private fun trySetClick(views: RemoteViews, id: Int, intent: PendingIntent) {
        try {
            views.setOnClickPendingIntent(id, intent)
        } catch (error: Exception) {
            DuoWidgetLog.w("R-32", "setOnClickPendingIntent 0x${Integer.toHexString(id)}", error)
        }
    }
}
