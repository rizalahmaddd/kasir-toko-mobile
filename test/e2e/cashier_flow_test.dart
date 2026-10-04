// Runs the real repositories against a live server:
//   E2E_SERVER=http://127.0.0.1:8000 flutter test test/e2e
// It opens a shift and records a sale, so point it at a throwaway database, never production.
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:web_pos_mobile/core/network/api_client.dart';
import 'package:web_pos_mobile/core/network/api_exception.dart';
import 'package:web_pos_mobile/core/storage/app_storage.dart';
import 'package:web_pos_mobile/features/auth/data/current_user.dart';
import 'package:web_pos_mobile/features/pos/data/pos_models.dart';
import 'package:web_pos_mobile/features/pos/data/pos_repository.dart';
import 'package:web_pos_mobile/features/sales/data/sales_repository.dart';
import 'package:web_pos_mobile/features/shift/data/shift_repository.dart';

final _server = Platform.environment['E2E_SERVER'];

void main() {
  group('cashier e2e', () {
    late ProviderContainer container;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({StorageKeys.serverUrl: _server ?? ''});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);

      final body = await container
          .read(apiClientProvider)
          .post('auth/login', data: {'login': Platform.environment['E2E_LOGIN'] ?? 'kasir', 'password': Platform.environment['E2E_PASSWORD'] ?? 'password', 'device_name': 'e2e'});
      final data = ApiClient.data(body);
      CurrentUser.fromJson(data['user'] as Map<String, dynamic>);
      container.read(authTokenProvider.notifier).set(data['token'] as String);
    });

    tearDownAll(() async {
      await container.read(apiClientProvider).post('auth/logout');
      container.dispose();
    });

    test('cashier can sell, hold, and review a transaction', () async {
      final pos = container.read(posRepositoryProvider);
      final shifts = container.read(shiftRepositoryProvider);
      final sales = container.read(salesRepositoryProvider);

      final shift = await shifts.current() ?? await shifts.open(200000);
      expect(shift.isOpen, isTrue);

      final config = await pos.config();
      expect(config.hasOpenShift, isTrue);
      expect(config.paymentMethods.map((m) => m.value), contains('cash'));

      await pos.categories();
      final catalog = await pos.products();
      final product = catalog.items.firstWhere((p) => !p.trackStock || p.stock >= 2);
      if (product.barcode != null) {
        expect((await pos.lookup(product.barcode!)).id, product.id);
      }

      final cart = Cart(clientUuid: const Uuid().v4(), items: [CartItem.fromProduct(product, quantity: 2)]);
      final total = cart.totals(config.taxRate).total;

      try {
        await pos.checkout(
          cart: cart.copyWith(items: [cart.items.first.copyWith(price: product.price + 1)]),
          payments: const [],
          expectedTotal: total,
        );
        fail('A stale price must be rejected');
      } on ApiException catch (error) {
        expect(error.reason, 'price_changed');
      }

      final cash = total + 5000;
      final sale = await pos.checkout(
        cart: cart,
        payments: [PaymentLine(method: 'cash', amount: cash)],
        expectedTotal: total,
      );
      expect(sale.total, total);
      expect(sale.changeAmount, 5000);

      final retried = await pos.checkout(
        cart: cart,
        payments: [PaymentLine(method: 'cash', amount: cash)],
        expectedTotal: total,
      );
      expect(retried.id, sale.id, reason: 'Same client_uuid must not create a second sale');

      final receipt = await sales.receipt(sale.id);
      expect(receipt.text, contains(sale.number));

      final today = DateTime.now();
      final list = await sales.list(from: today, to: today);
      expect(list.items.map((s) => s.id), contains(sale.id));
      expect((await sales.show(sale.id)).items, hasLength(1));

      await pos.holdOrder(cart: cart, total: total, label: 'e2e');
      final held = (await pos.heldOrders()).firstWhere((order) => order.label == 'e2e');
      final resumed = await pos.resumeHeldOrder(held.id);
      expect(Cart.fromJson(resumed.cart!, fallbackUuid: 'x').items.single.productId, product.id);

      await shifts.recordCash(type: 'in', amount: 1000, reason: 'e2e kas masuk');
      final refreshed = await shifts.current();
      expect(refreshed!.summary!.cashIn, greaterThanOrEqualTo(1000));
    });
  }, skip: _server == null ? 'Set E2E_SERVER to run against a live API' : false);
}
