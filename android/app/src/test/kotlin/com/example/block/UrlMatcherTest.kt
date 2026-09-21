package com.example.block

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class UrlMatcherTest {

    private fun blocked(text: String, domain: String): Boolean {
        val host = UrlMatcher.hostOf(text) ?: return false
        return UrlMatcher.matches(host, domain)
    }

    @Test
    fun everyPathQueryAndFragmentOfABlockedDomainIsBlocked() {
        val urls = listOf(
            "x.com",
            "x.com/",
            "x.com/home",
            "x.com/home?ref=1",
            "x.com/i/flow/login?redirect_after_login=%2Fhome#top",
            "https://x.com/home",
            "http://x.com/elonmusk/status/123?s=20&t=abc",
            "https://www.x.com/home",
            "https://mobile.x.com/home",
            "HTTPS://X.COM/HOME",
            "  x.com/home  ",
            "x.com:443/home",
            "https://user:pw@x.com/home",
            "x.com.",
            "x.com/very/long/path/that/the/browser/trunc…",
            "x.com…",
        )
        for (u in urls) assertTrue("should block: $u", blocked(u, "x.com"))
    }

    @Test
    fun lookalikeHostsAreNotBlocked() {
        val urls = listOf(
            "max.com/home",
            "notx.com",
            "x.com.evil.example/home",
            "example.com/x.com",
            "example.com/?u=x.com",
            "xx.com",
        )
        for (u in urls) assertFalse("should NOT block: $u", blocked(u, "x.com"))
    }

    @Test
    fun searchQueriesAndPlainTextAreNotUrls() {
        assertNull(UrlMatcher.hostOf("x.com is down"))
        assertNull(UrlMatcher.hostOf("Search or type web address"))
        assertNull(UrlMatcher.hostOf("hello"))
        assertNull(UrlMatcher.hostOf(""))
        assertNull(UrlMatcher.hostOf("localhost"))
    }

    @Test
    fun subdomainRulesOnlyCoverThatSubdomain() {
        assertTrue(blocked("https://m.youtube.com/watch?v=1", "youtube.com"))
        assertTrue(blocked("music.youtube.com", "youtube.com"))
        assertFalse(blocked("youtube.com", "music.youtube.com"))
    }

    @Test
    fun hostIsExtractedWithoutWww() {
        assertEquals("reddit.com", UrlMatcher.hostOf("https://www.reddit.com/r/all?x=1"))
    }
}
