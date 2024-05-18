import 'package:flutter/material.dart';
import 'package:flutter_qr_scanner/flutter_qr_scanner_plugin.dart';

class QRScanView extends StatefulWidget {
  const QRScanView({super.key});

  @override
  _QRScanViewState createState() => _QRScanViewState();
}

class _QRScanViewState extends State<QRScanView> {
  late QRController qrController;

  @override
  void initState() {
    super.initState();
    qrController = QRController(CameraFacing.front);
    // TODO: make this work for both platforms
    // cameraController.qrBytes.listen((data) {
    //   // Handle the incoming data here
    //   print("Received data: $data");
    // });
    start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner View'),
      ),
      body: Stack(
        children: [
          GestureDetector(
            onScaleUpdate: (details) {
              // TODO: make zoom smooth
              print(details.scale);
              qrController.changeZoom(details.scale);
            },
            child: QRScanViewWidget(qrController),
          ),
        ],
      ),
    );
  }

  void start() async {
    await qrController.startAsync();
  }

  @override
  void dispose() {
    qrController.dispose();
    super.dispose();
  }
}
