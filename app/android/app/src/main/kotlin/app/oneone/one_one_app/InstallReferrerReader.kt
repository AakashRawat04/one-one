package app.oneone.one_one_app

import android.content.Context
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import com.android.installreferrer.api.ReferrerDetails
import java.net.URLDecoder

/**
 * Reads the Play Install Referrer on first launch to recover an invite code
 * that was embedded in the Play Store link the user followed.
 *
 * Flow:
 *  1. Inviting user shares https://one-one-xw00.onrender.com/invite/<CODE>
 *  2. Recipient (no app) taps it → backend redirects to Play Store with
 *     ?referrer=inviteCode%3D<CODE>
 *  3. Play Store records the referrer and delivers it on first app launch.
 *  4. This reader parses the referrer, saves the code via InviteLinkContract,
 *     and the existing _joinPendingInvite() in StartupGateScreen picks it up.
 *
 * Safe to call on every cold start — it only writes when it finds a new code
 * and there is no pending code already queued.
 */
object InstallReferrerReader {

    private const val TAG = "OneOneInviteReferrer"
    private const val INVITE_CODE_KEY = "inviteCode"

    fun readOnce(context: Context) {
        // Don't overwrite a code that arrived via a direct App Link tap.
        if (InviteLinkContract.peekPendingCode(context) != null) return

        val client = InstallReferrerClient.newBuilder(context).build()
        client.startConnection(object : InstallReferrerStateListener {
            override fun onInstallReferrerSetupFinished(responseCode: Int) {
                try {
                    if (responseCode != InstallReferrerClient.InstallReferrerResponse.OK) {
                        Log.d(TAG, "Install referrer not available (code=$responseCode)")
                        return
                    }
                    val details: ReferrerDetails = client.installReferrer
                    val rawReferrer = details.installReferrer ?: return
                    Log.d(TAG, "Raw install referrer: $rawReferrer")

                    // The referrer value is URL-encoded on the Play Store side.
                    // e.g. "inviteCode%3DABCDE" → "inviteCode=ABCDE"
                    val decoded = try {
                        URLDecoder.decode(rawReferrer, "UTF-8")
                    } catch (_: Exception) {
                        rawReferrer
                    }

                    // Parse key=value pairs separated by & (standard referrer format)
                    val params = decoded.split("&").mapNotNull { pair ->
                        val idx = pair.indexOf('=')
                        if (idx < 1) null else pair.substring(0, idx) to pair.substring(idx + 1)
                    }.toMap()

                    val inviteCode = params[INVITE_CODE_KEY]
                        ?.trim()
                        ?.uppercase()
                        ?.takeIf { it.matches(Regex("[A-Z0-9_-]{4,64}")) }
                        ?: return

                    Log.i(TAG, "Recovered invite code from referrer codeSuffix=${inviteCode.takeLast(4)}")
                    InviteLinkContract.savePendingCode(context, inviteCode)
                } finally {
                    try { client.endConnection() } catch (_: Exception) {}
                }
            }

            override fun onInstallReferrerServiceDisconnected() {
                Log.d(TAG, "Install referrer service disconnected")
            }
        })
    }
}
