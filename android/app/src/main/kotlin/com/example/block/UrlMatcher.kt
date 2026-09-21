package com.example.block

/**
 * Turns whatever a browser shows in its address bar into a bare host, and
 * decides whether that host belongs to a blocked domain.
 *
 * A blocked domain covers *everything* on it: any path, query string,
 * fragment, scheme, port, `www.` and any subdomain. `x.com` therefore blocks
 * `x.com/home`, `https://mobile.x.com/a/b?c=d#e`, and so on, but never
 * `max.com` or `x.com.evil.example`.
 */
object UrlMatcher {

    // [scheme://][user@]host[:port] followed by end, a path/query/fragment
    // start, or an ellipsis (browsers truncate long URLs). Anchored at the
    // start so ordinary sentences never match; a space right after the host
    // (a search query like "x.com is down") is rejected by the tail.
    private val URLISH = Regex(
        "^(?:[a-z][a-z0-9+.-]*://)?(?:[^/?#@\\s]*@)?" +
            "((?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,})\\.?" +
            "(?::\\d+)?(?:[/?#…]|$)"
    )

    /** The host shown in [text], without `www.`, or null if it isn't a URL. */
    fun hostOf(text: String): String? {
        val cleaned = text.trim().lowercase().trimStart { !it.isLetterOrDigit() }
        val match = URLISH.find(cleaned) ?: return null
        return match.groupValues[1].removePrefix("www.")
    }

    /** True if [host] is [domain] itself or any subdomain of it. */
    fun matches(host: String, domain: String): Boolean =
        host == domain || host.endsWith(".$domain")

    fun matchesAny(host: String, domains: Collection<String>): Boolean =
        domains.any { matches(host, it) }
}
