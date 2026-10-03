import 'package:flutter_test/flutter_test.dart';
import 'package:web_pos_mobile/core/utils/display_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DisplayService', () {
    late DisplayService service;

    setUp(() {
      service = DisplayService();
    });

    test('keepScreenOn sets isWakelockEnabled to true', () async {
      expect(service.isWakelockEnabled, isFalse);
      await service.keepScreenOn();
      expect(service.isWakelockEnabled, isTrue);
    });

    test('allowScreenSleep sets isWakelockEnabled to false', () async {
      await service.keepScreenOn();
      expect(service.isWakelockEnabled, isTrue);

      await service.allowScreenSleep();
      expect(service.isWakelockEnabled, isFalse);
    });

    test('setMaxBrightness sets isMaxBrightness to true', () async {
      expect(service.isMaxBrightness, isFalse);
      await service.setMaxBrightness();
      expect(service.isMaxBrightness, isTrue);
    });

    test('resetBrightness sets isMaxBrightness to false', () async {
      await service.setMaxBrightness();
      expect(service.isMaxBrightness, isTrue);

      await service.resetBrightness();
      expect(service.isMaxBrightness, isFalse);
    });
  });
}
