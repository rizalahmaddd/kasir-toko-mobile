// Runs every repository against a live server as superadmin, so a response the models can't parse
// shows up here before a cashier sees it:
//   E2E_SERVER=http://127.0.0.1:8000 flutter test test/e2e
// It creates and voids records, so point it at a throwaway database, never production.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:web_pos_mobile/core/network/api_client.dart';
import 'package:web_pos_mobile/core/network/api_exception.dart';
import 'package:web_pos_mobile/core/storage/app_storage.dart';
import 'package:web_pos_mobile/features/auth/data/current_user.dart';
import 'package:web_pos_mobile/features/customers/data/customers_repository.dart';
import 'package:web_pos_mobile/features/dashboard/dashboard.dart';
import 'package:web_pos_mobile/features/notifications/notifications.dart';
import 'package:web_pos_mobile/features/pos/data/pos_models.dart';
import 'package:web_pos_mobile/features/pos/data/pos_repository.dart';
import 'package:web_pos_mobile/features/printing/printer.dart';
import 'package:web_pos_mobile/features/printing/receipt_layout.dart';
import 'package:web_pos_mobile/features/products/data/product_models.dart';
import 'package:web_pos_mobile/features/products/data/products_repository.dart';
import 'package:web_pos_mobile/features/receivables/receivables.dart';
import 'package:web_pos_mobile/features/reports/reports.dart';
import 'package:web_pos_mobile/features/sales/data/sales_repository.dart';
import 'package:web_pos_mobile/features/shift/data/shift_repository.dart';

final _server = Platform.environment['E2E_SERVER'];

void main() {
  group('back office e2e', () {
    late ProviderContainer container;
    final tag = DateTime.now().millisecondsSinceEpoch.toString().substring(6);

    setUpAll(() async {
      await initializeDateFormatting('id_ID');
      SharedPreferences.setMockInitialValues({StorageKeys.serverUrl: _server ?? ''});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);

      final body = await container
          .read(apiClientProvider)
          .post('auth/login', data: {'login': Platform.environment['E2E_ADMIN'] ?? 'superadmin', 'password': Platform.environment['E2E_PASSWORD'] ?? 'password', 'device_name': 'e2e'});
      final data = ApiClient.data(body);
      CurrentUser.fromJson(data['user'] as Map<String, dynamic>);
      container.read(authTokenProvider.notifier).set(data['token'] as String);
    });

    tearDownAll(() async {
      await container.read(apiClientProvider).post('auth/logout');
      container.dispose();
    });

    test('dashboard, notifications, search and receipt profile parse', () async {
      final dashboard = await container.read(dashboardProvider.future);
      expect(dashboard.stats, isNotEmpty);

      final notifications = container.read(notificationsRepositoryProvider);
      await notifications.list();
      await notifications.unreadCount();
      await notifications.search('ber');

      final profile = await container.read(receiptProfileProvider.future);
      expect(profile.storeName, isNotEmpty);
    });

    test('categories, products, stock and customers round-trip', () async {
      final products = container.read(productsRepositoryProvider);

      final category = await products.saveCategory(name: 'E2E Kategori $tag', sortOrder: 99, isActive: true);
      final product = await products.saveProduct(
        ProductInput(categoryId: category.id, sku: 'E2E-$tag', name: 'E2E Produk $tag', unit: 'pcs', costPrice: 5000, price: 8000, trackStock: true, stock: 10, minStock: 2, isActive: true),
      );
      expect(product.price, 8000);

      final updated = await products.saveProduct(
        ProductInput(categoryId: category.id, sku: 'E2E-$tag', name: 'E2E Produk $tag', unit: 'pcs', costPrice: 5000, price: 9000, trackStock: true, minStock: 2, isActive: true),
        id: product.id,
      );
      expect(updated.price, 9000);
      expect((await products.product(product.id)).name, 'E2E Produk $tag');
      expect((await products.products(search: 'E2E Produk $tag')).items.map((p) => p.id), contains(product.id));

      final movement = await products.adjust(productId: product.id, type: 'stock_in', quantity: 5, unitCost: 5000, note: 'e2e');
      expect(movement.quantity, 5);
      await products.stock(search: 'E2E Produk $tag');
      await products.stockSummary();
      expect((await products.movements(productId: product.id)).items, isNotEmpty);
      await products.categories();

      final customers = container.read(customersRepositoryProvider);
      final customer = await customers.save(Customer(id: 0, code: 'E2E-$tag', name: 'E2E Pelanggan $tag', phone: '08123$tag', paymentTermDays: 0, isActive: true));
      expect((await customers.show(customer.id)).name, 'E2E Pelanggan $tag');
      await customers.list(search: 'E2E Pelanggan');

      await products.deleteProduct(product.id);
      await products.deleteCategory(category.id);
      await customers.delete(customer.id);
    });

    test('credit sale, partial payment, void and shift close', () async {
      final pos = container.read(posRepositoryProvider);
      final shifts = container.read(shiftRepositoryProvider);
      final sales = container.read(salesRepositoryProvider);

      final shift = await shifts.current() ?? await shifts.open(100000);
      final config = await pos.config();
      if (!config.allowCredit) {
        markTestSkipped('Kasbon is disabled on this server');
        return;
      }

      final customer = await pos.createCustomer(name: 'E2E Kasbon $tag', phone: '08987$tag');
      final product = (await pos.products()).items.firstWhere((p) => !p.trackStock || p.stock >= 1);
      final cart = Cart(clientUuid: const Uuid().v4(), items: [CartItem.fromProduct(product)], customer: customer, note: 'e2e kasbon');
      final total = cart.totals(config.taxRate).total;

      final sale = await pos.checkout(cart: cart, payments: const [], expectedTotal: total);
      expect(sale.dueAmount, total);
      expect(sale.note, 'e2e kasbon');

      final receivables = container.read(receivablesRepositoryProvider);
      expect((await receivables.list(customerId: customer.id)).items.map((s) => s.id), contains(sale.id));
      final paid = await receivables.pay(sale.id, amount: 1000, method: 'cash');
      expect(paid.dueAmount, total - 1000);

      final lines = saleReceipt(paid, profile: await container.read(receiptProfileProvider.future), paperWidth: '58');
      expect(lines.map((l) => l.text).any((l) => l.startsWith('Sisa kasbon')), isTrue);

      final voided = await sales.voidSale(sale.id, 'e2e salah input');
      expect(voided.isVoided, isTrue);
      try {
        await sales.voidSale(sale.id, 'lagi');
        fail('A voided sale must not void twice');
      } on ApiException catch (error) {
        expect(error.statusCode, anyOf(409, 422, 403));
      }

      await shifts.list();
      await shifts.sales(shift.id);
      await shifts.recordCashFor(shift.id, type: 'out', amount: 500, reason: 'e2e kas keluar');
      final current = await shifts.show(shift.id);
      final closed = await shifts.close(shift.id, countedCash: current.summary!.expected, note: 'e2e');
      expect(closed.isOpen, isFalse);
      expect(closed.cashDifference, 0);
      expect(shiftRecap(closed, profile: const ReceiptProfile(storeName: 'Toko'), paperWidth: '58'), isNotEmpty);
    });

    test('reports parse for the last 30 days', () async {
      final reports = container.read(reportsRepositoryProvider);
      final now = DateTime.now();
      final range = DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now);

      await reports.summary(range);
      await reports.daily(range);
      await reports.products(range, sort: 'revenue');
      await reports.products(range, sort: 'quantity');
      await reports.activity();
    });
  }, skip: _server == null ? 'Set E2E_SERVER to run against a live API' : false);
}
