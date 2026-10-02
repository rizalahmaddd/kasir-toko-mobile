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

class _CameraScannerScreenState extends State<CameraScannerScreen> with SingleTickerProviderStateMixin {
  final _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  late final AnimationController _animController;
  bool _done = false;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
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

  Future<void> _toggleTorch() async {
    await _controller.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  @override
  Widget build(BuildContext context) {
    const scanBoxWidth = 270.0;
    const scanBoxHeight = 180.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('Scan Barcode / QR', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        actions: [
          IconButton(
            tooltip: 'Lampu kilat',
            icon: Icon(
              _torchOn ? LucideIcons.flashlight : LucideIcons.flashlightOff,
              color: _torchOn ? const Color(0xFFFBBF24) : Colors.white,
            ),
            onPressed: _toggleTorch,
          ),
          IconButton(
            tooltip: 'Ganti kamera',
            icon: const Icon(LucideIcons.switchCamera, color: Colors.white),
            onPressed: () => _controller.switchCamera(),
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
                  'Kamera tidak bisa dibuka. Izinkan akses kamera di pengaturan perangkat.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ),

          // Dark vignette overlay with cutout
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.65),
              BlendMode.srcOut,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Center(
                  child: Container(
                    width: scanBoxWidth,
                    height: scanBoxHeight,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Target box with glowing corner brackets & animated laser line
          Center(
            child: SizedBox(
              width: scanBoxWidth,
              height: scanBoxHeight,
              child: Stack(
                children: [
                  // Corner brackets
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.8),
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  // Animated scanning laser line
                  AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      return Positioned(
                        top: _animController.value * (scanBoxHeight - 4),
                        left: 8,
                        right: 8,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Colors.transparent,
                                Color(0xFF10B981),
                                Color(0xFF34D399),
                                Color(0xFF10B981),
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.6),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Hint instruction pill at bottom
          Positioned(
            left: 20,
            right: 20,
            bottom: 50,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.scanLine, size: 16, color: Color(0xFF10B981)),
                    SizedBox(width: 8),
                    Text(
                      'Posisikan barcode di dalam kotak',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

