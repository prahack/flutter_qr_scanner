import 'package:flutter/material.dart';
import 'package:flutter_qr_scanner/src/qr_controller.dart';


/// A widget showing a live camera preview.
class QRScanViewWidget extends StatelessWidget {
  /// The controller of the camera.
  final QRController controller;

  /// Create a [QRScanViewWidget] with a [controller], the [controller] must has been initialized.
  const QRScanViewWidget(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller.args,
      builder: (context, value, child) => _build(context, value),
    );
  }

  Widget _build(BuildContext context, CameraArgs? value) {
    if (value == null) {
      return Container(color: Colors.black);
    } else {
      return ClipRect(
        child: Transform.scale(
          scale: value.size.fill(MediaQuery.of(context).size),
          child: Center(
            child: AspectRatio(
              aspectRatio: value.size.aspectRatio,
              child: Texture(textureId: value.textureId),
            ),
          ),
        ),
      );
    }
  }
}

extension on Size {
  double fill(Size targetSize) {
    if (targetSize.aspectRatio < aspectRatio) {
      return targetSize.height * aspectRatio / targetSize.width;
    } else {
      return targetSize.width / aspectRatio / targetSize.height;
    }
  }
}
