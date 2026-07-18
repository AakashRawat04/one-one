package app.oneone.one_one_app

import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import com.google.firebase.FirebaseApp
import com.google.firebase.installations.FirebaseInstallations
import com.google.firebase.messaging.FirebaseMessaging
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        logFirebaseRuntimeConfiguration()
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            VoiceNudgeContract.flutterChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                // Keep the channel name for compatibility with existing Dart and
                // database records. New SDKs return the registered Firebase
                // Installation ID rather than a legacy registration token.
                "getFcmToken" -> {
                    Log.i(
                        VoiceNudgeDiagnostics.tag,
                        "[FCM-02] Flutter requested FCM installation registration",
                    )
                    FirebaseMessaging.getInstance().register()
                        .addOnCompleteListener registration@{ registrationTask ->
                            if (!registrationTask.isSuccessful) {
                                VoiceNudgeDiagnostics.logFailure(
                                    "[FCM-E1] FCM installation registration",
                                    registrationTask.exception,
                                )
                                result.error(
                                    "fcm_registration_failed",
                                    registrationTask.exception?.message
                                        ?: "FCM installation registration failed.",
                                    null,
                                )
                                return@registration
                            }

                            Log.i(
                                VoiceNudgeDiagnostics.tag,
                                "[FCM-03] FCM backend registration completed",
                            )
                            FirebaseInstallations.getInstance().id
                                .addOnCompleteListener idLookup@{ idTask ->
                                    val installationId =
                                        if (idTask.isSuccessful) idTask.result else null
                                    if (idTask.isSuccessful && !installationId.isNullOrBlank()) {
                                        Log.i(
                                            VoiceNudgeDiagnostics.tag,
                                            "[FCM-04] Firebase Installation ID resolved " +
                                                VoiceNudgeDiagnostics.describeIdentifier(
                                                    installationId,
                                                ),
                                        )
                                        VoiceNudgeTokenStore.save(this, installationId)
                                        result.success(installationId)
                                        return@idLookup
                                    }

                                    VoiceNudgeDiagnostics.logFailure(
                                        "[FCM-E2] Firebase Installation ID lookup",
                                        idTask.exception,
                                    )
                                    result.error(
                                        "fcm_installation_id_unavailable",
                                        idTask.exception?.message
                                            ?: "Firebase Installation ID is unavailable.",
                                        null,
                                    )
                                }
                        }
                }

                else -> result.notImplemented()
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun logFirebaseRuntimeConfiguration() {
        try {
            val firebaseApp = FirebaseApp.getInstance()
            val options = firebaseApp.options
            val applicationInfo = packageManager.getApplicationInfo(
                packageName,
                PackageManager.GET_META_DATA,
            )
            val installationIdEnabled = applicationInfo.metaData?.getBoolean(
                "firebase_messaging_installation_id_enabled",
                false,
            ) ?: false
            val googlePlayServicesVersion = try {
                packageManager.getPackageInfo("com.google.android.gms", 0).versionName
            } catch (_: PackageManager.NameNotFoundException) {
                "missing"
            }

            Log.i(
                VoiceNudgeDiagnostics.tag,
                "[FCM-01] runtime configuration " +
                    "package=$packageName " +
                    "build=${if (BuildConfig.DEBUG) "debug" else "release"} " +
                    "signingSha1=${signingCertificateSha1() ?: "unavailable"} " +
                    "firebaseAppId=${options.applicationId} " +
                    "projectId=${options.projectId} " +
                    "senderId=${options.gcmSenderId} " +
                    "installationIdEnabled=$installationIdEnabled " +
                    "autoInit=${FirebaseMessaging.getInstance().isAutoInitEnabled} " +
                    "googlePlayServices=$googlePlayServicesVersion",
            )
        } catch (error: RuntimeException) {
            VoiceNudgeDiagnostics.logFailure(
                "[FCM-E0] Firebase runtime configuration",
                error,
            )
        }
    }

    @Suppress("DEPRECATION")
    private fun signingCertificateSha1(): String? {
        val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageManager.getPackageInfo(
                packageName,
                PackageManager.GET_SIGNING_CERTIFICATES,
            )
        } else {
            packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
        }
        val signature = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageInfo.signingInfo?.apkContentsSigners?.firstOrNull()
        } else {
            packageInfo.signatures?.firstOrNull()
        } ?: return null
        return MessageDigest.getInstance("SHA-1")
            .digest(signature.toByteArray())
            .joinToString(":") { byte -> "%02X".format(byte) }
    }
}
