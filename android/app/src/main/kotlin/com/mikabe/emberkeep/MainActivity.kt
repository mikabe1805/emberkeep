package com.mikabe.emberkeep

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import java.util.ArrayDeque

class MainActivity : FlutterActivity() {
    private val pendingAcademicSchedules = ArrayDeque<Map<String, String>>()
    private var academicScheduleChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "room_of_days/academic_schedule_files",
        )
        academicScheduleChannel = channel
        channel.setMethodCallHandler { call, result ->
            if (call.method != "takeInitialAcademicSchedule") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            result.success(
                if (pendingAcademicSchedules.isEmpty()) {
                    null
                } else {
                    pendingAcademicSchedules.removeFirst()
                },
            )
        }
        handleAcademicScheduleIntent(intent)
        if (pendingAcademicSchedules.isNotEmpty()) {
            channel.invokeMethod("academicScheduleAvailable", null)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleAcademicScheduleIntent(intent)
    }

    private fun handleAcademicScheduleIntent(intent: Intent?) {
        if (intent == null || intent.getBooleanExtra(CONSUMED_EXTRA, false)) return
        val uri = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> sharedStreamUri(intent)
            else -> null
        } ?: return
        if (!looksLikeCalendar(uri, intent.type)) return
        intent.putExtra(CONSUMED_EXTRA, true)
        val payload = readCalendar(uri) ?: return
        while (pendingAcademicSchedules.size >= MAX_PENDING_COUNT) {
            pendingAcademicSchedules.removeFirst()
        }
        pendingAcademicSchedules.addLast(payload)
        academicScheduleChannel?.invokeMethod("academicScheduleAvailable", null)
    }

    @Suppress("DEPRECATION")
    private fun sharedStreamUri(intent: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                ?: intent.clipData?.getItemAt(0)?.uri
        } else {
            intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                ?: intent.clipData?.getItemAt(0)?.uri
        }

    private fun looksLikeCalendar(uri: Uri, mimeType: String?): Boolean {
        val type = mimeType?.lowercase() ?: contentResolver.getType(uri)?.lowercase()
        if (type == "text/calendar" || type == "application/ics" ||
            type == "text/x-vcalendar"
        ) {
            return true
        }
        return displayName(uri).lowercase().endsWith(".ics")
    }

    private fun displayName(uri: Uri): String {
        if (uri.scheme == "content") {
            contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (index >= 0) return cursor.getString(index) ?: "class-schedule.ics"
                }
            }
        }
        return uri.lastPathSegment?.substringAfterLast('/') ?: "class-schedule.ics"
    }

    private fun readCalendar(uri: Uri): Map<String, String>? {
        return try {
            val bytes = contentResolver.openInputStream(uri)?.use { input ->
                val output = ByteArrayOutputStream()
                val buffer = ByteArray(8192)
                while (true) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    output.write(buffer, 0, count)
                    if (output.size() > MAX_BYTES) return null
                }
                output.toByteArray()
            } ?: return null
            val decoder = Charsets.UTF_8.newDecoder()
                .onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT)
            val contents = decoder.decode(ByteBuffer.wrap(bytes)).toString()
                .removePrefix("\uFEFF")
            mapOf(
                "name" to displayName(uri).ifBlank { "class-schedule.ics" },
                "contents" to contents,
            )
        } catch (_: Exception) {
            null
        }
    }

    companion object {
        private const val MAX_BYTES = 2 * 1024 * 1024
        private const val MAX_PENDING_COUNT = 4
        private const val CONSUMED_EXTRA = "roomOfDaysAcademicScheduleConsumed"
    }
}
