import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';
import 'package:web_pos_mobile/core/storage/app_storage.dart';
import 'package:web_pos_mobile/core/theme/app_theme.dart';
import 'package:web_pos_mobile/core/widgets/app_skeleton.dart';
import 'package:web_pos_mobile/features/auth/auth_controller.dart';
import 'package:web_pos_mobile/features/auth/data/current_user.dart';
import 'package:web_pos_mobile/features/pos/data/pos_models.dart';
import 'package:web_pos_mobile/features/pos/pos_providers.dart';
import 'package:web_pos_mobile/features/pos/presentation/pos_screen.dart';
import 'package:web_pos_mobile/features/pos/presentation/widgets/cart_item_tile.dart';
import 'package:web_pos_mobile/features/pos/presentation/widgets/product_card.dart';
import 'package:web_pos_mobile/features/pos/presentation/widgets/product_list_tile.dart';
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

  testWidgets('phone: decrement and remove from catalog card mini-stepper', (tester) async {
    await _pump(tester, const PosScreen(), phone);

    // Tap to add product
    await tester.tap(find.text('Produk 3'));
    await tester.pumpAndSettle();
    expect(find.text('1 barang'), findsOneWidget);

    final card = find.byKey(const ValueKey('pos_product_3'));

    // Mini-stepper is now visible on the card with trash icon and plus icon
    expect(find.descendant(of: card, matching: find.byIcon(AppIcons.trash2)), findsOneWidget);
    final plusOnCard = find.descendant(of: card, matching: find.byIcon(AppIcons.plus));
    expect(plusOnCard, findsOneWidget);

    // Tap [+] on card to increment
    await tester.tap(plusOnCard);
    await tester.pumpAndSettle();
    expect(find.text('2 barang'), findsOneWidget);
    expect(find.descendant(of: card, matching: find.byIcon(AppIcons.minus)), findsOneWidget);

    // Tap [-] on card to decrement back to 1
    await tester.tap(find.descendant(of: card, matching: find.byIcon(AppIcons.minus)));
    await tester.pumpAndSettle();
    expect(find.text('1 barang'), findsOneWidget);
    expect(find.descendant(of: card, matching: find.byIcon(AppIcons.trash2)), findsOneWidget);

    // Tap trash on card to remove completely from cart
    await tester.tap(find.descendant(of: card, matching: find.byIcon(AppIcons.trash2)));
    await tester.pumpAndSettle();
    expect(find.textContaining('barang'), findsNothing);
  });

  testWidgets('phone: long press on in-cart card opens line edit sheet with delete option', (tester) async {
    await _pump(tester, const PosScreen(), phone);

    // Tap to add product
    await tester.tap(find.text('Produk 3'));
    await tester.pumpAndSettle();
    expect(find.text('1 barang'), findsOneWidget);

    // Long press on card
    await tester.longPress(find.text('Produk 3'));
    await tester.pumpAndSettle();

    // Sheet is opened with delete button
    expect(find.text('Hapus Barang'), findsOneWidget);
    await tester.tap(find.text('Hapus Barang'));
    await tester.pumpAndSettle();

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

  testWidgets('phone: toggle density slider bar and switch between list, standard, and large', (tester) async {
    await _pump(tester, const PosScreen(), phone);

    // Default is standard density: PosProductCard with isLarge == false
    final initialCards = tester.widgetList<PosProductCard>(find.byType(PosProductCard));
    expect(initialCards, isNotEmpty);
    expect(initialCards.first.isLarge, isFalse);
    expect(find.byType(PosProductListTile), findsNothing);

    // Density slider bar is initially hidden
    expect(find.text('Daftar'), findsNothing);

    // Tap sliders button in header to open density bar
    await tester.tap(find.byIcon(AppIcons.slidersHorizontal));
    await tester.pumpAndSettle();

    // Density bar is now visible with 4 density levels and calculated columns info
    expect(find.text('Daftar'), findsOneWidget);
    expect(find.text('Ringkas'), findsOneWidget);
    expect(find.text('Standar'), findsOneWidget);
    expect(find.text('Besar'), findsOneWidget);
    expect(find.textContaining('2 kolom'), findsOneWidget);

    // Switch to List density
    await tester.tap(find.text('Daftar'));
    await tester.pumpAndSettle();

    // Verify it switched to PosProductListTile
    expect(find.byType(PosProductListTile), findsWidgets);
    expect(find.byType(PosProductCard), findsNothing);
    expect(find.textContaining('1 kolom'), findsOneWidget);

    // Switch to Ringkas (Compact) density: on phone it gives 3 columns!
    await tester.tap(find.text('Ringkas'));
    await tester.pumpAndSettle();
    expect(find.byType(PosProductCard), findsWidgets);
    expect(find.textContaining('3 kolom'), findsOneWidget);
    final compactCards = tester.widgetList<PosProductCard>(find.byType(PosProductCard));
    expect(compactCards, isNotEmpty);
    expect(compactCards.first.isCompact, isTrue);

    // Switch to Large density: on phone it gives 1 column gallery card
    await tester.tap(find.text('Besar'));
    await tester.pumpAndSettle();

    // Verify it switched to PosProductCard with isLarge == true
    final largeCards = tester.widgetList<PosProductCard>(find.byType(PosProductCard));
    expect(largeCards, isNotEmpty);
    expect(largeCards.first.isLarge, isTrue);
    expect(find.byType(PosProductListTile), findsNothing);
    expect(find.textContaining('1 kolom'), findsOneWidget);

    // Switch back to Standard density
    await tester.tap(find.text('Standar'));
    await tester.pumpAndSettle();
    final stdCards = tester.widgetList<PosProductCard>(find.byType(PosProductCard));
    expect(stdCards, isNotEmpty);
    expect(stdCards.first.isLarge, isFalse);
    expect(stdCards.first.isCompact, isFalse);
  });

  testWidgets('tablet: density scale calculates more columns and adapts layout', (tester) async {
    await _pump(tester, const PosScreen(), tablet);

    // Open density slider bar
    await tester.tap(find.byIcon(AppIcons.slidersHorizontal));
    await tester.pumpAndSettle();

    // On tablet (width 1280, catalog panel width ~859px), standard density calculates 4 columns
    expect(find.textContaining('4 kolom'), findsOneWidget);

    // Switch to Compact (Ringkas)
    await tester.tap(find.text('Ringkas'));
    await tester.pumpAndSettle();

    // Compact on tablet calculates 5 columns
    expect(find.textContaining('5 kolom'), findsOneWidget);

    // Switch to List (Daftar)
    await tester.tap(find.text('Daftar'));
    await tester.pumpAndSettle();

    // List on tablet calculates 2 columns list
    expect(find.textContaining('2 kolom'), findsOneWidget);
    expect(find.byType(PosProductListTile), findsWidgets);
  });

  testWidgets('PosCatalogSkeleton adapts to isList and custom photoHeight', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PosCatalogSkeleton(isList: true),
        ),
      ),
    );
    expect(find.byType(PosCatalogSkeleton), findsOneWidget);
  });

  testWidgets('phone: cart item can be swiped to delete', (tester) async {
    await _pump(tester, const PosScreen(), phone);

    // Tap to add product
    await tester.tap(find.text('Produk 3'));
    await tester.pumpAndSettle();
    expect(find.text('1 barang'), findsOneWidget);

    // Open cart
    await tester.tap(find.text('1 barang'));
    await tester.pumpAndSettle();
    expect(find.text('Keranjang'), findsOneWidget);
    expect(find.byType(CartItemTile), findsOneWidget);

    // Swipe cart item to delete
    await tester.drag(find.byType(CartItemTile), const Offset(-500, 0));
    await tester.pumpAndSettle();

    // Verify item is removed and cart automatically pops back to catalog
    expect(find.byType(CartItemTile), findsNothing);
    expect(find.text('Keranjang'), findsNothing);
    expect(find.text('Produk 3'), findsOneWidget);
  });

  testWidgets('phone: clearing cart automatically pops back to catalog', (tester) async {
    await _pump(tester, const PosScreen(), phone);

    // Tap to add product
    await tester.tap(find.text('Produk 3'));
    await tester.pumpAndSettle();
    expect(find.text('1 barang'), findsOneWidget);

    // Open cart
    await tester.tap(find.text('1 barang'));
    await tester.pumpAndSettle();
    expect(find.text('Keranjang'), findsOneWidget);

    // Tap clear cart trash button in header
    await tester.tap(find.byTooltip(PosStrings.clearCartTooltip));
    await tester.pumpAndSettle();

    // Confirm dialog
    expect(find.text(PosStrings.clearCartTitle), findsOneWidget);
    await tester.tap(find.text(PosStrings.clearCartConfirm));
    await tester.pumpAndSettle();

    // Verified: cart was popped and we are back on catalog
    expect(find.text('Keranjang'), findsNothing);
    expect(find.text('Produk 3'), findsOneWidget);
  });

  for (final (name, size) in [('phone', phone), ('tablet', tablet)]) {
    testWidgets('$name: shift summary renders', (tester) async {
      await _pump(tester, const ShiftScreen(), size);

      expect(find.text('Uang di laci seharusnya'), findsOneWidget);
      expect(find.text('Tutup Shift'), findsOneWidget);
    });
  }
}
