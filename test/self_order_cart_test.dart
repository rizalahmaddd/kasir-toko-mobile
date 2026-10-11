import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';
import 'package:web_pos_mobile/core/network/api_exception.dart';
import 'package:web_pos_mobile/core/storage/app_storage.dart';
import 'package:web_pos_mobile/features/pos/cart_controller.dart';
import 'package:web_pos_mobile/features/pos/cart_math.dart';
import 'package:web_pos_mobile/features/pos/data/pos_models.dart';
import 'package:web_pos_mobile/features/pos/data/pos_repository.dart';
import 'package:web_pos_mobile/features/pos/pos_providers.dart';
import 'package:web_pos_mobile/features/self_orders/data/self_order_models.dart';

const _latte = Product(id: 7, name: 'Latte', unit: 'gelas', price: 30000, trackStock: false, stock: 0, tiers: [PriceTier(min: 3, price: 25000)]);

/// Bentuk `data` dari GET pos/self-orders/{id}/cart: baris dengan harga yang dikunci saat dipesan.
Map<String, dynamic> _serverCart() => {
      'self_order_id': 12,
      'number': 'SO-2026-000012',
      'orderType': 'take_away',
      'table': '',
      'kitchenSent': <String, dynamic>{},
      'total': 54000,
      'items': [
        {
          'product_id': 7,
          'name': 'Latte',
          'unit': 'gelas',
          'price': 28000,
          'quantity': 2,
          'discount': 0,
          'auto_discount': 2000,
          'modifiers': <Map<String, dynamic>>[],
          'self_order_item_id': 41,
          'self_order_id': 12,
          'self_order_quantity': 2,
          'self_order_label': 'SO-2026-000012',
          'track': false,
          'stock': 0,
        },
      ],
    };

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: <Override>[
      sharedPreferencesProvider.overrideWithValue(prefs),
      posConfigProvider.overrideWith((ref) => Completer<PosConfig>().future),
    ],
  );
  addTearDown(container.dispose);

  return container;
}

void main() {
  test('a loaded QR order keeps its locked price and discount and sends its ids to checkout', () async {
    final container = await _container();
    container.read(cartProvider.notifier).loadSelfOrder(_serverCart());
    final cart = container.read(cartProvider);
    final line = cart.items.single;

    expect(line.isSelfOrder, isTrue);
    expect(line.unitPrice, 28000);
    expect(line.autoDiscount, 2000);
    expect(line.total, 54000);

    final payload = PosRepository.checkoutPayload(cart: cart, payments: const [], expectedTotal: 54000);

    expect(payload['self_order_ids'], [12]);
    expect((payload['items'] as List).single, containsPair('self_order_item_id', 41));
    expect((payload['items'] as List).single, containsPair('auto_discount', 2000));
  });

  test('the same product added by the cashier stays a separate line and never reprices the QR line', () async {
    final container = await _container();
    final cart = container.read(cartProvider.notifier)..loadSelfOrder(_serverCart());

    expect(cart.add(_latte), isNull);
    final items = container.read(cartProvider).items;

    expect(items, hasLength(2));
    expect(items.firstWhere((item) => item.isSelfOrder).unitPrice, 28000);
    // Baris QR (2 gelas) tidak dihitung ke batas grosir 3 gelas milik baris kasir.
    expect(items.firstWhere((item) => !item.isSelfOrder).unitPrice, 30000);
  });

  test('the ordered quantity can shrink but not grow, and the locked discount shrinks with it', () async {
    final container = await _container();
    final cart = container.read(cartProvider.notifier)..loadSelfOrder(_serverCart());
    final key = container.read(cartProvider).items.single.key;

    expect(cart.setQuantity(key, 3), SelfOrderStrings.quantityLocked);
    expect(container.read(cartProvider).items.single.quantity, 2);

    expect(cart.setQuantity(key, 1), isNull);
    expect(container.read(cartProvider).items.single.autoDiscount, 1000);
  });

  test('QR lines survive being held and resumed, and are dropped when the server says the order is gone', () async {
    final container = await _container();
    final cart = container.read(cartProvider.notifier)
      ..loadSelfOrder(_serverCart())
      ..add(_latte);

    cart.load(container.read(cartProvider).toJson());
    final resumed = container.read(cartProvider).items.firstWhere((item) => item.isSelfOrder);

    expect(resumed.selfOrderItemId, 41);
    expect(resumed.selfOrderQuantity, 2);
    expect(resumed.autoDiscount, 2000);

    cart.applyRejection(ApiException(message: '', reason: 'self_order_invalid', context: {'self_order_item_ids': [41]}));

    expect(container.read(cartProvider).items.single.isSelfOrder, isFalse);
  });

  test('inbox orders expose the next cashier action', () {
    final order = SelfOrder.fromJson({
      'id': 3,
      'number': 'SO-2026-000003',
      'label': 'Meja 05',
      'customer_name': 'Rina',
      'status': 'ready',
      'status_label': 'Siap',
      'payment_method': 'qris',
      'payment_status': 'paid',
      'payment_label': 'Lunas',
      'next_action': null,
      'total': 28000,
      'table_label': '05',
      'items': [
        {'name': 'Latte', 'quantity': 1, 'modifiers': ['Large'], 'note': null},
      ],
      'created_at': '2026-10-11T10:00:00+07:00',
    });

    expect(order.needsAttention, isTrue);
    expect(order.isDineIn, isTrue);
    expect(order.isPaid, isTrue);
    expect(order.items.single.modifiers, ['Large']);
  });
}
