package com.example.my_app

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.my_app/datetime_setting"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "isAutomaticTimeEnabled") {
                val isAutoTime = Settings.Global.getInt(
                    contentResolver,
                    Settings.Global.AUTO_TIME,
                    0
                ) == 1
                result.success(isAutoTime)
            } else if (call.method == "openDateTimeSettings") {
                try {
                    val intent = Intent(Settings.ACTION_DATE_SETTINGS).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("ERROR", "Could not open date settings: ${e.message}", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
