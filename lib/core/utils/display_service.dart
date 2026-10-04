import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Service to manage screen wakelock and brightness.
///
/// Used to:
/// - Keep the device screen awake while the cashier (POS) tab/menu is open.
/// - Set the screen brightness to maximum when displaying QR codes (e.g. QRIS payment)
///   and restore the previous/system brightness when closed.
class DisplayService {
  DisplayService({ScreenBrightness? screenBrightness})
      : _screenBrightness = screenBrightness ?? ScreenBrightness.instance;

  final ScreenBrightness _screenBrightness;

  static final DisplayService instance = DisplayService();

  bool _isWakelockEnabled = false;
  bool _isMaxBrightness = false;

  bool get isWakelockEnabled => _isWakelockEnabled;
  bool get isMaxBrightness => _isMaxBrightness;

  /// Keeps the screen awake (prevents screen timeout/sleep).
  Future<void> keepScreenOn() async {
    _isWakelockEnabled = true;
    try {
      await WakelockPlus.enable();
    } catch (e) {
      debugPrint('DisplayService.keepScreenOn error: $e');
    }
  }

  /// Releases wake lock so device can sleep normally according to system settings.
  Future<void> allowScreenSleep() async {
    _isWakelockEnabled = false;
    try {
      await WakelockPlus.disable();
    } catch (e) {
      debugPrint('DisplayService.allowScreenSleep error: $e');
    }
  }

  /// Sets screen brightness to full (1.0) for easy QR scanning.
  Future<void> setMaxBrightness() async {
    _isMaxBrightness = true;
    try {
      await _screenBrightness.setApplicationScreenBrightness(1.0);
    } catch (e) {
      debugPrint('DisplayService.setMaxBrightness error: $e');
    }
  }

  /// Resets screen brightness to system / previous brightness.
  Future<void> resetBrightness() async {
    _isMaxBrightness = false;
    try {
      await _screenBrightness.resetApplicationScreenBrightness();
    } catch (e) {
      debugPrint('DisplayService.resetBrightness error: $e');
    }
  }
}

final displayServiceProvider = Provider<DisplayService>((ref) {
  return DisplayService.instance;
});
