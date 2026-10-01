import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Returns the first barcode read, or null when the cashier backs out.
class CameraScannerScreen extends StatefulWidget {
  const CameraScannerScreen({super.key});

  static Future<String?> open(BuildContext context) =>
      Navigator.of(context).push<String>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const CameraScannerScreen()));

  @override
  State<CameraScannerScreen> createState() => _CameraScannerScreenState();
}

class _CameraScannerScreenState extends State<CameraScannerScreen> {
  final _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final code = capture.barcodes.map((barcode) => barcode.rawValue).nonNulls.firstOrNull;
    if (_done || code == null || code.isEmpty) {
      return;
    }
    _done = true;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan barcode'),
        actions: [
          IconButton(
            tooltip: 'Lampu kilat',
            icon: const Icon(LucideIcons.flashlight),
            onPressed: _controller.toggleTorch,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Kamera tidak bisa dibuka. Izinkan akses kamera di pengaturan, atau ketik kodenya di kolom pencarian.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 260,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 48,
            child: Text('Arahkan barcode ke dalam kotak', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}
