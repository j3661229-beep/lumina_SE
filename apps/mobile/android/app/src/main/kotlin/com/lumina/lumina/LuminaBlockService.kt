package com.lumina.lumina

import android.accessibilityservice.AccessibilityService
import android.content.SharedPreferences
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import org.json.JSONArray

/**
 * LuminaBlockService — Accessibility Service that enforces the DND blocklist.
 *
 * When DND mode is ON and the user opens a blocked app, this service fires
 * performGlobalAction(GLOBAL_ACTION_HOME) immediately, sending them back to
 * the home screen before the blocked app renders.
 *
 * Shared state with Flutter via the default SharedPreferences file:
 *   • cs_dnd_enabled  → Boolean
 *   • cs_blocked_apps → JSON array of package name strings
 *   • cs_block_active → Boolean (true only while a block is firing, prevents loops)
 */
class LuminaBlockService : AccessibilityService() {

    companion object {
        private const val TAG = "LuminaBlock"
        private const val PREFS   = "FlutterSharedPreferences"
        private const val KEY_DND = "flutter.cs_dnd_enabled"
        private const val KEY_APPS = "flutter.cs_blocked_apps"
        // Packages that should never be blocked (system / Lumina itself)
        private val WHITELIST = setOf(
            "com.lumina.lumina",
            "com.android.launcher",
            "com.android.launcher2",
            "com.android.launcher3",
            "com.miui.home",
            "com.sec.android.app.launcher",
            "com.huawei.android.launcher",
            "com.android.systemui",
        )
    }

    private lateinit var prefs: SharedPreferences
    private var lastBlockedPkg: String? = null
    private var lastBlockTime: Long = 0L

    override fun onServiceConnected() {
        super.onServiceConnected()
        prefs = applicationContext
            .getSharedPreferences(PREFS, MODE_PRIVATE)
        Log.d(TAG, "LuminaBlockService connected ✅")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return
        if (pkg.isBlank() || WHITELIST.contains(pkg)) return

        // Debounce: don't re-block the same package within 2 seconds
        val now = System.currentTimeMillis()
        if (pkg == lastBlockedPkg && now - lastBlockTime < 2000) return

        val dndEnabled = prefs.getBoolean(KEY_DND, false)
        if (!dndEnabled) return

        val blockedRaw = prefs.getString(KEY_APPS, "[]") ?: "[]"
        val blockedList = runCatching {
            val arr = JSONArray(blockedRaw)
            (0 until arr.length()).map { arr.getString(it) }.toSet()
        }.getOrDefault(emptySet())

        if (blockedList.contains(pkg)) {
            Log.d(TAG, "🚫 Blocking $pkg → sending to home")
            lastBlockedPkg = pkg
            lastBlockTime = now
            performGlobalAction(GLOBAL_ACTION_HOME)
        }
    }

    override fun onInterrupt() {
        Log.d(TAG, "LuminaBlockService interrupted")
    }
}
