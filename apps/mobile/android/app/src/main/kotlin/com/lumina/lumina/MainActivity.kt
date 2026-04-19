package com.lumina.lumina

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CONTEXT_CHANNEL = "com.lumina/context_switch"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CONTEXT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Check if PACKAGE_USAGE_STATS permission is granted
                    "hasUsagePermission" -> result.success(hasUsagePermission())

                    // Open Android Settings → Usage Access screen
                    "requestUsagePermission" -> {
                        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(null)
                    }

                    // Get foreground app events for the last N minutes
                    // Returns list of {packageName, appName, startTime, endTime, durationMs}
                    "getRecentEvents" -> {
                        val minutes = (call.argument<Int>("minutes") ?: 60).toLong()
                        if (!hasUsagePermission()) {
                            result.error("NO_PERMISSION", "Usage stats permission not granted", null)
                            return@setMethodCallHandler
                        }
                        result.success(getRecentEvents(minutes))
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun hasUsagePermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun getRecentEvents(windowMinutes: Long): List<Map<String, Any?>> {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val endTime = System.currentTimeMillis()
        val startTime = endTime - windowMinutes * 60 * 1000

        val events = UsageEvents.Event()
        val query = usm.queryEvents(startTime, endTime)

        // Collect foreground events grouped into sessions
        val result = mutableListOf<Map<String, Any?>>()
        var lastFgPackage: String? = null
        var lastFgTime: Long = 0L

        while (query.hasNextEvent()) {
            query.getNextEvent(events)

            if (events.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                // Close previous session
                if (lastFgPackage != null && lastFgPackage != events.packageName) {
                    result.add(mapOf(
                        "packageName" to lastFgPackage,
                        "appName" to (getAppLabel(lastFgPackage!!) ?: lastFgPackage),
                        "startTime" to lastFgTime,
                        "endTime" to events.timeStamp,
                        "durationMs" to (events.timeStamp - lastFgTime),
                    ))
                }
                lastFgPackage = events.packageName
                lastFgTime = events.timeStamp

            } else if (events.eventType == UsageEvents.Event.MOVE_TO_BACKGROUND) {
                if (lastFgPackage == events.packageName) {
                    result.add(mapOf(
                        "packageName" to events.packageName,
                        "appName" to (getAppLabel(events.packageName) ?: events.packageName),
                        "startTime" to lastFgTime,
                        "endTime" to events.timeStamp,
                        "durationMs" to (events.timeStamp - lastFgTime),
                    ))
                    lastFgPackage = null
                }
            }
        }

        // Close any ongoing session
        if (lastFgPackage != null) {
            result.add(mapOf(
                "packageName" to lastFgPackage,
                "appName" to (getAppLabel(lastFgPackage!!) ?: lastFgPackage),
                "startTime" to lastFgTime,
                "endTime" to endTime,
                "durationMs" to (endTime - lastFgTime),
            ))
        }

        return result.takeLast(50) // cap at 50 events for performance
    }

    private fun getAppLabel(packageName: String): String? = try {
        val pm = packageManager
        val info = pm.getApplicationInfo(packageName, 0)
        pm.getApplicationLabel(info).toString()
    } catch (_: Exception) { null }
}
