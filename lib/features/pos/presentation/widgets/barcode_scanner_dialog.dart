import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';
import 'package:web_pos_mobile/core/theme/app_colors.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/utils/responsive.dart';

import '../camera_scanner_screen.dart';
import 'barcode_scanner_view.dart';

/// Popup dialog barcode scanner with controls to toggle torch, switch camera,
/// close, or maximize into full-screen mode ([CameraScannerScreen]).
class BarcodeScannerDialog extends StatefulWidget {
  const BarcodeScannerDialog({super.key});

  static const _maximizeSignal = '__MAXIMIZE__';

  /// Opens the barcode scanner as a popup dialog.
  /// If the user taps the maximize button, it smoothly opens the full-screen [CameraScannerScreen].
  static Future<String?> open(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const BarcodeScannerDialog(),
    );

    if (result == _maximizeSignal) {
      if (!context.mounted) return null;
      return CameraScannerScreen.open(context);
    }

    return result;
  }

  @override
  State<BarcodeScannerDialog> createState() => _BarcodeScannerDialogState();
}

class _BarcodeScannerDialogState extends State<BarcodeScannerDialog> {
  final _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _torchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleTorch() async {
    unawaited(HapticFeedback.lightImpact());
    await _controller.toggleTorch();
    if (mounted) setState(() => _torchOn = !_torchOn);
  }

  Future<void> _switchCamera() async {
    unawaited(HapticFeedback.lightImpact());
    await _controller.switchCamera();
  }

  void _onMaximize() {
    unawaited(HapticFeedback.lightImpact());
    Navigator.of(context).pop(BarcodeScannerDialog._maximizeSignal);
  }

  void _onClose() {
    unawaited(HapticFeedback.lightImpact());
    Navigator.of(context).pop();
  }

  void _onDetect(String code) {
    unawaited(HapticFeedback.mediumImpact());
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = context.screenWidth;
    final screenHeight = context.screenHeight;

    final dialogWidth = (screenWidth - 36).clamp(300.0, 420.0);
    final dialogHeight = (screenHeight * 0.56).clamp(380.0, 480.0);

    return Dialog(
      backgroundColor: isDark ? AppColors.slate900 : Colors.black87,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.r20),
        side: BorderSide(
          color: isDark ? AppColors.slate800 : Colors.white24,
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s24),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            // Top control bar
            Container(
              padding: const EdgeInsets.fromLTRB(AppSpacing.s14, AppSpacing.s8, AppSpacing.s8, AppSpacing.s8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate900 : Colors.black,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppColors.slate800 : Colors.white12,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(AppIcons.scanBarcode, size: AppSizes.s18, color: AppColors.emerald400),
                  const SizedBox(width: AppSizes.s8),
                  const Expanded(
                    child: Text(
                      PosStrings.scanTitle,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: PosStrings.torchTooltip,
                    icon: Icon(
                      _torchOn ? AppIcons.flashlight : AppIcons.flashlightOff,
                      size: AppSizes.s18,
                      color: _torchOn ? AppColors.amber400 : Colors.white70,
                    ),
                    onPressed: _toggleTorch,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: PosStrings.switchCameraTooltip,
                    icon: const Icon(AppIcons.switchCamera, size: AppSizes.s18, color: Colors.white70),
                    onPressed: _switchCamera,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: PosStrings.maximizeScanTooltip,
                    icon: const Icon(AppIcons.maximize, size: AppSizes.s18, color: Colors.white),
                    onPressed: _onMaximize,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: PosStrings.closeScanTooltip,
                    icon: const Icon(AppIcons.x, size: AppSizes.s18, color: Colors.white70),
                    onPressed: _onClose,
                  ),
                ],
              ),
            ),

            // Camera Viewport
            Expanded(
              child: BarcodeScannerView(
                controller: _controller,
                onDetect: _onDetect,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
