import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_pos_mobile/core/storage/app_storage.dart';
import 'package:web_pos_mobile/core/theme/app_theme.dart';
import 'package:web_pos_mobile/features/auth/auth_controller.dart';
import 'package:web_pos_mobile/features/auth/data/current_user.dart';
import 'package:web_pos_mobile/features/pos/data/pos_models.dart';
import 'package:web_pos_mobile/features/pos/pos_providers.dart';
import 'package:web_pos_mobile/features/pos/presentation/pos_screen.dart';
import 'package:web_pos_mobile/features/shift/data/shift_models.dart';
import 'package:web_pos_mobile/features/shift/presentation/shift_screen.dart';
import 'package:web_pos_mobile/features/shift/shift_controller.dart';

const _user = CurrentUser(
  id: 3,
  name: 'Kasir Demo',
  username: 'kasir',
  roles: ['kasir'],
  permissions: {'pos.sell', 'pos.discount'},
  isSuperadmin: false,
  enabledFeatures: {'pos.cashier', 'pos.sales', 'pos.shifts'},
);

final _shift = Shift(
  id: 1,
  number: 'SFT-0001',
  isOpen: true,
  cashierName: 'Kasir Demo',
  openedAt: DateTime(2026, 10, 1, 8),
  openingCash: 200000,
  summary: const ShiftSummary(
    opening: 200000,
    cashSales: 450000,
    cashReceivables: 0,
    cashIn: 10000,
    cashOut: 25000,
    expected: 635000,
    salesCount: 12,
    salesTotal: 780000,
    voidedCount: 1,
    nonCash: {'qris': 330000, 'transfer': 0, 'card': 0},
  ),
  cashMovements: [
    CashMovement(id: 1, type: 'out', typeLabel: 'Kas keluar', amount: 25000, reason: 'Beli es batu dan plastik kresek besar', createdAt: DateTime(2026, 10, 1, 9)),
  ],
  canClose: true,
  canRecordCash: true,
);

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
    PaymentMethodOption(value: 'transfer', label: 'Transfer'),
    PaymentMethodOption(value: 'card', label: 'Kartu'),
  ],
  qrisEnabled: false,
  hasOpenShift: true,
  heldOrdersCount: 2,
);

final _products = [
  for (var i = 1; i <= 24; i++)
    Product(
      id: i,
      name: i == 1 ? 'Minyak Goreng Sania Pouch 2 Liter Kemasan Hemat' : 'Produk $i',
      sku: 'SKU-$i',
      unit: 'pcs',
      price: 1000 * i + 500,
      trackStock: i.isEven,
      stock: i == 2 ? 0 : 15,
      isLowStock: i == 4,
    ),
];

class _FakeShift extends CurrentShiftController {
  @override
  Future<Shift?> build() async => _shift;
}

class _FakeCatalog extends CatalogController {
  @override
  Future<CatalogPage> build() async => CatalogPage(products: _products, page: 1, hasMore: false);
}

Future<List<Override>> _overrides() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    currentUserProvider.overrideWithValue(_user),
    currentShiftProvider.overrideWith(_FakeShift.new),
    posConfigProvider.overrideWith((ref) async => _config),
    posCategoriesProvider.overrideWith((ref) async => const [Category(id: 1, name: 'Sembako'), Category(id: 2, name: 'Minuman')]),
    catalogProvider.overrideWith(_FakeCatalog.new),
  ];
}

Future<void> _pump(WidgetTester tester, Widget screen, Size size) async {
  await initializeDateFormatting('id_ID');
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: await _overrides(),
      child: MaterialApp(theme: AppTheme.dark(), home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const phone = Size(390, 844);
  const tablet = Size(1280, 800);

  testWidgets('phone: add products, open cart, then payment', (tester) async {
    await _pump(tester, const PosScreen(), phone);

    await tester.tap(find.text('Minyak Goreng Sania Pouch 2 Liter Kemasan Hemat'));
    await tester.tap(find.text('Produk 3'));
    await tester.pumpAndSettle();
    expect(find.text('2 barang'), findsOneWidget);

    await tester.tap(find.text('2 barang'));
    await tester.pumpAndSettle();
    expect(find.text('Keranjang'), findsOneWidget);

    await tester.tap(find.textContaining('Bayar Rp'));
    await tester.pumpAndSettle();
    expect(find.text('Total tagihan'), findsOneWidget);

    await tester.tap(find.text('Uang pas'));
    await tester.pumpAndSettle();
    expect(find.text('Kembalian'), findsOneWidget);
  });

  testWidgets('phone: out-of-stock product is not added', (tester) async {
    await _pump(tester, const PosScreen(), phone);

    await tester.tap(find.text('Produk 2'));
    await tester.pumpAndSettle();

    expect(find.text('Stok Produk 2 habis.'), findsOneWidget);
    expect(find.textContaining('barang'), findsNothing);
  });

  testWidgets('tablet: catalog and cart side by side', (tester) async {
    await _pump(tester, const PosScreen(), tablet);

    await tester.tap(find.text('Produk 5'));
    await tester.pumpAndSettle();

    expect(find.text('Pelanggan umum'), findsOneWidget);
    expect(find.textContaining('Bayar Rp'), findsOneWidget);
    expect(find.text('PPN 11%'), findsOneWidget);
  });

  for (final (name, size) in [('phone', phone), ('tablet', tablet)]) {
    testWidgets('$name: shift summary renders', (tester) async {
      await _pump(tester, const ShiftScreen(), size);

      expect(find.text('Uang di laci seharusnya'), findsOneWidget);
      expect(find.text('Tutup Shift'), findsOneWidget);
    });
  }
}
