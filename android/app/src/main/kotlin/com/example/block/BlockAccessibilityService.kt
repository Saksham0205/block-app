package com.example.block

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
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

    /** Every installed app that can open web pages, not just well-known ones. */
    private var browserPackages: Set<String> = emptySet()
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
        browserPackages = findBrowsers()
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
                // Only browsers need content inspection (address bar changes).
                if (pkg == foregroundPackage && pkg in browserPackages) {
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

        if (pkg !in browserPackages) return
        if (root == null || root.packageName?.toString() != pkg) return

        // Any page under a blocked domain counts, whatever its path or query.
        for (host in browserHosts(root, pkg)) {
            active.firstOrNull { it.blocksHost(host) }?.let {
                block(it, host)
                return
            }
        }
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

    /** Packages that handle plain https links: Chrome, Firefox, Samsung… */
    private fun findBrowsers(): Set<String> {
        val probe = Intent(Intent.ACTION_VIEW, Uri.parse("https://example.com"))
            .addCategory(Intent.CATEGORY_BROWSABLE)
        val resolved = if (Build.VERSION.SDK_INT >= 33) {
            packageManager.queryIntentActivities(probe, PackageManager.ResolveInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            packageManager.queryIntentActivities(probe, 0)
        }
        return (resolved.map { it.activityInfo.packageName } + URL_BAR_IDS.keys)
            .toSet() - packageName
    }

    /**
     * Hosts currently shown in a browser's address bar. Tries the browser's
     * known view id first; if that yields nothing (a browser update renamed
     * it, or it's a browser we don't know), scans for anything that looks
     * like an address bar instead.
     */
    private fun browserHosts(root: AccessibilityNodeInfo, pkg: String): List<String> {
        val hosts = LinkedHashSet<String>()

        URL_BAR_IDS[pkg]?.forEach { id ->
            root.findAccessibilityNodeInfosByViewId(id).forEach { node ->
                node.text?.toString()?.let(UrlMatcher::hostOf)?.let(hosts::add)
            }
        }
        if (hosts.isEmpty()) scanForAddressBar(root, hosts)
        return hosts.toList()
    }

    /**
     * Breadth-first walk of the browser's own UI. Only nodes whose view id
     * looks like an address bar are read, so text inside web pages (which has
     * no view id) can never trigger a block.
     */
    private fun scanForAddressBar(root: AccessibilityNodeInfo, out: MutableSet<String>) {
        val queue = ArrayDeque<AccessibilityNodeInfo>()
        queue.add(root)
        var visited = 0
        while (queue.isNotEmpty() && visited < MAX_SCAN_NODES) {
            val node = queue.removeFirst()
            visited++

            val id = node.viewIdResourceName.orEmpty()
            if (id.isNotEmpty() && ADDRESS_ID_HINT.containsMatchIn(id)) {
                node.text?.toString()?.let(UrlMatcher::hostOf)?.let(out::add)
            }
            for (i in 0 until node.childCount) {
                node.getChild(i)?.let(queue::add)
            }
        }
    }

    companion object {
        private const val TICK_MS = 4_000L
        private const val DEBOUNCE_MS = 800L
        private const val MAX_SCAN_NODES = 400
        private val ADDRESS_ID_HINT =
            Regex("url|omnibox|address|location_bar|toolbar_edit", RegexOption.IGNORE_CASE)

        /** Address-bar view ids for popular browsers (fast path). */
        private val URL_BAR_IDS = mapOf(
            "com.android.chrome" to listOf("com.android.chrome:id/url_bar"),
            "com.chrome.beta" to listOf("com.chrome.beta:id/url_bar"),
            "com.chrome.dev" to listOf("com.chrome.dev:id/url_bar"),
            "com.chrome.canary" to listOf("com.chrome.canary:id/url_bar"),
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
