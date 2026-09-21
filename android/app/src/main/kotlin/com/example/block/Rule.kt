package com.example.block

import android.content.Context
import org.json.JSONArray
import java.util.Calendar

/** Native mirror of the Dart `BlockRule`. Kept in sync via [RuleStore]. */
data class Rule(
    val id: String,
    val name: String,
    val apps: Set<String>,
    val domains: List<String>,
    val days: Set<Int>, // ISO: 1 = Monday … 7 = Sunday
    val startMinute: Int,
    val endMinute: Int,
    val enabled: Boolean,
) {
    fun isActive(now: Calendar = Calendar.getInstance()): Boolean {
        if (!enabled) return false
        val minute = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        val today = isoDay(now)

        if (endMinute > startMinute) {
            return today in days && minute >= startMinute && minute < endMinute
        }
        // Overnight (or all-day when start == end): the evening belongs to the
        // start day, the early morning to the day after it.
        if (minute >= startMinute) return today in days
        if (minute < endMinute) return (if (today == 1) 7 else today - 1) in days
        return false
    }

    fun blocksApp(packageName: String) = packageName in apps

    fun blocksHost(host: String) =
        domains.any { host == it || host.endsWith(".$it") }

    private fun isoDay(c: Calendar) = (c.get(Calendar.DAY_OF_WEEK) + 5) % 7 + 1
}

object RuleStore {
    const val PREFS = "block_native"
    const val KEY_RULES = "rules"

    fun save(context: Context, rules: List<*>) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_RULES, JSONArray(rules).toString())
            .apply()
    }

    fun load(context: Context): List<Rule> {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_RULES, null) ?: return emptyList()
        return try {
            val array = JSONArray(raw)
            (0 until array.length()).map { i ->
                val o = array.getJSONObject(i)
                Rule(
                    id = o.getString("id"),
                    name = o.optString("name"),
                    apps = o.optJSONArray("apps").toStrings().toSet(),
                    domains = o.optJSONArray("domains").toStrings(),
                    days = o.optJSONArray("days").toInts().toSet(),
                    startMinute = o.optInt("startMinute"),
                    endMinute = o.optInt("endMinute"),
                    enabled = o.optBoolean("enabled", true),
                )
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun JSONArray?.toStrings(): List<String> =
        if (this == null) emptyList() else (0 until length()).map { getString(it) }

    private fun JSONArray?.toInts(): List<Int> =
        if (this == null) emptyList() else (0 until length()).map { getInt(it) }
}
