import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';
import 'package:web_pos_mobile/core/theme/app_colors.dart';
import 'package:web_pos_mobile/core/theme/app_durations.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';

/// Reusable camera barcode & QR scanner viewfinder widget.
/// Includes animated laser line, targeting corners, vignette cutout, and hint pill.
class BarcodeScannerView extends StatefulWidget {
  const BarcodeScannerView({
    super.key,
    required this.onDetect,
    this.controller,
    this.hintText = PosStrings.scanHint,
    this.laserColor = AppColors.emerald500,
    this.continuous = false,
    this.repeatDelay = const Duration(milliseconds: 800),
  });

  final ValueChanged<String> onDetect;
  final MobileScannerController? controller;
  final String hintText;
  final Color laserColor;

  /// Keep scanning after a hit (stock counting). The same code is ignored for [repeatDelay] so one
  /// barcode held under the camera is not counted many times.
  final bool continuous;
  final Duration repeatDelay;

  @override
  State<BarcodeScannerView> createState() => _BarcodeScannerViewState();
}

class _BarcodeScannerViewState extends State<BarcodeScannerView> with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _animController;
  bool _isInternalController = false;
  bool _hasDetected = false;
  String? _lastCode;
  DateTime? _lastAt;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = MobileScannerController(detectionSpeed: widget.continuous ? DetectionSpeed.normal : DetectionSpeed.noDuplicates);
      _isInternalController = true;
    }

    _animController = AnimationController(
      vsync: this,
      duration: AppDurations.milliseconds1800,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    if (_isInternalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handleDetect(BarcodeCapture capture) {
    if (_hasDetected) return;
    final code = capture.barcodes.map((barcode) => barcode.rawValue).nonNulls.firstOrNull;
    if (code == null || code.isEmpty) return;
    if (widget.continuous) {
      final now = DateTime.now();
      if (code == _lastCode && _lastAt != null && now.difference(_lastAt!) < widget.repeatDelay) {
        _lastAt = now;
        return;
      }
      _lastCode = code;
      _lastAt = now;
      widget.onDetect(code);
      return;
    }
    _hasDetected = true;
    widget.onDetect(code);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final availableHeight = constraints.maxHeight;

        // Proportional target box scaled to available viewport
        final scanBoxWidth = (availableWidth * 0.78).clamp(180.0, 280.0);
        final scanBoxHeight = (scanBoxWidth * 0.65).clamp(120.0, 190.0);

        return Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: _handleDetect,
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
                            color: widget.laserColor.withValues(alpha: 0.8),
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
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  widget.laserColor,
                                  AppColors.emerald400,
                                  widget.laserColor,
                                  Colors.transparent,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.laserColor.withValues(alpha: 0.6),
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

            // Hint instruction pill
            if (widget.hintText.isNotEmpty)
              Positioned(
                left: 16,
                right: 16,
                bottom: (availableHeight * 0.08).clamp(16.0, 48.0),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(AppRadius.r30),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(AppIcons.scanLine, size: AppSizes.s14, color: widget.laserColor),
                        const SizedBox(width: AppSizes.s6),
                        Flexible(
                          child: Text(
                            widget.hintText,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
