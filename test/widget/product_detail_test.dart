import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';
import 'package:web_pos_mobile/core/network/api_client.dart';
import 'package:web_pos_mobile/core/storage/app_storage.dart';
import 'package:web_pos_mobile/core/theme/app_theme.dart';
import 'package:web_pos_mobile/features/auth/auth_controller.dart';
import 'package:web_pos_mobile/features/products/data/product_models.dart';
import 'package:web_pos_mobile/features/products/presentation/product_detail_screen.dart';
import 'package:web_pos_mobile/features/products/products_providers.dart';

const _sample = ProductRecord(
  id: 42,
  sku: 'PRD-042',
  barcode: '89912345678',
  name: 'Kopi Susu Gula Aren',
  unit: 'cup',
  costPrice: 8000,
  price: 18000,
  trackStock: true,
  stock: 50,
  minStock: 10,
  isLowStock: false,
  isActive: true,
);

class _FakeProductDetailNotifier extends ProductDetailNotifier {
  _FakeProductDetailNotifier(super.arg);

  @override
  Future<ProductRecord?> loadCache(int id) async => null;

  @override
  Future<ProductRecord> fetchRemote(int id) async => _sample;
}

class _FakeMovementsNotifier extends MovementsNotifier {
  _FakeMovementsNotifier(super.query);

  @override
  Future<Paginated<StockMovement>> fetch(int page) async =>
      const Paginated<StockMovement>(items: [], currentPage: 1, lastPage: 1);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  testWidgets('renders ProductDetailScreen without rendering exceptions', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          productDetailProvider(42).overrideWith(() => _FakeProductDetailNotifier(42)),
          movementsProvider((productId: 42, type: null, search: '')).overrideWith(
            () => _FakeMovementsNotifier((productId: 42, type: null, search: '')),
          ),
          currentUserProvider.overrideWith((ref) => null),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ProductDetailScreen(productId: 42),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Kopi Susu Gula Aren'), findsWidgets);
    expect(find.text('PRD-042'), findsOneWidget);
    expect(find.text('Rp18.000'), findsOneWidget);
    expect(find.text('Harga Jual'), findsOneWidget);
    expect(find.text(ProductStrings.labelCostPrice), findsOneWidget);
    expect(find.text('Stok Saat Ini'), findsOneWidget);
  });
}
