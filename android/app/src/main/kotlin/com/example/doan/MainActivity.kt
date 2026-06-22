package com.example.doan

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.media.AudioManager
import android.media.ToneGenerator
import android.speech.tts.TextToSpeech
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.KeyEvent
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.doan/tts"
    private val HARDWARE_KEY_CHANNEL = "com.example.doan/hardware_keys"
    private val AUDIO_FEEDBACK_CHANNEL = "com.example.doan/audio_feedback"
    private var tts: TextToSpeech? = null
    private var hardwareKeyEvents: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize TTS
        initializeTTS()

        // Setup Platform Channel for TTS
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "speak" -> {
                        val text = call.argument<String>("text") ?: ""
                        val language = call.argument<String>("language") ?: "vi"
                        val country = call.argument<String>("country") ?: "VN"
                        val pitch = call.argument<Double>("pitch") ?: 1.0
                        val speechRate = call.argument<Double>("speechRate") ?: 0.8

                        speakVietnamese(text, language, country, pitch.toFloat(), speechRate.toFloat())
                        result.success(null)
                    }
                    "stop" -> {
                        tts?.stop()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_FEEDBACK_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "playMicTone" -> {
                        val isStarting = call.argument<Boolean>("isStarting") ?: true
                        playMicTone(isStarting)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, HARDWARE_KEY_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    hardwareKeyEvents = events
                }

                override fun onCancel(arguments: Any?) {
                    hardwareKeyEvents = null
                }
            })
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_DOWN) {
            val eventSink = hardwareKeyEvents
            when (event.keyCode) {
                KeyEvent.KEYCODE_VOLUME_UP -> {
                    eventSink?.success("volume_up")
                    return eventSink != null
                }
                KeyEvent.KEYCODE_VOLUME_DOWN -> {
                    eventSink?.success("volume_down")
                    return eventSink != null
                }
                KeyEvent.KEYCODE_CAMERA -> {
                    eventSink?.success("camera")
                    return eventSink != null
                }
            }
        }
        return super.dispatchKeyEvent(event)
    }

    private fun playMicTone(isStarting: Boolean) {
        try {
            val toneType = if (isStarting) {
                ToneGenerator.TONE_PROP_BEEP
            } else {
                ToneGenerator.TONE_PROP_NACK
            }
            val durationMs = if (isStarting) 90 else 160
            val toneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, 90)
            toneGenerator.startTone(toneType, durationMs)
            Handler(Looper.getMainLooper()).postDelayed({
                toneGenerator.release()
            }, (durationMs + 80).toLong())
        } catch (e: Exception) {
            println("Mic tone error: ${e.message}")
        }
    }

    private fun initializeTTS() {
        tts = TextToSpeech(this) { status ->
            if (status == TextToSpeech.SUCCESS) {
                println("✅ TTS Engine initialized successfully")
                // Set default Vietnamese locale
                val locale = Locale("vi", "VN")
                val result = tts?.setLanguage(locale)
                if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
                    println("⚠️ Vietnamese not supported, trying fallback")
                    // Fallback to default language
                    tts?.language = Locale.getDefault()
                } else {
                    println("✅ Vietnamese locale set")
                }
            } else {
                println("❌ TTS Engine initialization failed")
            }
        }
    }

    private fun speakVietnamese(
        text: String,
        language: String,
        country: String,
        pitch: Float,
        speechRate: Float
    ) {
        if (tts == null) {
            println("❌ TTS not initialized")
            return
        }

        try {
            println("🔊 Speaking: $text (lang=$language, country=$country, pitch=$pitch, rate=$speechRate)")
            
            // Set pitch and speech rate
            tts?.setPitch(pitch)
            tts?.setSpeechRate(speechRate)

            // Set language
            val locale = Locale(language, country)
            val langResult = tts?.setLanguage(locale) ?: TextToSpeech.LANG_NOT_SUPPORTED
            
            if (langResult == TextToSpeech.LANG_MISSING_DATA || langResult == TextToSpeech.LANG_NOT_SUPPORTED) {
                println("⚠️ Language $language-$country not available, using default")
            }

            // Speak
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null)
            } else {
                @Suppress("DEPRECATION")
                tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null)
            }
            
            println("✅ TTS speech queued successfully")
        } catch (e: Exception) {
            println("❌ Error during TTS speak: ${e.message}")
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        tts?.stop()
        tts?.shutdown()
        super.onDestroy()
    }
}
