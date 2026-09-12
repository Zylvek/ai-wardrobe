package com.example.wardrobe_ai

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ai_wardrobe/install",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("args", "path is required", null)
                    } else {
                        installApk(path)
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /// Запускает системный установщик APK.
    private fun installApk(path: String) {
        // На Android 8+ нужно разрешение «устанавливать неизвестные
        // приложения» для нашего приложения. Если его нет — открываем
        // системную настройку, пользователь вернётся и нажмёт ещё раз.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            val intent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName"),
            )
            startActivity(intent)
            return
        }
        val file = File(path)
        val uri = FileProvider.getUriForFile(
            this, "$packageName.fileProvider", file,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_ACTIVITY_NEW_TASK,
            )
        }
        startActivity(intent)
    }
}