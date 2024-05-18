import 'package:flutter_qr_scanner/flutter_qr_scanner_plugin.dart';
import 'package:flutter_qr_scanner/src/flutter_qr_scanner_method_channel.dart';
import 'package:flutter_qr_scanner/src/flutter_qr_scanner_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterQrScannerPlatform
    with MockPlatformInterfaceMixin
    implements FlutterQrScannerPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

}

void main() {
  final FlutterQrScannerPlatform initialPlatform = FlutterQrScannerPlatform.instance;

  test('$MethodChannelFlutterQrScanner is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterQrScanner>());
  });

  test('getPlatformVersion', () async {
    FlutterQrScanner flutterQrScanPlugin = FlutterQrScanner();
    MockFlutterQrScannerPlatform fakePlatform = MockFlutterQrScannerPlatform();
    FlutterQrScannerPlatform.instance = fakePlatform;

    expect(await flutterQrScanPlugin.getPlatformVersion(), '42');
  });
}
