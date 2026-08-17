package com.aidata.kashfLite

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    /// Logcat tag for native-side diagnostics.
    private val tag = "KashfMainActivity"

    /// Channel name mirrored on the Dart side in
    /// `lib/services/pdf_media_store.dart`.
    private val channelName = "com.aidata.kashfLite/pdf_media_store"

    /// Authority must match the `<provider>` element in
    /// `AndroidManifest.xml`:
    ///
    ///   `android:authorities="${applicationId}.fileprovider"`
    ///
    /// Resolved lazily in [onCreate] — `packageName` is a
    /// `ContextWrapper` property that requires the activity
    /// to be attached. Initializing it as a field (i.e. in
    /// `<init>`) crashes the launcher with NPE on
    /// `getPackageName()` because the base context isn't
    /// wired up yet.
    private var fileProviderAuthority: String = ""

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        fileProviderAuthority = "${packageName}.fileprovider"
        // Surface the resolved authority in logcat so we can
        // tell at a glance whether the FileProvider is wired
        // up correctly.
        Log.i(tag, "onCreate packageName=$packageName authority=$fileProviderAuthority")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.i(tag, "configureFlutterEngine — registering $channelName")
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "openPdf" -> {
                        val path = call.argument<String>("path")
                        val title = call.argument<String>("title")
                        if (path == null) {
                            result.error(
                                "bad_args",
                                "path is required",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        val uri = openPdfFile(path, title)
                        result.success(uri.toString())
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                Log.e(tag, "native handler failed: ${e.message}", e)
                result.error(
                    "open_failed",
                    e.message ?: "unknown error",
                    e.stackTraceToString(),
                )
            }
        }
    }

    /// Opens [path] via the platform PDF viewer. Wraps the
    /// `file://` URI in a `content://` URI via FileProvider
    /// (declared in `AndroidManifest.xml`) and grants the
    /// receiving app temporary read access via
    /// `FLAG_GRANT_READ_URI_PERMISSION`. This is the only
    /// way to safely share a file from another app on
    /// Android 7+ — passing a raw `file://` URI throws
    /// `FileUriExposedException` and the launch silently
    /// fails.
    private fun openPdfFile(path: String, title: String?): Uri {
        val file = File(path)
        if (!file.exists()) {
            throw IllegalStateException("PDF not found at $path")
        }
        val uri: Uri = FileProvider.getUriForFile(
            this,
            fileProviderAuthority,
            file,
        )
        val view = Intent(Intent.ACTION_VIEW)
        view.setDataAndType(uri, "application/pdf")
        view.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        view.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        // Set the title used in the chooser (when Android
        // asks "Open with…").
        if (title != null) {
            view.putExtra(Intent.EXTRA_TITLE, title)
        }
        val chooser = Intent.createChooser(view, title ?: "Open PDF")
        chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        chooser.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        startActivity(chooser)
        return uri
    }
}