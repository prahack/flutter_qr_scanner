import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'flutter_qr_scanner_platform_interface.dart';


/// An implementation of [FlutterQrScannerPlatform] that uses method channels.
class MethodChannelFlutterQrScanner extends FlutterQrScannerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_qr_scanner/channel');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String?>('getPlatformVersion');
    return version;
  }
}
