import Flutter
import UIKit
import ZXingCpp
import Foundation
import SwiftUI
import AVFoundation

public class FlutterQrScannerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, FlutterTexture, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = FlutterQrScannerPlugin(registrar.textures())
        
        let channel = FlutterMethodChannel(name: "flutter_qr_scanner/channel", binaryMessenger: registrar.messenger())
        
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        let event = FlutterEventChannel(name: "flutter_qr_scanner/event", binaryMessenger: registrar.messenger())
        event.setStreamHandler(instance)
    }
    
    
    
    
    
    let registry: FlutterTextureRegistry
    var sink: FlutterEventSink!
    var textureId: Int64!
    var captureSession: AVCaptureSession!
    var device: AVCaptureDevice!
    var latestBuffer: CVImageBuffer!
    var analyzeMode: Int
    let reader =  ZXIBarcodeReader()
    let zxingLock = DispatchSemaphore(value: 1)
    var frontCameraInput: AVCaptureDeviceInput?
    var backCameraInput: AVCaptureDeviceInput?
    var isCapture : Bool = false
    let processingQueue = DispatchQueue(label: "qr-processing-queue")
    
    
    init(_ registry: FlutterTextureRegistry) {
        self.registry = registry
        analyzeMode = 0
        super.init()
    }
    
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        case "permissionState":
            permissionState(call, result)
        case "requestPermissions":
            requestPermissions(call, result)
        case "startScan":
            startScan(call, result)
        case "stopScan":
            stopScan(result)
        case "changeZoom":
            changeZoom(call, result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        return nil
    }
    
    public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        if latestBuffer == nil {
            return nil
        }
        return Unmanaged<CVPixelBuffer>.passRetained(latestBuffer)
    }
    
    
    func changeZoom(_ call: FlutterMethodCall,_ result: @escaping FlutterResult) {
        let zoomFactor = call.arguments as! CGFloat
        print("zoomFactor: \(zoomFactor)")
        guard let device = device else {
            result(FlutterError(code: "CameraError", message: "Camera device not initialized.", details: nil))
            return
        }
        
        do {
            try device.lockForConfiguration()
            //            device.videoZoomFactor = max(1.0, min(zoomFactor, device.activeFormat.videoMaxZoomFactor))
            device.videoZoomFactor = max(1, zoomFactor)
            device.unlockForConfiguration()
            result(nil)
        } catch {
            result(FlutterError(code: "CameraError", message: "Failed to set zoom level.", details: nil))
        }
    }
    
    func resizeAndCenterCropImageBuffer(imageBuffer: CVImageBuffer, targetSize: CGSize) -> CVPixelBuffer? {
        let imageWidth = CVPixelBufferGetWidth(imageBuffer)
        let imageHeight = CVPixelBufferGetHeight(imageBuffer)
        let targetWidth = Int(targetSize.width)
        let targetHeight = Int(targetSize.height)
        
        let sourceAspectRatio = CGFloat(imageWidth) / CGFloat(imageHeight)
        let targetAspectRatio = targetSize.width / targetSize.height
        
        var cropRect = CGRect(x: 0, y: 0, width: CGFloat(imageWidth), height: CGFloat(imageHeight))
        
        if sourceAspectRatio > targetAspectRatio {
            // Crop horizontally
            let scaledWidth = CGFloat(targetHeight) * sourceAspectRatio
            let xOffset = (CGFloat(imageWidth) - scaledWidth) / 2
            cropRect.origin.x = xOffset
            cropRect.size.width = scaledWidth
        } else {
            // Crop vertically
            let scaledHeight = CGFloat(targetWidth) / sourceAspectRatio
            let yOffset = (CGFloat(imageHeight) - scaledHeight) / 2
            cropRect.origin.y = yOffset
            cropRect.size.height = scaledHeight
        }
        
        let options: [NSString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        
        var resizedBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(nil, targetWidth, targetHeight, kCVPixelFormatType_32BGRA, options as CFDictionary, &resizedBuffer)
        
        guard status == kCVReturnSuccess, let outputBuffer = resizedBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        CVPixelBufferLockBaseAddress(outputBuffer, [])
        
        guard let destData = CVPixelBufferGetBaseAddress(outputBuffer) else {
            return nil
        }
        
        let destBytesPerRow = CVPixelBufferGetBytesPerRow(outputBuffer)
        
        let context = CGContext(data: destData, width: targetWidth, height: targetHeight, bitsPerComponent: 8, bytesPerRow: destBytesPerRow, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        guard let cgContext = context else {
            return nil
        }
        
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let cgImage = CIContext().createCGImage(ciImage.cropped(to: cropRect), from: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        
        cgContext.draw(cgImage!, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        context?.flush()
        
        CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
        CVPixelBufferUnlockBaseAddress(outputBuffer, [])
        
        return outputBuffer
    }
    
    func permissionState(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .notDetermined:
            result(0)
        case .authorized:
            result(1)
        default:
            result(2)
        }
    }
    
    func requestPermissions(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        AVCaptureDevice.requestAccess(for: .video, completionHandler: { result($0) })
    }
    
    func startScan(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        textureId = registry.register(self)
        captureSession = AVCaptureSession()
        
        // Set the session preset to vga640x480
        if captureSession.canSetSessionPreset(.vga640x480) {
            captureSession.sessionPreset = .vga640x480
        } else {
            // Handle unsupported preset
            print("vga640x480 preset is not supported")
        }
        
        let position = AVCaptureDevice.Position.back
        if #available(iOS 10.0, *) {
            print("iOS 10.0 ++")
            device = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: position).devices.first
        } else {
            print("iOS 9.0")
            device = AVCaptureDevice.devices(for: .video).filter({$0.position == position}).first
        }
        //           device.addObserver(self, forKeyPath: #keyPath(AVCaptureDevice.torchMode), options: .new, context: nil)
        captureSession.beginConfiguration()
        // Add device input.
        do {
            let input = try AVCaptureDeviceInput(device: device)
            captureSession.addInput(input)
        } catch {
            //              error.throwNative(result)
            print(error)
        }
        // Add video output.
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue.main)
        captureSession.addOutput(videoOutput)
        for connection in videoOutput.connections {
            connection.videoOrientation = .portrait
            if position == .front && connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
        }
        
        captureSession.commitConfiguration()
        
        
        DispatchQueue(label: "camera-handling").async { [weak self] in
            guard let self = self else { return }
            
            self.captureSession.startRunning()
            
            
            let demensions = CMVideoFormatDescriptionGetDimensions(self.device.activeFormat.formatDescription)
            let width = Double(demensions.height)
            let height = Double(demensions.width)
            let size = ["width": width, "height": height]
            let answer: [String : Any?] = ["textureId": self.textureId, "size": size]
            result(answer)
            
        }
    }
    
    
    func stopScan(_ result: FlutterResult) {
        captureSession.stopRunning()
        for input in captureSession.inputs {
            captureSession.removeInput(input)
        }
        for output in captureSession.outputs {
            captureSession.removeOutput(output)
        }
        registry.unregisterTexture(textureId)
        
        analyzeMode = 0
        latestBuffer = nil
        captureSession = nil
        device = nil
        textureId = nil
        
        result(nil)
    }
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection)   {
        latestBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        registry.textureFrameAvailable(textureId)
        if(!isCapture){
            self.processSampleBuffer(sampleBuffer)
        }else{
            
        }
    }
    
    func processSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard zxingLock.wait(timeout: .now()) == .success else {
            print("Lock acquisition failed, dropping frame.")
            return
        }
        
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            defer {
                self.zxingLock.signal()
            }
            
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                print("Failed to get image buffer from sample buffer.")
                return
            }
            
            do {
                if let result = try self.reader.read(imageBuffer).first {
                    self.processQRCodeResult(result.bytes)
                } else {
                    print("No QR code found in image.")
                }
            } catch {
                print("Failed to read QR code: \(error.localizedDescription)")
            }
        }
    }
    
    func processQRCodeResult(_ result: Data) {
        // Convert result bytes to UInt8 array and log
        let qrBytes = [UInt8](result)
        print("QR Code Bytes: \(qrBytes)")
        let event: [String: Any?] = ["name": "qr_size","data": qrBytes]
        sink?(event)
    }
}
