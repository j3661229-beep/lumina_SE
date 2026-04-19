package com.lumina.lumina

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.text.TextUtils
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

                    // Check if Accessibility Service (Focus Block) is enabled
                    "hasAccessibilityPermission" -> result.success(hasAccessibilityPermission())

                    // Open Settings → Accessibility to enable LuminaBlockService
                    "requestAccessibilityPermission" -> {
                        var opened = false

                        // Attempt 1: Standard accessibility settings (works on stock Android)
                        try {
                            startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                            })
                            opened = true
                        } catch (_: Exception) {}

                        // Attempt 2: Direct AOSP AccessibilitySettingsActivity component (MIUI fallback)
                        if (!opened) {
                            try {
                                startActivity(Intent().apply {
                                    component = android.content.ComponentName(
                                        "com.android.settings",
                                        "com.android.settings.Settings\$AccessibilitySettingsActivity"
                                    )
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                })
                                opened = true
                            } catch (_: Exception) {}
                        }

                        // Attempt 3: Generic settings as last resort
                        if (!opened) {
                            try {
                                startActivity(Intent(Settings.ACTION_SETTINGS).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                })
                                opened = true
                            } catch (_: Exception) {}
                        }

                        if (opened) result.success(null)
                        else result.error("SETTINGS_NOT_FOUND", "Cannot open Accessibility settings on this device", null)
                    }

                    // Open Android Settings → Usage Access screen
                    "requestUsagePermission" -> {
                        var opened = false
                        // Attempt 1: package-specific URI (preferred — scrolls to Lumina directly)
                        try {
                            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                                data = android.net.Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            opened = true
                        } catch (_: Exception) {}

                        // Attempt 2: generic usage access list
                        if (!opened) {
                            try {
                                val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(intent)
                                opened = true
                            } catch (_: Exception) {}
                        }

                        // Attempt 3: MIUI-specific settings page
                        if (!opened) {
                            try {
                                val intent = Intent().apply {
                                    component = android.content.ComponentName(
                                        "com.android.settings",
                                        "com.android.settings.Settings\$UsageAccessSettingsActivity"
                                    )
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(intent)
                                opened = true
                            } catch (_: Exception) {}
                        }

                        if (opened) result.success(null)
                        else result.error("SETTINGS_NOT_FOUND", "Cannot open Usage Access settings on this device", null)
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

                    // Get current foreground app (real-time, 3-second window)
                    "getForegroundApp" -> {
                        if (!hasUsagePermission()) {
                            result.error("NO_PERMISSION", "Usage stats permission not granted", null)
                            return@setMethodCallHandler
                        }
                        result.success(getCurrentForegroundApp())
                    }

                    // Get all user-installed apps for the DND blocklist picker
                    "getInstalledApps" -> result.success(getInstalledApps())

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

    private fun hasAccessibilityPermission(): Boolean {
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        val serviceId = "$packageName/${LuminaBlockService::class.java.name}"
        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(enabledServices)
        while (splitter.hasNext()) {
            val name = splitter.next()
            if (name.equals(serviceId, ignoreCase = true)) return true
        }
        return false
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

    /** Returns the package name currently in the foreground (last 3-second window). */
    private fun getCurrentForegroundApp(): Map<String, Any?>? {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        val queryEvents = usm.queryEvents(now - 3000L, now)
        val event = UsageEvents.Event()
        var lastFg: UsageEvents.Event? = null
        while (queryEvents.hasNextEvent()) {
            queryEvents.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                lastFg = UsageEvents.Event().also { e -> e.packageName; }
                // Re-query since we can't copy the event directly
            }
        }
        // Fallback: use queryUsageStats for a 5-second window
        val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_BEST, now - 5000L, now)
        if (stats.isNullOrEmpty()) return null
        val recent = stats.filter { it.lastTimeUsed > 0 }.maxByOrNull { it.lastTimeUsed } ?: return null
        val pkg = recent.packageName
        return mapOf(
            "packageName" to pkg,
            "appName" to (getAppLabel(pkg) ?: pkg),
            "lastUsed" to recent.lastTimeUsed,
        )
    }

    /** Returns list of all user-launcher-visible apps for the DND blocklist picker. */
    private fun getInstalledApps(): List<Map<String, String>> {
        val pm = packageManager
        val intent = android.content.Intent(android.content.Intent.ACTION_MAIN).apply {
            addCategory(android.content.Intent.CATEGORY_LAUNCHER)
        }
        return pm.queryIntentActivities(intent, 0)
            .map { ri ->
                val pkg = ri.activityInfo.packageName
                mapOf(
                    "packageName" to pkg,
                    "appName" to (pm.getApplicationLabel(ri.activityInfo.applicationInfo).toString()),
                )
            }
            .filter { it["packageName"] != packageName } // exclude Lumina itself
            .distinctBy { it["packageName"] }
            .sortedBy { it["appName"] }
    }

    private fun getAppLabel(packageName: String): String? = try {
        val pm = packageManager
        val info = pm.getApplicationInfo(packageName, 0)
        pm.getApplicationLabel(info).toString()
    } catch (_: Exception) { null }
}
