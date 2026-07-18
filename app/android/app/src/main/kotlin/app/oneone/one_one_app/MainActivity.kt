package app.oneone.one_one_app

import com.google.firebase.messaging.FirebaseMessaging
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            VoiceNudgeContract.flutterChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getFcmToken" -> FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
                    if (task.isSuccessful && !task.result.isNullOrBlank()) {
                        VoiceNudgeTokenStore.save(this, task.result)
                        result.success(task.result)
                    } else {
                        result.error(
                            "fcm_token_unavailable",
                            task.exception?.message ?: "FCM token is unavailable.",
                            null,
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}
