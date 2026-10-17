package com.palengkego.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var orderOverlayChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        orderOverlayChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "palengkego/order_overlay"
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "canDrawOverlays" -> result.success(
                        Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
                            Settings.canDrawOverlays(applicationContext)
                    )
                    "requestPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                            !Settings.canDrawOverlays(this)
                        ) {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                            startActivity(intent)
                        }
                        result.success(null)
                    }
                    "show" -> {
                        val count = call.argument<Int>("count") ?: 0
                        OrderOverlayWindow.show(applicationContext, count)
                        result.success(null)
                    }
                    "hide" -> {
                        OrderOverlayWindow.hide()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getBooleanExtra("open_active_orders", false)) {
            orderOverlayChannel?.invokeMethod("openActiveOrders", null)
        }
    }
}
