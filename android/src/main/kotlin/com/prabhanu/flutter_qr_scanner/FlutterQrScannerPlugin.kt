package com.prabhanu.flutter_qr_scanner

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel


/** FlutterQrScanPluginner */
class FlutterQrScannerPlugin : FlutterPlugin, ActivityAware, MethodCallHandler {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    private var qrScanActivity: QRScanner? = null
    private var flutter: FlutterPlugin.FlutterPluginBinding? = null
    private var activity: ActivityPluginBinding? = null
    private lateinit var event: EventChannel


    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_qr_scanner/channel")
        channel.setMethodCallHandler(this)
        event = EventChannel(flutterPluginBinding.binaryMessenger, "flutter_qr_scanner/event")

        this.flutter = flutterPluginBinding

    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding
        qrScanActivity = QRScanner(activity!!.activity, flutter!!.textureRegistry)
        event!!.setStreamHandler(qrScanActivity)

    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        activity!!.removeRequestPermissionsResultListener(qrScanActivity!!)
        activity = null
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }


    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method == "getPlatformVersion") {
            result.success("Android method")
        } else if (call.method == "startScan") {
            qrScanActivity!!.startScan(result)
            return
        } else if (call.method == "requestPermissions") {
            qrScanActivity!!.requestPermissions(result)
            return
        } else if (call.method == "permissionState") {
            qrScanActivity!!.permissionState(result)
            return
        } else if (call.method == "changeZoom") {
            qrScanActivity!!.changeZoom(call, result)
            return
        } else if (call.method == "stopScan") {
            qrScanActivity!!.stopScan(result)
            return
        } else {
            result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        flutter = null
    }
}