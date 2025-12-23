package com.flowtrack.app

import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.flowtrack.app/files"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "readContentUri") {
                val uriString = call.arguments as? String
                if (uriString != null) {
                    try {
                        val uri = Uri.parse(uriString)
                        val inputStream = contentResolver.openInputStream(uri)
                        if (inputStream != null) {
                            val reader = BufferedReader(InputStreamReader(inputStream))
                            val content = reader.readText()
                            reader.close()
                            inputStream.close()
                            result.success(content)
                        } else {
                            result.error("READ_ERROR", "Cannot open input stream", null)
                        }
                    } catch (e: Exception) {
                        result.error("READ_ERROR", "Error reading content: ${e.message}", null)
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "URI string is null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
