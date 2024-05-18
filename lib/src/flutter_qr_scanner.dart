import 'flutter_qr_scanner_platform_interface.dart';



class FlutterQrScanner {
  Future<String?> getPlatformVersion() {
    return FlutterQrScannerPlatform.instance.getPlatformVersion();
  }
}


