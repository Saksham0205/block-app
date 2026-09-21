package com.example.block

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.LayerDrawable
import android.os.Bundle
import android.text.format.DateFormat
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import java.util.Calendar

/** Full-screen "this is blocked right now" page shown over the blocked app. */
class BlockActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val target = intent.getStringExtra(EXTRA_TARGET).orEmpty()
        val ruleName = intent.getStringExtra(EXTRA_RULE_NAME).orEmpty()
        val endMinute = intent.getIntExtra(EXTRA_END_MINUTE, -1)

        // Same palette as the Flutter app: near-black, coral = "locked".
        val bg = Color.parseColor("#0D0D0D")
        val fg = Color.parseColor("#F5F5F5")
        val muted = Color.parseColor("#8E8E93")
        val accent = Color.parseColor("#FF4D67")

        val untilText = if (endMinute >= 0) {
            val cal = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, endMinute / 60)
                set(Calendar.MINUTE, endMinute % 60)
            }
            " until ${DateFormat.getTimeFormat(this).format(cal.time)}"
        } else ""

        fun dp(v: Int) = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics
        ).toInt()

        val icon = TextView(this).apply {
            text = "🔒"
            textSize = 40f
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(8).toFloat()
                setColor(Color.argb(38, Color.red(accent), Color.green(accent), Color.blue(accent)))
                setStroke(dp(1), Color.argb(140, Color.red(accent), Color.green(accent), Color.blue(accent)))
            }
            layoutParams = LinearLayout.LayoutParams(dp(96), dp(96))
        }

        val title = TextView(this).apply {
            text = if (target.isNotEmpty()) "$target is blocked" else "Blocked"
            setTextColor(fg)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 30f)
            typeface = Typeface.create("sans-serif-black", Typeface.NORMAL)
            gravity = Gravity.CENTER
            setPadding(0, dp(28), 0, dp(8))
        }

        val body = TextView(this).apply {
            text = "“$ruleName” keeps this off-limits$untilText.\nGet back to what you set out to do."
            setTextColor(muted)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            gravity = Gravity.CENTER
            setLineSpacing(0f, 1.25f)
        }

        // NeoPOP-style button: white face sitting on a hard grey edge.
        val edge = dp(5)
        val button = Button(this).apply {
            text = "Go home"
            isAllCaps = false
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 17f)
            typeface = Typeface.create("sans-serif-black", Typeface.NORMAL)
            setTextColor(bg)
            background = LayerDrawable(
                arrayOf(
                    GradientDrawable().apply { cornerRadius = dp(2).toFloat(); setColor(Color.parseColor("#8A8A8A")) },
                    GradientDrawable().apply { cornerRadius = dp(2).toFloat(); setColor(Color.WHITE) },
                )
            ).also { it.setLayerInset(1, 0, 0, edge, edge) }
            setPadding(0, 0, edge, edge)
            stateListAnimator = null
            setOnClickListener { goHome() }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dp(60)
            ).apply { topMargin = dp(40) }
        }

        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(32), dp(32), dp(32), dp(32))
            setBackgroundColor(bg)
            addView(icon)
            addView(title)
            addView(body)
            addView(button)
        }
        setContentView(column)

        // Draw edge-to-edge behind system bars while keeping content padded.
        column.setOnApplyWindowInsetsListener { v, insets ->
            v.setPadding(
                dp(32), insets.systemWindowInsetTop + dp(32),
                dp(32), insets.systemWindowInsetBottom + dp(32)
            )
            insets
        }
        window.decorView.systemUiVisibility =
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
    }

    @Deprecated("Back always leads home, never back into the blocked app")
    override fun onBackPressed() = goHome()

    private fun goHome() {
        startActivity(
            Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        )
        finish()
    }

    companion object {
        const val EXTRA_TARGET = "target"
        const val EXTRA_RULE_NAME = "rule_name"
        const val EXTRA_END_MINUTE = "end_minute"
    }
}
