import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class QRScanner extends StatefulWidget {

  QRScannerState createState() => QRScannerState();
}

class QRScannerState extends State<QRScanner> {

  final qrKey = GlobalKey(debugLabel: 'QR');

  String result;

  Barcode barcode;
  QRViewController controller;

  @override
  void dispose(){
    controller?.dispose();
    super.dispose();
  }

  @override
  void reassemble() {
    super.reassemble();
    controller.pauseCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: QRView(
        formatsAllowed: [BarcodeFormat.qrcode],
        key: qrKey,
        overlay: QrScannerOverlayShape(),
        onQRViewCreated: (QRViewController controller) {
          setState(() {
            this.controller = controller;
          });
          controller.scannedDataStream.listen((scanData) {
            controller.pauseCamera();
            setState(() {
              Navigator.pop(context, scanData.code);
            });
          });
        },
      )
    );
  }
  
}