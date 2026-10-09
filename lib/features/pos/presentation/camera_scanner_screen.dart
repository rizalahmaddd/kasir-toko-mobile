import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';
import 'package:web_pos_mobile/core/theme/app_colors.dart';

import 'widgets/barcode_scanner_view.dart';

/// Full-screen camera barcode scanner.
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
  bool _torchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(String code) {
    if (_done || code.isEmpty) {
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(PosStrings.scanTitle, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        actions: [
          IconButton(
            tooltip: PosStrings.torchTooltip,
            icon: Icon(
              _torchOn ? AppIcons.flashlight : AppIcons.flashlightOff,
              color: _torchOn ? AppColors.amber400 : Colors.white,
            ),
            onPressed: _toggleTorch,
          ),
          IconButton(
            tooltip: PosStrings.switchCameraTooltip,
            icon: const Icon(AppIcons.switchCamera, color: Colors.white),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: BarcodeScannerView(
        controller: _controller,
        onDetect: _onDetect,
      ),
    );
  }
}

