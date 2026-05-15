package com.example.quicklify

import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaScannerConnection
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer

class MainActivity : FlutterActivity() {
    private val SCANNER_CHANNEL = "com.example.quicklify/media_scanner"
    private val MUXER_CHANNEL = "com.example.quicklify/media_muxer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Media scanner channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCANNER_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "scanFile") {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        MediaScannerConnection.scanFile(
                            this,
                            arrayOf(path),
                            null
                        ) { _, uri ->
                            result.success(uri?.toString())
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Path is null", null)
                    }
                } else {
                    result.notImplemented()
                }
            }

        // Media muxer channel — merges video-only + audio into a single MP4
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MUXER_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "merge") {
                    val videoPath = call.argument<String>("videoPath")
                    val audioPath = call.argument<String>("audioPath")
                    val outputPath = call.argument<String>("outputPath")

                    if (videoPath == null || audioPath == null || outputPath == null) {
                        result.error("INVALID_ARGUMENT", "Missing path arguments", null)
                        return@setMethodCallHandler
                    }

                    // Run on a background thread to avoid blocking the UI
                    Thread {
                        try {
                            mergeStreams(videoPath, audioPath, outputPath)
                            runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("MERGE_FAILED", e.message, null)
                            }
                        }
                    }.start()
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun mergeStreams(videoPath: String, audioPath: String, outputPath: String) {
        val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        val bufferSize = 1024 * 1024 // 1 MB buffer
        val buffer = ByteBuffer.allocate(bufferSize)
        val bufferInfo = android.media.MediaCodec.BufferInfo()

        try {
            // ── Add video track ──
            val videoExtractor = MediaExtractor()
            videoExtractor.setDataSource(videoPath)
            var videoTrackIndex = -1
            var muxerVideoTrack = -1

            for (i in 0 until videoExtractor.trackCount) {
                val format = videoExtractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
                if (mime.startsWith("video/")) {
                    videoExtractor.selectTrack(i)
                    muxerVideoTrack = muxer.addTrack(format)
                    videoTrackIndex = i
                    break
                }
            }

            if (videoTrackIndex == -1) {
                videoExtractor.release()
                throw Exception("No video track found in $videoPath")
            }

            // ── Add audio track ──
            val audioExtractor = MediaExtractor()
            audioExtractor.setDataSource(audioPath)
            var audioTrackIndex = -1
            var muxerAudioTrack = -1

            for (i in 0 until audioExtractor.trackCount) {
                val format = audioExtractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
                if (mime.startsWith("audio/")) {
                    audioExtractor.selectTrack(i)
                    muxerAudioTrack = muxer.addTrack(format)
                    audioTrackIndex = i
                    break
                }
            }

            if (audioTrackIndex == -1) {
                videoExtractor.release()
                audioExtractor.release()
                throw Exception("No audio track found in $audioPath")
            }

            // ── Mux ──
            muxer.start()

            // Write video samples
            while (true) {
                val sampleSize = videoExtractor.readSampleData(buffer, 0)
                if (sampleSize < 0) break
                bufferInfo.offset = 0
                bufferInfo.size = sampleSize
                bufferInfo.presentationTimeUs = videoExtractor.sampleTime
                bufferInfo.flags = videoExtractor.sampleFlags
                muxer.writeSampleData(muxerVideoTrack, buffer, bufferInfo)
                videoExtractor.advance()
            }

            // Write audio samples
            while (true) {
                val sampleSize = audioExtractor.readSampleData(buffer, 0)
                if (sampleSize < 0) break
                bufferInfo.offset = 0
                bufferInfo.size = sampleSize
                bufferInfo.presentationTimeUs = audioExtractor.sampleTime
                bufferInfo.flags = audioExtractor.sampleFlags
                muxer.writeSampleData(muxerAudioTrack, buffer, bufferInfo)
                audioExtractor.advance()
            }

            videoExtractor.release()
            audioExtractor.release()
            muxer.stop()
            muxer.release()
        } catch (e: Exception) {
            try { muxer.release() } catch (_: Exception) {}
            throw e
        }
    }
}
