import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

/// A camera controller.
abstract class QRController {
  /// Arguments for [CameraView].
  ValueNotifier<CameraArgs?> get args;

  Stream<List<int>> get qrBytes;

  /// Create a [CameraController].
  ///
  /// [facing] target facing used to select camera.
  ///
  factory QRController([CameraFacing facing = CameraFacing.back]) =>
      _QRController(facing);

  /// Start the camera asynchronously.
  Future<void> startAsync();

  void changeZoom(double scale);

  /// Release the resources of the camera.
  void dispose();
}

class _QRController implements QRController {
  static const MethodChannel method = MethodChannel('flutter_qr_scanner/channel');
  static const EventChannel event = EventChannel('flutter_qr_scanner/event');

  static const undetermined = 0;
  static const authorized = 1;
  static const denied = 2;


  static int? id;
  static StreamSubscription? subscription;

  late CameraFacing facing;

  late StreamController<List<int>> qrSizeController = StreamController<List<int>>();

  @override
  Stream<List<int>> get qrBytes => qrSizeController.stream;

  @override
  final ValueNotifier<CameraArgs?> args;

  _QRController(this.facing)
      : args = ValueNotifier(null){
    // In case new instance before dispose.
    if (id != null) {
      stop();
    }
    id = hashCode;
    subscription =
        event.receiveBroadcastStream().listen((data) => handleEvent(data));
  }

  void handleEvent(Map<dynamic, dynamic> event) {
    final name = event['name'];
    final data = event['data'];
    switch (name) {
      case 'qr_size':
        List<int> intList = data.whereType<int>().toList();
        qrSizeController.add(intList);
        break;
      case 'torchState':
        break;
      case 'pose':
        break;
      default:
        throw UnimplementedError();
    }
  }

  @override
  Future<void> startAsync() async {
    ensure('startAsync');
    // Check authorization state.
    var state = await method.invokeMethod('permissionState');
    if (state == undetermined) {
      final result = await method.invokeMethod('requestPermissions');
      state = result ? authorized : denied;
    }
    if (state != authorized) {
      throw PlatformException(code: 'NO ACCESS');
    }

    final answer = await method.invokeMapMethod<String, dynamic>('startScan');
    final textureId = answer?['textureId'];
    final size = toSize(answer?['size']);
    args.value = CameraArgs(textureId, size);
  }


  @override
  void dispose() {
    if (hashCode == id) {
      stop();
      subscription?.cancel();
      subscription = null;
      id = null;
    }
    qrSizeController.close();
  }

  @override
  void changeZoom(double scale) => method.invokeMethod('changeZoom', scale);

  void stop() => method.invokeMethod('stopScan');

  void ensure(String name) {
    final message =
        'CameraController.$name called after CameraController.dispose\n'
        'CameraController methods should not be used after calling dispose.';
    assert(hashCode == id, message);
  }

  Size toSize(Map<dynamic, dynamic> data) {
    final width = data['width'];
    final height = data['height'];
    return Size(width, height);
  }
}


/// The facing of a camera.
enum CameraFacing {
  /// Front facing camera.
  front,

  /// Back facing camera.
  back,
}

/// Camera args for [CameraView].
class CameraArgs {
  /// The texture id.
  final int textureId;

  /// Size of the texture.
  final Size size;

  /// Create a [CameraArgs].
  CameraArgs(this.textureId, this.size);
}