import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_pos_mobile/core/storage/app_storage.dart';
import 'package:web_pos_mobile/core/utils/display_service.dart';
import 'package:web_pos_mobile/features/pos/data/pos_models.dart';
import 'package:web_pos_mobile/features/pos/presentation/widgets/qris_view.dart';

class FakeDisplayService extends DisplayService {
  int setMaxBrightnessCallCount = 0;
  int resetBrightnessCallCount = 0;

  @override
  Future<void> setMaxBrightness() async {
    setMaxBrightnessCallCount++;
    await super.setMaxBrightness();
  }

  @override
  Future<void> resetBrightness() async {
    resetBrightnessCallCount++;
    await super.resetBrightness();
  }
}

const _testQris = QrisPayment(
  payload: '00020101021226600016ID.CO.SHOPEE.WWW0118936009180000000000',
  amount: 50000,
  merchantName: 'Toko Berkah',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeDisplayService fakeDisplayService;

  setUp(() {
    fakeDisplayService = FakeDisplayService();
  });

  testWidgets('sets max brightness when QrisPaymentView is mounted and resets on dispose (default true)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          displayServiceProvider.overrideWithValue(fakeDisplayService),
          qrisProvider(50000).overrideWith((ref) async => _testQris),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: QrisPaymentView(amount: 50000),
          ),
        ),
      ),
    );

    // Initial mount sets brightness to max because default is true
    expect(fakeDisplayService.isMaxBrightness, isTrue);
    expect(fakeDisplayService.setMaxBrightnessCallCount, greaterThanOrEqualTo(1));

    await tester.pumpAndSettle();
    expect(find.text('Toko Berkah'), findsOneWidget);
    expect(fakeDisplayService.isMaxBrightness, isTrue);

    // Unmount QrisPaymentView
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(fakeDisplayService.isMaxBrightness, isFalse);
    expect(fakeDisplayService.resetBrightnessCallCount, greaterThanOrEqualTo(1));
  });

  testWidgets('does not set max brightness when qrFullBrightness is false in local settings', (tester) async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.posQrFullBrightness: false,
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          displayServiceProvider.overrideWithValue(fakeDisplayService),
          qrisProvider(50000).overrideWith((ref) async => _testQris),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: QrisPaymentView(amount: 50000),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Toko Berkah'), findsOneWidget);
    expect(fakeDisplayService.isMaxBrightness, isFalse);
    expect(fakeDisplayService.setMaxBrightnessCallCount, equals(0));
  });

  testWidgets('resets brightness when qrisProvider returns error', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          displayServiceProvider.overrideWithValue(fakeDisplayService),
          qrisProvider(50000).overrideWith((ref) async => throw Exception('Gagal membuat QRIS')),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: QrisPaymentView(amount: 50000),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.textContaining('Gagal membuat QRIS'), findsOneWidget);
    expect(fakeDisplayService.isMaxBrightness, isFalse);
  });
}
