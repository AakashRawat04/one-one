package app.oneone.one_one_app

import android.content.Context

object InviteLinkContract {
    const val flutterChannel = "app.oneone/invite_links"
    const val customScheme = "oneone"
    const val inviteHost = "invite"
    const val httpsHost = "one-one-xw00.onrender.com"

    private const val preferencesName = "one_one_invite_links"
    private const val pendingCodeKey = "pending_invite_code"

    fun savePendingCode(context: Context, code: String) {
        context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
            .edit()
            .putString(pendingCodeKey, code)
            .apply()
    }

    fun peekPendingCode(context: Context): String? =
        context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
            .getString(pendingCodeKey, null)
            ?.takeIf { it.isNotBlank() }

    fun clearPendingCode(context: Context, expectedCode: String) {
        val preferences = context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
        if (preferences.getString(pendingCodeKey, null) != expectedCode) return
        preferences.edit().remove(pendingCodeKey).apply()
    }
}
