package com.prabhanu.flutter_qr_scanner

import android.Manifest
import android.annotation.SuppressLint
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.common.util.concurrent.ListenableFuture
import zxingcpp.BarcodeReader
import java.util.concurrent.Executors
import io.flutter.plugin.common.MethodChannel
import android.app.Activity
import android.content.pm.PackageManager
import io.flutter.view.TextureRegistry
import android.view.Surface
import io.flutter.plugin.common.PluginRegistry
import androidx.core.app.ActivityCompat
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall


class QRScanner(private val activity: Activity, private val textureRegistry: TextureRegistry) :
    PluginRegistry.RequestPermissionsResultListener, EventChannel.StreamHandler,
    QRBytesListener {
    private lateinit var cameraProviderFuture: ListenableFuture<ProcessCameraProvider>
    private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var cameraProvider: ProcessCameraProvider? = null


    private var listener: PluginRegistry.RequestPermissionsResultListener? = null
    private var sink: EventChannel.EventSink? = null

    // The camera view
    private lateinit var pvCamera: PreviewView

    // The text view to show instructions to the user
    private lateinit var tvInstructions: TextView

    // The button to go back to the previous screen
    private lateinit var ivBack: ImageView

    // The password entered by the user
    private lateinit var qrPassword: String

    // The bar code reader
    private val barCodeReader = BarcodeReader()

    // The camera
    private var camera: Camera? = null

    // The frame view showing the pinch to zoom animation
    private lateinit var flPinchToZoom: FrameLayout

    // Whether the pinch to zoom hint has been shown
    private var isPinchToZoomHintShown = false

    companion object {
        private const val REQUEST_CODE = 19930430
    }

    private class QrAnalyzer(
        val barCodeReader: BarcodeReader,
        val qrScanListener: QRBytesListener
    ) : ImageAnalysis.Analyzer {
        override fun analyze(image: ImageProxy) {
            image.use {
                // check qr code is located within scanner view
                // val rect = Rect(0, 0, image.width, image.height)
                val result = barCodeReader.read(image)
                if (result.isNotEmpty()) {
                    val qrResult = result[0]
                    qrResult.bytes?.let {
                        qrScanListener.processQrBytes(it)
                    }
                }
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    fun requestNative(result: MethodChannel.Result) {
        listener = PluginRegistry.RequestPermissionsResultListener { requestCode, _, grantResults ->
            if (requestCode != REQUEST_CODE) {
                false
            } else {
                val authorized = grantResults[0] == PackageManager.PERMISSION_GRANTED
                result.success(authorized)
                listener = null
                true
            }
        }
        val permissions = arrayOf(Manifest.permission.CAMERA)
        ActivityCompat.requestPermissions(activity, permissions, REQUEST_CODE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        return listener?.onRequestPermissionsResult(requestCode, permissions, grantResults) ?: false
    }

    fun stateNative(result: MethodChannel.Result) {
        // Can't get exact denied or not_determined state without request. Just return not_determined when state isn't authorized
        val state =
            if (ContextCompat.checkSelfPermission(
                    activity,
                    Manifest.permission.CAMERA
                ) == PackageManager.PERMISSION_GRANTED
            ) 1
            else 0
        result.success(state)
    }

    fun startNative(result: MethodChannel.Result) {
        val future = ProcessCameraProvider.getInstance(activity)
        val executor = ContextCompat.getMainExecutor(activity)
        future.addListener({

            //camera selector
            val selector = CameraSelector.DEFAULT_BACK_CAMERA
            cameraProvider = future.get()
            textureEntry = textureRegistry.createSurfaceTexture()
            val textureId = textureEntry!!.id()
            // Preview
            val surfaceProvider = Preview.SurfaceProvider { request ->
                val resolution = request.resolution
                val texture = textureEntry!!.surfaceTexture()
                texture.setDefaultBufferSize(resolution.width, resolution.height)
                val surface = Surface(texture)
                request.provideSurface(surface, executor) { }
            }

            val preview = Preview.Builder().build().apply { setSurfaceProvider(surfaceProvider) }

            // Analyzer
            val executorAnalyzer = Executors.newSingleThreadExecutor()

            val resolutionSelector =
                ResolutionSelector.Builder()
                    .setResolutionStrategy(
                        ResolutionStrategy.HIGHEST_AVAILABLE_STRATEGY,
                    ).build()

            val imageAnalysis =
                ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    // .setBackgroundExecutor(executor)
                    .setResolutionSelector(resolutionSelector)
                    .build()
                    .also {
                        it.setAnalyzer(
                            executor,
                            QrAnalyzer(barCodeReader, this),
                        )
                    }

            val owner = activity as LifecycleOwner

            camera = cameraProvider!!.bindToLifecycle(owner, selector, preview, imageAnalysis)

            @SuppressLint("RestrictedApi")
            val resolution = preview.attachedSurfaceResolution!!
            val portrait = camera!!.cameraInfo.sensorRotationDegrees % 180 == 0
            val width = resolution.width.toDouble()
            val height = resolution.height.toDouble()
            val size = if (portrait) mapOf("width" to width, "height" to height) else mapOf(
                "width" to height,
                "height" to width
            )
            val answer =
                mapOf("textureId" to textureId, "size" to size)
            result.success(answer)
        }, executor)
    }

    fun stopNative(result: MethodChannel.Result?) {
        val owner = activity as LifecycleOwner
        camera!!.cameraInfo.torchState.removeObservers(owner)
        cameraProvider!!.unbindAll()
        textureEntry!!.release()

        camera = null
        textureEntry = null
        cameraProvider = null

        result?.success(null)
    }

    override fun processQrBytes(spBytes: ByteArray) {
        println("QR bytes: ${spBytes.size}")
        val event = mapOf("name" to "qr_size", "data" to spBytes)
        sink?.success(event)
    }

    fun changeZoomLevel(call: MethodCall, result: MethodChannel.Result) {
        val scaleFactor: Double = call.arguments as Double
        println("scaleFactor: $scaleFactor")
        val currentZoomRatio = camera!!.cameraInfo.zoomState.value!!.zoomRatio
        val x = currentZoomRatio * scaleFactor
        println("x: $x")
        val floatVar: Float = x.toFloat()

        camera!!.cameraControl!!.setZoomRatio(floatVar)
//        result.success(null)
    }
}

interface QRBytesListener {
    fun processQrBytes(bytes: ByteArray)
}
