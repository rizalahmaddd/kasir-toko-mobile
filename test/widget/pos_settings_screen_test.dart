import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';
import 'package:web_pos_mobile/core/storage/app_storage.dart';
import 'package:web_pos_mobile/core/theme/app_theme.dart';
import 'package:web_pos_mobile/features/pos/data/pos_models.dart';
import 'package:web_pos_mobile/features/pos/pos_providers.dart';
import 'package:web_pos_mobile/features/pos/presentation/pos_settings_screen.dart';

const _config = PosConfig(
  taxRate: 11,
  taxLabel: 'PPN',
  allowNegativeStock: false,
  allowCredit: true,
  canDiscount: true,
  receiptWidth: '58',
  quickCash: [20000, 50000, 100000],
  paymentMethods: [
    PaymentMethodOption(value: 'cash', label: 'Tunai'),
    PaymentMethodOption(value: 'qris', label: 'QRIS'),
  ],
  qrisEnabled: true,
  hasOpenShift: true,
  heldOrdersCount: 0,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders local display settings switches with default true', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          posConfigProvider.overrideWith((ref) async => _config),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const PosSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(PosStrings.sectionDisplayScreen), findsOneWidget);
    expect(find.text(PosStrings.keepScreenOnTitle), findsOneWidget);
    expect(find.text(PosStrings.qrFullBrightnessTitle), findsOneWidget);

    // Both switches should be true by default
    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    // allowNegativeStock (false), allowCredit (true), autoPrint (false), keepScreenOn (true), qrFullBrightness (true)
    expect(switches.length, equals(5));
    // The last two switches are keepScreenOn and qrFullBrightness
    expect(switches[3].value, isTrue);
    expect(switches[4].value, isTrue);
  });

  testWidgets('toggling keepScreenOn and qrFullBrightness saves to SharedPreferences locally without API call', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          posConfigProvider.overrideWith((ref) async => _config),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const PosSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Toggle keepScreenOn switch off
    final keepScreenFinder = find.text(PosStrings.keepScreenOnTitle);
    await tester.ensureVisible(keepScreenFinder);
    await tester.pumpAndSettle();
    await tester.tap(keepScreenFinder);
    await tester.pumpAndSettle();

    expect(prefs.getBool(StorageKeys.posKeepScreenOn), isFalse);

    // Toggle qrFullBrightness switch off
    final qrBrightnessFinder = find.text(PosStrings.qrFullBrightnessTitle);
    await tester.ensureVisible(qrBrightnessFinder);
    await tester.pumpAndSettle();
    await tester.tap(qrBrightnessFinder);
    await tester.pumpAndSettle();

    expect(prefs.getBool(StorageKeys.posQrFullBrightness), isFalse);

    // Toggle keepScreenOn back on
    await tester.ensureVisible(keepScreenFinder);
    await tester.pumpAndSettle();
    await tester.tap(keepScreenFinder);
    await tester.pumpAndSettle();

    expect(prefs.getBool(StorageKeys.posKeepScreenOn), isTrue);
  });
}
