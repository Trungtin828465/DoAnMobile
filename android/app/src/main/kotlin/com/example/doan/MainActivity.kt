package com.example.doan

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.speech.tts.TextToSpeech
import android.os.Build
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.doan/tts"
    private var tts: TextToSpeech? = null

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
