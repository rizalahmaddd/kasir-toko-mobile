import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_pos_mobile/core/network/api_exception.dart';
import 'package:web_pos_mobile/core/storage/app_storage.dart';
import 'package:web_pos_mobile/features/pos/cart_controller.dart';
import 'package:web_pos_mobile/features/pos/data/pos_models.dart';
import 'package:web_pos_mobile/features/pos/pos_providers.dart';

const _rice = Product(id: 1, name: 'Beras 5kg', unit: 'karung', price: 75000, trackStock: true, stock: 2);
const _soap = Product(id: 2, name: 'Sabun', unit: 'pcs', price: 4000, trackStock: false, stock: 0);

// Config never resolves, so the cart falls back to "negative stock not allowed" without touching the network.
List<Override> _overrides(SharedPreferences prefs) => [
      sharedPreferencesProvider.overrideWithValue(prefs),
      posConfigProvider.overrideWith((ref) => Completer<PosConfig>().future),
    ];

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: _overrides(prefs));
  addTearDown(container.dispose);

  return container;
}

void main() {
  test('adding beyond tracked stock is refused with a warning', () async {
    final container = await _container();
    final cart = container.read(cartProvider.notifier);

    expect(cart.add(_rice, quantity: 2), isNull);
    expect(cart.add(_rice), contains('tersisa 2'));
    expect(container.read(cartProvider).items.single.quantity, 2);
  });

  test('cart survives an app restart', () async {
    final container = await _container();
    container.read(cartProvider.notifier).add(_soap, quantity: 3);
    final uuid = container.read(cartProvider).clientUuid;

    final restarted = ProviderContainer(overrides: _overrides(await SharedPreferences.getInstance()));
    addTearDown(restarted.dispose);

    expect(restarted.read(cartProvider).clientUuid, uuid);
    expect(restarted.read(cartProvider).items.single.quantity, 3);
  });

  test('checkout rejections update prices, stock and drop unavailable products', () async {
    final container = await _container();
    final cart = container.read(cartProvider.notifier)
      ..add(_rice)
      ..add(_soap);

    cart.applyRejection(ApiException(message: '', reason: 'price_changed', context: {
      'prices': {
        '1': {'price': 80000, 'name': 'Beras 5kg'},
      },
    }));
    cart.applyRejection(ApiException(message: '', reason: 'insufficient_stock', context: {
      'stock': {'1': 0.5},
    }));
    cart.applyRejection(ApiException(message: '', reason: 'unavailable', context: {
      'product_ids': [2],
    }));

    final item = container.read(cartProvider).items.single;
    expect(item.productId, 1);
    expect(item.price, 80000);
    expect(item.stock, 0.5);
  });

  test('a resumed held order from the web cashier gets a fresh client_uuid', () async {
    final container = await _container();
    final before = container.read(cartProvider).clientUuid;

    container.read(cartProvider.notifier).load({
      'client_uuid': before,
      'items': [
        {'product_id': 2, 'name': 'Sabun', 'unit': 'pcs', 'price': 4000, 'quantity': 2, 'discount': 500, 'track': false, 'stock': 0},
      ],
      'customer': {'id': 7, 'name': 'Bu Rina'},
      'discountType': 'percent',
      'discountValue': 10,
    });

    final cart = container.read(cartProvider);
    expect(cart.clientUuid, isNot(before));
    expect(cart.customer?.id, 7);
    expect(cart.discountType, DiscountType.percent);
    expect(cart.items.single.total, 7500);
  });
}
