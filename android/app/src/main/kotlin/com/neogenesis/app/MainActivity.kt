package com.anvy4ik.neogenesis

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Handler
import android.os.Looper
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {

    private val SCREEN_CHANNEL = "neo_genesis/screen"
    private val SERVICE_CHANNEL = "neo_genesis/service"
    private val CAPTURE_REQUEST_CODE = 1001

    private var projectionManager: MediaProjectionManager? = null
    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        projectionManager =
            getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager

        // ── Screen capture channel ────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPermission" -> {
                        pendingResult = result
                        val intent = projectionManager!!.createScreenCaptureIntent()
                        startActivityForResult(intent, CAPTURE_REQUEST_CODE)
                    }
                    "captureScreen" -> captureScreen(result)
                    "stopCapture" -> {
                        stopCapture()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Foreground service channel ────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SERVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService" -> {
                        NeoForegroundService.start(this)
                        result.success(true)
                    }
                    "stopService" -> {
                        NeoForegroundService.stop(this)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == CAPTURE_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                mediaProjection = projectionManager!!.getMediaProjection(resultCode, data)
                setupVirtualDisplay()
                pendingResult?.success(true)
            } else {
                pendingResult?.success(false)
            }
            pendingResult = null
        }
    }

    private fun setupVirtualDisplay() {
        val metrics = resources.displayMetrics
        val width = metrics.widthPixels
        val height = metrics.heightPixels
        val density = metrics.densityDpi

        imageReader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)

        virtualDisplay = mediaProjection?.createVirtualDisplay(
            "NeoGenesisCapture",
            width, height, density,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            imageReader!!.surface, null, null
        )
    }

    private fun captureScreen(result: MethodChannel.Result) {
        if (imageReader == null) {
            result.error("NO_PERMISSION", "Screen capture not initialized", null)
            return
        }

        Handler(Looper.getMainLooper()).postDelayed({
            try {
                val image = imageReader!!.acquireLatestImage()
                if (image == null) {
                    result.error("NO_IMAGE", "No image available", null)
                    return@postDelayed
                }

                val planes = image.planes
                val buffer = planes[0].buffer
                val pixelStride = planes[0].pixelStride
                val rowStride = planes[0].rowStride
                val rowPadding = rowStride - pixelStride * image.width

                val bitmap = Bitmap.createBitmap(
                    image.width + rowPadding / pixelStride,
                    image.height,
                    Bitmap.Config.ARGB_8888
                )
                bitmap.copyPixelsFromBuffer(buffer)
                image.close()

                val scaled = Bitmap.createScaledBitmap(bitmap, 720,
                    (720f * bitmap.height / bitmap.width).toInt(), true)
                bitmap.recycle()

                val stream = ByteArrayOutputStream()
                scaled.compress(Bitmap.CompressFormat.JPEG, 70, stream)
                scaled.recycle()

                val base64 = Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
                result.success(base64)
            } catch (e: Exception) {
                result.error("CAPTURE_ERROR", e.message, null)
            }
        }, 200)
    }

    private fun stopCapture() {
        virtualDisplay?.release()
        imageReader?.close()
        mediaProjection?.stop()
        virtualDisplay = null
        imageReader = null
        mediaProjection = null
    }
}
