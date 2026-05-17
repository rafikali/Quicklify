package com.example.quicklify

import android.content.ContentValues
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.nio.ByteBuffer

class MainActivity : FlutterActivity() {
    private val SCANNER_CHANNEL = "com.example.quicklify/media_scanner"
    private val MUXER_CHANNEL = "com.example.quicklify/media_muxer"
    private val GALLERY_CHANNEL = "com.example.quicklify/gallery"

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

        // Gallery save channel — saves file to gallery via MediaStore
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, GALLERY_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "saveToGallery") {
                    val filePath = call.argument<String>("filePath")
                    val filename = call.argument<String>("filename")
                    val mimeType = call.argument<String>("mimeType")

                    if (filePath == null || filename == null) {
                        result.error("INVALID_ARGUMENT", "Missing arguments", null)
                        return@setMethodCallHandler
                    }

                    Thread {
                        try {
                            val uri = saveFileToGallery(filePath, filename, mimeType ?: "video/mp4")
                            runOnUiThread { result.success(uri) }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("GALLERY_SAVE_FAILED", e.message, null)
                            }
                        }
                    }.start()
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

    private fun saveFileToGallery(filePath: String, filename: String, mimeType: String): String? {
        val file = File(filePath)
        if (!file.exists()) throw Exception("File not found: $filePath")

        val isVideo = mimeType.startsWith("video/")
        val isAudio = mimeType.startsWith("audio/")

        val resolver = contentResolver

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10+ — use MediaStore API (scoped storage)
            val collection = when {
                isVideo -> MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                isAudio -> MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                else -> MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            }

            val relativePath = when {
                isVideo -> Environment.DIRECTORY_MOVIES + "/Quicklify"
                isAudio -> Environment.DIRECTORY_MUSIC + "/Quicklify"
                else -> Environment.DIRECTORY_DOWNLOADS + "/Quicklify"
            }

            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }

            val uri = resolver.insert(collection, values)
                ?: throw Exception("Failed to create MediaStore entry")

            resolver.openOutputStream(uri)?.use { outputStream ->
                FileInputStream(file).use { inputStream ->
                    inputStream.copyTo(outputStream, bufferSize = 8192)
                }
            } ?: throw Exception("Failed to open output stream")

            // Mark as complete
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)

            // Delete the temp file from Downloads folder
            file.delete()

            return uri.toString()
        } else {
            // Android 9 and below — copy to public directory and scan
            val publicDir = when {
                isVideo -> Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES)
                isAudio -> Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC)
                else -> Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            }

            val targetDir = File(publicDir, "Quicklify")
            targetDir.mkdirs()
            val targetFile = File(targetDir, filename)

            file.copyTo(targetFile, overwrite = true)
            file.delete()

            // Scan so it appears in gallery
            MediaScannerConnection.scanFile(this, arrayOf(targetFile.absolutePath), arrayOf(mimeType), null)

            return targetFile.absolutePath
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
