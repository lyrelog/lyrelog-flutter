package com.lyrelog.flutter

import android.content.Context
import android.util.Log
import com.lyrelog.Configuration
import com.lyrelog.Consent
import com.lyrelog.Level
import com.lyrelog.Lyrelog
import io.flutter.embedding.engine.plugins.FlutterPlugin
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * The Android side of the lyrelog Flutter plugin: every call from Dart goes straight to the
 * Lyrelog Android SDK (`com.lyrelog:lyrelog-android`), which owns the disk queue, batching,
 * retries, crashes, sessions, consent and Key Attestation. Nothing here keeps state of its own.
 *
 * Never throws back into Dart: the SDK doesn't throw, and anything unexpected is caught and said
 * once in logcat at debug level (tag `Lyrelog`), never with the key.
 *
 * Pigeon delivers every call on one serial background thread (`@TaskQueue` in
 * `pigeon/messages.dart`), not on the main thread the UI runs on, in the order Dart made them;
 * the Android SDK is safe to call from any thread.
 */
class LyrelogPlugin : FlutterPlugin, LyrelogHostApi {
    private var context: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        LyrelogHostApi.setUp(binding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        LyrelogHostApi.setUp(binding.binaryMessenger, null)
        // The SDK keeps running: it belongs to the process, not to this engine.
        context = null
    }

    override fun start(configuration: StartMessage) = guarded("start") {
        val app = context ?: return@guarded
        // False when it was already running (a second start is ignored) or couldn't start.
        Lyrelog.start(app, configuration.toConfiguration())
    }

    override fun log(level: LevelMessage, message: String, category: String?, attrs: Map<String, Any?>?, payload: Any?) =
        guarded("log") { Lyrelog.log(level.toLevel(), message, category, attrs, payload) }

    override fun setUser(id: String?) = guarded("setUser") { Lyrelog.setUser(id) }

    override fun setConsent(consent: ConsentMessage) = guarded("setConsent") { Lyrelog.setConsent(consent.toConsent()) }

    override fun screen(name: String, attrs: Map<String, Any?>?) = guarded("screen") { Lyrelog.screen(name, attrs) }

    override fun sessionId(): String? = try {
        Lyrelog.sessionId
    } catch (e: Exception) {
        null
    }

    // `flush` and `stop` block: off the main thread.
    override suspend fun flush(timeoutMs: Long): Boolean = withContext(Dispatchers.IO) {
        try {
            Lyrelog.flush(timeoutMs)
        } catch (e: Exception) {
            false
        }
    }

    override suspend fun stop() = withContext(Dispatchers.IO) {
        guarded("stop") { Lyrelog.stop() }
    }

    private inline fun guarded(what: String, block: () -> Unit) {
        try {
            block()
        } catch (e: Exception) {
            Log.d("Lyrelog", "lyrelog flutter: $what failed (${e.javaClass.name})")
        }
    }
}

internal fun StartMessage.toConfiguration(): Configuration {
    val message = this
    return Configuration(apiKey) {
        endpoint = message.endpoint
        consent = message.consent.toConsent()
        minimumLevel = message.minimumLevel.toLevel()
        flushIntervalMillis = message.flushIntervalMs
        maxBatchBytes = message.maxBatchBytes.toInt()
        maxBatchEvents = message.maxBatchEvents.toInt()
        maxDiskBytes = message.maxDiskBytes
        maxEventAgeMillis = message.maxEventAgeMs
        sessionTimeoutMillis = message.sessionTimeoutMs
        environment = message.environment
        platform = message.platform
        redactedKeys = message.redactedKeys
        captureCrashes = message.captureNativeCrashes
        attachScreen = message.attachScreen
        // A Flutter app has one Activity: its class name would say nothing.
        automaticScreens = false
        mirrorToLogcat = message.mirrorToConsole
        attest = message.attest
        wrapper = "lyrelog-flutter/$WRAPPER_VERSION"
    }
}

/** This package's version (pubspec.yaml), named in `resource.sdk` before the Android SDK's. */
internal const val WRAPPER_VERSION = "1.0.3"

internal fun LevelMessage.toLevel() = when (this) {
    LevelMessage.TRACE -> Level.TRACE
    LevelMessage.DEBUG -> Level.DEBUG
    LevelMessage.INFO -> Level.INFO
    LevelMessage.NOTICE -> Level.NOTICE
    LevelMessage.WARNING -> Level.WARNING
    LevelMessage.ERROR -> Level.ERROR
    LevelMessage.CRITICAL -> Level.CRITICAL
}

internal fun ConsentMessage.toConsent() = when (this) {
    ConsentMessage.PENDING -> Consent.PENDING
    ConsentMessage.GRANTED -> Consent.GRANTED
    ConsentMessage.DENIED -> Consent.DENIED
}
