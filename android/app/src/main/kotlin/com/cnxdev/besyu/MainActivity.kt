package com.cnxdev.besyu

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "med_reminder/app_settings",
        ).setMethodCallHandler { call, result ->
            if (call.method != "open") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val intent = Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:$packageName"),
            )
            startActivity(intent)
            result.success(true)
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "med_reminder/emergency_contact",
        ).setMethodCallHandler { call, result ->
            val phoneNumber = call.arguments as? String
            if (phoneNumber.isNullOrBlank()) {
                result.success(false)
                return@setMethodCallHandler
            }

            val intent = when (call.method) {
                "call" -> Intent(Intent.ACTION_DIAL, Uri.parse("tel:$phoneNumber"))
                "sms" -> Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:$phoneNumber"))
                else -> {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
            }

            if (intent.resolveActivity(packageManager) == null) {
                result.success(false)
                return@setMethodCallHandler
            }
            startActivity(intent)
            result.success(true)
        }
    }
}
