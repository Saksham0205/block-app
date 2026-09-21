package com.example.block

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    private val worker = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(::onCall)
    }

    private fun onCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getInstalledApps" -> worker.execute {
                try {
                    val apps = loadInstalledApps()
                    mainHandler.post { result.success(apps) }
                } catch (e: Exception) {
                    mainHandler.post { result.error("apps", e.message, null) }
                }
            }

            "saveRules" -> {
                RuleStore.save(this, call.argument<List<*>>("rules") ?: emptyList<Any>())
                result.success(null)
            }

            "isServiceEnabled" -> result.success(isServiceEnabled())

            "openAccessibilitySettings" -> {
                startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                result.success(null)
            }

            "openAppInfo" -> {
                startActivity(
                    Intent(
                        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.fromParts("package", packageName, null)
                    )
                )
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun isServiceEnabled(): Boolean {
        val enabled = Settings.Secure.getString(
            contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        val component = ComponentName(this, BlockAccessibilityService::class.java)
        val forms = setOf(component.flattenToString(), component.flattenToShortString())
        return enabled.split(':').any { it in forms }
    }

    /** Every app that has a launcher icon, except this one. */
    private fun loadInstalledApps(): List<Map<String, Any?>> {
        val pm = packageManager
        val query = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val resolved: List<ResolveInfo> =
            if (Build.VERSION.SDK_INT >= 33) {
                pm.queryIntentActivities(query, PackageManager.ResolveInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                pm.queryIntentActivities(query, 0)
            }

        return resolved
            .distinctBy { it.activityInfo.packageName }
            .filter { it.activityInfo.packageName != packageName }
            .map { info ->
                mapOf(
                    "package" to info.activityInfo.packageName,
                    "label" to info.loadLabel(pm).toString(),
                    "icon" to toPng(info.loadIcon(pm)),
                )
            }
    }

    private fun toPng(drawable: Drawable, size: Int = 96): ByteArray {
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        drawable.setBounds(0, 0, size, size)
        drawable.draw(Canvas(bitmap))
        return ByteArrayOutputStream().also {
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
            bitmap.recycle()
        }.toByteArray()
    }

    override fun onDestroy() {
        worker.shutdown()
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL = "com.example.block/native"
    }
}
