import 'package:flutter/material.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/constants/app_strings.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';
import 'package:web_pos_mobile/core/theme/app_durations.dart';
import 'package:web_pos_mobile/core/theme/app_colors.dart';

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
      duration: AppDurations.milliseconds1800,
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.s24),
                child: Text(
                  PosStrings.cameraError,
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
                      borderRadius: BorderRadius.circular(AppRadius.r16),
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
                        borderRadius: BorderRadius.circular(AppRadius.r16),
                        border: Border.all(
                          color: AppColors.emerald500.withValues(alpha: 0.8),
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
                                AppColors.emerald500,
                                AppColors.emerald400,
                                AppColors.emerald500,
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.emerald500.withValues(alpha: 0.6),
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
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(AppRadius.r30),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIcons.scanLine, size: AppSizes.s16, color: AppColors.emerald500),
                    SizedBox(width: AppSizes.s8),
                    Text(
                      PosStrings.scanHint,
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

