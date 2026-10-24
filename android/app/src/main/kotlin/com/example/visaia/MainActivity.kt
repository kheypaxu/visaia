package com.example.visaia

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "visaia/dashboard_widget")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "update" -> {
                            val bytes = call.arguments as? ByteArray
                            if (bytes == null) {
                                result.error("invalid_image", "Expected PNG bytes", null)
                            } else {
                                DashboardWidgetProvider.save(this, bytes)
                                result.success(null)
                            }
                        }
                        "clear" -> {
                            DashboardWidgetProvider.clear(this)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("widget_error", error.message, null)
                }
            }
    }
}
