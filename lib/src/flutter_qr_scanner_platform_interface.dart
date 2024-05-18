import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'flutter_qr_scanner_method_channel.dart';


abstract class FlutterQrScannerPlatform extends PlatformInterface {
  /// Constructs a FlutterQrScanPlatform.
  FlutterQrScannerPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterQrScannerPlatform _instance = MethodChannelFlutterQrScanner();

  /// The default instance of [FlutterQrScanPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterQrScan].
  static FlutterQrScannerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterQrScanPlatform] when
  /// they register themselves.
  static set instance(FlutterQrScannerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
