import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_pos_mobile/core/network/api_exception.dart';
import 'package:web_pos_mobile/core/storage/app_storage.dart';
import 'package:web_pos_mobile/features/pos/cart_controller.dart';
import 'package:web_pos_mobile/features/pos/data/pos_models.dart';
import 'package:web_pos_mobile/features/pos/data/pos_repository.dart';
import 'package:web_pos_mobile/features/pos/pos_providers.dart';

const _config = PosConfig(
  taxRate: 10,
  taxLabel: 'PB1',
  allowNegativeStock: true,
  allowCredit: false,
  canDiscount: true,
  receiptWidth: '58',
  quickCash: [],
  paymentMethods: [],
  qrisEnabled: false,
  hasOpenShift: true,
  heldOrdersCount: 0,
  serviceChargeRate: 5,
  serviceChargeDineInOnly: true,
  orderTypeEnabled: true,
  modifiersEnabled: true,
  tieredPriceEnabled: true,
);

final _latte = Product.fromJson({
  'id': 3,
  'name': 'Latte',
  'unit': 'cup',
  'price': 28000,
  'track_stock': false,
  'stock': '0.000',
  'modifier_groups': [
    {
      'id': 1,
      'name': 'Ukuran',
      'min': 1,
      'max': 1,
      'rule': 'Wajib, pilih 1',
      'modifiers': [
        {'id': 10, 'name': 'Regular', 'price': 0},
        {'id': 11, 'name': 'Large', 'price': 5000},
      ],
    },
  ],
});

final _water = Product.fromJson({
  'id': 4,
  'name': 'Air Mineral',
  'unit': 'btl',
  'price': 4000,
  'track_stock': false,
  'stock': '0.000',
  'price_tiers': [
    {'min_quantity': '12.000', 'price': 3500},
  ],
});

const _large = SelectedModifier(id: 11, name: 'Large', price: 5000, group: 'Ukuran');

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs), posConfigProvider.overrideWith((ref) => Future.value(_config))],
  );
  addTearDown(container.dispose);
  await container.read(posConfigProvider.future);

  return container;
}

void main() {
  test('lines with different modifiers stay apart and their prices are part of the line total', () async {
    final container = await _container();
    final cart = container.read(cartProvider.notifier);

    cart.add(_latte, modifiers: const [_large]);
    cart.add(_latte, modifiers: const [_large]);
    cart.add(_latte, modifiers: const [SelectedModifier(id: 10, name: 'Regular', price: 0)]);

    final items = container.read(cartProvider).items;
    expect(items, hasLength(2));
    expect(items.firstWhere((i) => i.modifiers.first.id == 11).total, 66000);
    expect(items.firstWhere((i) => i.modifiers.first.id == 11).toCheckoutJson()['modifiers'], [
      {'id': 11, 'name': 'Large', 'price': 5000},
    ]);
  });

  test('tier prices follow the total base quantity across lines', () async {
    final container = await _container();
    final cart = container.read(cartProvider.notifier);

    cart.add(_water, quantity: 10);
    expect(container.read(cartProvider).items.single.unitPrice, 4000);

    cart.add(_water, quantity: 2);
    final line = container.read(cartProvider).items.single;
    expect(line.unitPrice, 3500);
    expect(line.isTiered, isTrue);
    expect(line.toCheckoutJson()['price'], 3500);
  });

  test('dine-in pays service charge and the checkout payload carries the order and kitchen state', () async {
    final container = await _container();
    final cart = container.read(cartProvider.notifier);

    cart.add(_latte, quantity: 2, modifiers: const [_large]);
    cart.setTable('5');
    var state = container.read(cartProvider);
    final dineIn = state.totalsFor(_config);

    expect(dineIn.serviceAmount, 3300);
    expect(dineIn.taxAmount, 6930);
    expect(dineIn.total, 76230);

    cart.setOrderType(OrderTypes.takeAway);
    state = container.read(cartProvider);
    expect(state.totalsFor(_config).serviceAmount, 0);
    expect(state.table, isNull);

    cart.setOrderType(OrderTypes.dineIn);
    cart.setTable('5');
    cart.load({
      ...container.read(cartProvider).toJson(),
      'kitchenSent': {'3:0:11:': 1},
    });
    final payload = PosRepository.checkoutPayload(cart: container.read(cartProvider), payments: const [], expectedTotal: 0, config: _config);
    expect(payload['order_type'], OrderTypes.dineIn);
    expect(payload['table_label'], '5');
    expect(payload['kitchen_sent'], {'3:0:11:': 1.0});
    expect(container.read(cartProvider).items.single.signature, '3:0:11:');
  });

  test('server rejections update modifier prices, drop deleted modifiers, and restore tiered base prices', () async {
    final container = await _container();
    final cart = container.read(cartProvider.notifier);
    cart.add(_latte, modifiers: const [_large]);
    cart.add(_water, quantity: 12);

    cart.applyRejection(
      ApiException(
        message: 'x',
        statusCode: 422,
        reason: 'price_changed',
        context: {
          'prices': {
            '4': {
              'price': 3000,
              'base_price': 3800,
              'tiers': [
                {'min_quantity': '12.000', 'price': 3000},
              ],
            },
          },
          'modifier_prices': {
            '11': {'price': 6000},
          },
        },
      ),
    );

    var items = container.read(cartProvider).items;
    expect(items.firstWhere((i) => i.productId == 3).modifiersTotal, 6000);
    expect(items.firstWhere((i) => i.productId == 4).unitPrice, 3000);

    cart.applyRejection(
      ApiException(
        message: 'x',
        statusCode: 422,
        reason: 'modifier_unavailable',
        context: {
          'modifier_ids': [11],
        },
      ),
    );
    items = container.read(cartProvider).items;
    expect(items.firstWhere((i) => i.productId == 3).modifiers, isEmpty);
  });
}
