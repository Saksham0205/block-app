package com.example.block

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.view.inputmethod.InputMethodManager

/**
 * Watches which app is in the foreground (and, for browsers, which site is in
 * the address bar) and covers it with [BlockActivity] when a rule that is
 * currently active says it's off-limits.
 *
 * Everything is evaluated on-device; no content is stored or sent anywhere.
 */
class BlockAccessibilityService : AccessibilityService() {

    private val handler = Handler(Looper.getMainLooper())

    private var rules: List<Rule> = emptyList()
    private var foregroundPackage: String? = null
    private var ignoredPackages: Set<String> = emptySet()
    private var lastBlockAt = 0L

    private val prefsListener =
        SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
            if (key == RuleStore.KEY_RULES) {
                rules = RuleStore.load(this)
                recheckForeground()
            }
        }

    /** Catches the case where a slot *starts* while a blocked app is open. */
    private val ticker = object : Runnable {
        override fun run() {
            recheckForeground()
            handler.postDelayed(this, TICK_MS)
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        rules = RuleStore.load(this)
        ignoredPackages = buildSet {
            add("com.android.systemui")
            add(packageName)
            val imm = getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager
            imm.enabledInputMethodList.forEach { add(it.packageName) }
        }
        getSharedPreferences(RuleStore.PREFS, MODE_PRIVATE)
            .registerOnSharedPreferenceChangeListener(prefsListener)
        handler.postDelayed(ticker, TICK_MS)
    }

    override fun onDestroy() {
        handler.removeCallbacks(ticker)
        getSharedPreferences(RuleStore.PREFS, MODE_PRIVATE)
            .unregisterOnSharedPreferenceChangeListener(prefsListener)
        super.onDestroy()
    }

    override fun onInterrupt() = Unit

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        val pkg = event.packageName?.toString() ?: return

        // Our own block screen counts as "foreground" so we don't re-trigger
        // on top of it, but keyboards / system UI must not steal the state.
        if (pkg == packageName) {
            foregroundPackage = pkg
            return
        }
        if (pkg in ignoredPackages) return

        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                foregroundPackage = pkg
                evaluate(pkg, rootInActiveWindow)
            }
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                // Only browsers need content inspection (URL bar changes).
                if (pkg in URL_BAR_IDS && pkg == foregroundPackage) {
                    evaluate(pkg, rootInActiveWindow)
                }
            }
        }
    }

    private fun recheckForeground() {
        val pkg = foregroundPackage ?: return
        if (pkg == packageName) return
        evaluate(pkg, rootInActiveWindow)
    }

    private fun evaluate(pkg: String, root: AccessibilityNodeInfo?) {
        val active = rules.filter { it.isActive() }
        if (active.isEmpty()) return

        active.firstOrNull { it.blocksApp(pkg) }?.let {
            block(it, appLabel(pkg))
            return
        }

        if (root == null || root.packageName?.toString() != pkg) return
        val host = readBrowserHost(root, pkg) ?: return
        active.firstOrNull { it.blocksHost(host) }?.let { block(it, host) }
    }

    private fun block(rule: Rule, target: String) {
        val now = System.currentTimeMillis()
        if (now - lastBlockAt < DEBOUNCE_MS) return
        lastBlockAt = now

        startActivity(
            Intent(this, BlockActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_NO_ANIMATION
                )
                putExtra(BlockActivity.EXTRA_TARGET, target)
                putExtra(BlockActivity.EXTRA_RULE_NAME, rule.name)
                putExtra(BlockActivity.EXTRA_END_MINUTE, rule.endMinute)
            }
        )
    }

    private fun appLabel(pkg: String): String = try {
        packageManager.getApplicationLabel(packageManager.getApplicationInfo(pkg, 0))
            .toString()
    } catch (e: Exception) {
        pkg
    }

    /** Returns the bare host currently shown in a known browser's URL bar. */
    private fun readBrowserHost(root: AccessibilityNodeInfo, pkg: String): String? {
        val ids = URL_BAR_IDS[pkg] ?: return null
        for (id in ids) {
            val text = root.findAccessibilityNodeInfosByViewId(id)
                .firstOrNull()?.text?.toString()
            if (!text.isNullOrBlank()) return extractHost(text)
        }
        return null
    }

    private fun extractHost(text: String): String? {
        var value = text.trim().lowercase()
        if (value.contains(' ')) return null // a search query, not a URL
        value = value.replaceFirst(Regex("^[a-z][a-z0-9+.-]*://"), "")
        value = value.split('/', '?', '#').first()
        value = value.substringAfterLast('@').replaceFirst(Regex(":\\d+$"), "")
        value = value.removePrefix("www.")
        return value.takeIf { it.contains('.') && it.matches(HOST_REGEX) }
    }

    companion object {
        private const val TICK_MS = 4_000L
        private const val DEBOUNCE_MS = 1_200L
        private val HOST_REGEX = Regex("^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$")

        /** Address-bar view ids for popular browsers. */
        private val URL_BAR_IDS = mapOf(
            "com.android.chrome" to listOf("com.android.chrome:id/url_bar"),
            "com.chrome.beta" to listOf("com.chrome.beta:id/url_bar"),
            "com.chrome.dev" to listOf("com.chrome.dev:id/url_bar"),
            "com.brave.browser" to listOf("com.brave.browser:id/url_bar"),
            "com.microsoft.emmx" to listOf("com.microsoft.emmx:id/url_bar"),
            "com.vivaldi.browser" to listOf("com.vivaldi.browser:id/url_bar"),
            "com.opera.browser" to listOf("com.opera.browser:id/url_field"),
            "com.sec.android.app.sbrowser" to listOf(
                "com.sec.android.app.sbrowser:id/location_bar_edit_text"
            ),
            "org.mozilla.firefox" to listOf(
                "org.mozilla.firefox:id/mozac_browser_toolbar_url_view",
                "org.mozilla.firefox:id/url_bar_title",
            ),
            "com.duckduckgo.mobile.android" to listOf(
                "com.duckduckgo.mobile.android:id/omnibarTextInput"
            ),
        )
    }
}
