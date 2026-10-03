import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_pos_mobile/core/storage/app_storage.dart';
import 'package:web_pos_mobile/core/theme/app_theme.dart';
import 'package:web_pos_mobile/features/products/data/product_models.dart';
import 'package:web_pos_mobile/features/products/presentation/product_form_screen.dart';
import 'package:web_pos_mobile/features/products/products_providers.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  testWidgets('renders ProductFormScreen for new product without errors', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allCategoriesProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ProductFormScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Tambah Produk Baru'), findsWidgets);
    expect(find.text('Informasi Produk'), findsOneWidget);
    expect(find.text('Identifikasi & Barcode'), findsOneWidget);
    expect(find.text('Harga & Margin Keuntungan'), findsOneWidget);
    expect(find.text('Manajemen Stok & Inventaris'), findsOneWidget);
    expect(find.text('Status & Ketersediaan'), findsOneWidget);
    expect(find.text('Simpan Produk Baru'), findsOneWidget);
  });

  testWidgets('renders ProductFormScreen for existing product without errors', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    const sample = ProductRecord(
      id: 10,
      sku: 'PRD-001',
      name: 'Kopi Susu',
      unit: 'cup',
      costPrice: 8000,
      price: 15000,
      trackStock: true,
      stock: 20,
      minStock: 5,
      isLowStock: false,
      isActive: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allCategoriesProvider.overrideWith((ref) async => [
            const CategoryRecord(id: 1, name: 'Minuman'),
          ]),
          productDetailProvider(10).overrideWith((ref) async => sample),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const ProductFormScreen(productId: 10),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Ubah Produk'), findsOneWidget);
    expect(find.text('Kopi Susu'), findsWidgets);
    expect(find.text('SKU: PRD-001'), findsOneWidget);
    expect(find.text('Simpan Perubahan'), findsOneWidget);
  });
}
