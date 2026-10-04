import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:web_pos_mobile/core/storage/app_storage.dart';
import 'package:web_pos_mobile/core/theme/app_theme.dart';
import 'package:web_pos_mobile/features/printing/presentation/printer_screen.dart';
import 'package:web_pos_mobile/features/printing/presentation/receipt_preview.dart';
import 'package:web_pos_mobile/features/printing/printer.dart';
import 'package:web_pos_mobile/features/printing/receipt_layout.dart';

const _profile = ReceiptProfile(
  storeName: 'Toko Sumber Rejeki',
  address: 'Jl. Merdeka 10, Malang',
  phone: '0341-123456',
  header: 'Buka 07.00 - 21.00',
  footer: 'Terima kasih atas kunjungan Anda',
  taxLabel: 'PPN',
);

class _FakePrinterService extends PrinterService {
  _FakePrinterService(super.ref);

  @override
  Future<List<BluetoothInfo>> pairedDevices() async => [
    BluetoothInfo(name: 'RPP02N', macAdress: 'AA:BB'),
  ];
}

Future<SharedPreferences> _pump(WidgetTester tester, Size size, {Map<String, Object> prefs = const {}}) async {
  await initializeDateFormatting('id_ID');
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('groons.web.app/print'),
    (call) async => switch (call.method) {
      'pairedbluetooths' => ['RPP02N#AA:BB'],
      'disconnect' => true,
      _ => true,
    },
  );
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('groons.web.app/print'), null));
  final preferences = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        receiptProfileProvider.overrideWith((ref) async => _profile),
        printerServiceProvider.overrideWith((ref) => _FakePrinterService(ref)),
      ],
      child: MaterialApp(theme: AppTheme.dark(), home: const PrinterScreen()),
    ),
  );
  await tester.pumpAndSettle();

  return preferences;
}

void main() {
  for (final (label, size) in [('phone', const Size(390, 844)), ('tablet', const Size(1280, 800))]) {
    testWidgets('$label: settings and preview render without overflow', (tester) async {
      await _pump(tester, size);

      expect(tester.takeException(), isNull);
      expect(find.byType(ReceiptPreview), findsOneWidget);
      expect(find.text('Jl. Merdeka 10, Malang'), findsOneWidget);
      expect(find.text('Pilih printer dulu untuk tes cetak'), findsOneWidget);
      expect(find.text('RPP02N'), findsOneWidget);
    });
  }

  testWidgets('paper width and copies are remembered on this device', (tester) async {
    final prefs = await _pump(tester, const Size(390, 1600), prefs: {'printer_address': 'AA:BB', 'printer_name': 'RPP02N'});

    await tester.tap(find.text('80 mm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();

    expect(prefs.getString('printer_width'), '80');
    expect(prefs.getInt('printer_copies'), 2);
    expect(find.text('AA:BB · 80 mm'), findsOneWidget);
    expect(find.text('Cetak halaman tes'), findsOneWidget);
  });

  test('paper width follows the store setting until the cashier picks one', () async {
    SharedPreferences.setMockInitialValues({ReceiptProfile.cacheKey: '{"store_name":"Toko","paper_width":"80"}'});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(container.dispose);

    expect(container.read(printerSettingsProvider).paperWidth, '80');
  });
}
