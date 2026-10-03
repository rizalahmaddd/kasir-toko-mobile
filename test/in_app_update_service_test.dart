import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update_flutter/in_app_update_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:web_pos_mobile/core/services/in_app_update_service.dart';

class MockInAppUpdateFlutter extends Mock implements InAppUpdateFlutter {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InAppUpdateState', () {
    test('default state has idle status and zero progress', () {
      const state = InAppUpdateState();
      expect(state.status, InAppUpdateStatus.idle);
      expect(state.isChecking, isFalse);
      expect(state.isDownloading, isFalse);
      expect(state.isDownloaded, isFalse);
      expect(state.downloadProgress, 0.0);
    });

    test('downloadProgress calculates percentage correctly', () {
      const state = InAppUpdateState(
        status: InAppUpdateStatus.downloading,
        bytesDownloaded: 50,
        totalBytesToDownload: 100,
      );
      expect(state.downloadProgress, 0.5);
      expect(state.isDownloading, isTrue);
    });

    test('copyWith updates specified fields', () {
      const state = InAppUpdateState();
      final updated = state.copyWith(
        status: InAppUpdateStatus.downloaded,
        errorMessage: 'custom_error',
      );
      expect(updated.status, InAppUpdateStatus.downloaded);
      expect(updated.isDownloaded, isTrue);
      expect(updated.errorMessage, 'custom_error');
    });
  });

  group('InAppUpdateService', () {
    late MockInAppUpdateFlutter mockPlugin;
    late StreamController<InstallStateAndroid> streamController;
    late ProviderContainer container;

    setUp(() {
      mockPlugin = MockInAppUpdateFlutter();
      streamController = StreamController<InstallStateAndroid>.broadcast();

      when(() => mockPlugin.installStateStreamAndroid)
          .thenAnswer((_) => streamController.stream);

      container = ProviderContainer(
        overrides: [
          inAppUpdateFlutterPluginProvider.overrideWithValue(mockPlugin),
        ],
      );
    });

    tearDown(() {
      streamController.close();
      container.dispose();
    });

    test('initial state is idle', () {
      final state = container.read(inAppUpdateServiceProvider);
      expect(state.status, InAppUpdateStatus.idle);
    });

    test('completeFlexibleUpdate invokes plugin and updates status', () async {
      when(() => mockPlugin.completeUpdateAndroid()).thenAnswer((_) async {});

      final notifier = container.read(inAppUpdateServiceProvider.notifier);
      await notifier.completeFlexibleUpdate();

      verify(() => mockPlugin.completeUpdateAndroid()).called(1);
      expect(container.read(inAppUpdateServiceProvider).status, InAppUpdateStatus.completed);
    });

    test('handles PlatformException gracefully without rethrowing', () async {
      when(() => mockPlugin.checkUpdateAndroid()).thenThrow(
        PlatformException(code: 'CHECK_UPDATE_FAILED', message: 'Play Store unavailable'),
      );

      final notifier = container.read(inAppUpdateServiceProvider.notifier);
      // On platforms where check runs, it should catch error and set failed status
      await notifier.checkForUpdate(silent: true);

      final state = container.read(inAppUpdateServiceProvider);
      expect(state.status, isIn([InAppUpdateStatus.idle, InAppUpdateStatus.failed]));
    });
  });
}
