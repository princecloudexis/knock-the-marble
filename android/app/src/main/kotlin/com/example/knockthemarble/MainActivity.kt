package com.cloudexis.knockthemarble

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "abalone/audio"
    private var audioTrack: AudioTrack? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "init" -> {
                        result.success(true)
                    }
                    "play" -> {
                        val wav = call.argument<ByteArray>("wav")
                        if (wav != null && wav.size > 44) {
                            playWav(wav)
                            result.success(true)
                        } else {
                            result.error("INVALID", "No wav data", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun playWav(wav: ByteArray) {
        Thread {
            try {
                // Parse WAV header
                val sampleRate = readInt(wav, 24)
                val dataSize = readInt(wav, 40)
                val pcmData = wav.copyOfRange(44, wav.size)

                // Stop previous
                audioTrack?.stop()
                audioTrack?.release()

                val bufSize = AudioTrack.getMinBufferSize(
                    sampleRate,
                    AudioFormat.CHANNEL_OUT_MONO,
                    AudioFormat.ENCODING_PCM_16BIT
                )

                val track = AudioTrack.Builder()
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_GAME)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                    .setAudioFormat(
                        AudioFormat.Builder()
                            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                            .setSampleRate(sampleRate)
                            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                            .build()
                    )
                    .setBufferSizeInBytes(maxOf(bufSize, pcmData.size))
                    .setTransferMode(AudioTrack.MODE_STATIC)
                    .build()

                track.write(pcmData, 0, pcmData.size)
                track.play()
                audioTrack = track

            } catch (e: Exception) {
                e.printStackTrace()
            }
        }.start()
    }

    private fun readInt(data: ByteArray, offset: Int): Int {
        return (data[offset].toInt() and 0xFF) or
                ((data[offset + 1].toInt() and 0xFF) shl 8) or
                ((data[offset + 2].toInt() and 0xFF) shl 16) or
                ((data[offset + 3].toInt() and 0xFF) shl 24)
    }
}