import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_pos_mobile/core/network/api_exception.dart';
import 'package:web_pos_mobile/core/storage/app_storage.dart';
import 'package:web_pos_mobile/features/kitchen/data/kitchen_models.dart';
import 'package:web_pos_mobile/features/modifiers/data/modifier_groups_repository.dart';
import 'package:web_pos_mobile/features/orders/data/order_models.dart';
import 'package:web_pos_mobile/features/pos/cart_controller.dart';
import 'package:web_pos_mobile/features/pos/data/pos_models.dart';
import 'package:web_pos_mobile/features/pos/data/pos_repository.dart';
import 'package:web_pos_mobile/features/pos/pos_providers.dart';
import 'package:web_pos_mobile/features/printing/receipt_layout.dart';
import 'package:web_pos_mobile/features/sales/data/sale_models.dart';

const _config = PosConfig(
  taxRate: 0,
  taxLabel: 'PPN',
  allowNegativeStock: false,
  allowCredit: false,
  canDiscount: true,
  receiptWidth: '58',
  quickCash: [],
  paymentMethods: [],
  qrisEnabled: false,
  hasOpenShift: true,
  heldOrdersCount: 0,
  variantsEnabled: true,
  serialsEnabled: true,
  preOrderEnabled: true,
);

final _shirt = Product.fromJson({
  'id': 20,
  'name': 'Kaos Polos',
  'unit': 'pcs',
  'price': 65000,
  'track_stock': false,
  'stock': '0.000',
  'variants': [
    {'id': 21, 'name': 'Kaos Polos - M / Hitam', 'label': 'M / Hitam', 'sku': 'PRD-1', 'price': 65000, 'stock': '4.000', 'track_stock': true},
  ],
});

final _phone = Product.fromJson({'id': 30, 'name': 'HP Android', 'unit': 'unit', 'price': 2000000, 'track_stock': true, 'stock': '3.000', 'track_serial': true});

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    posConfigProvider.overrideWith((ref) => Future.value(_config)),
  ]);
  addTearDown(container.dispose);
  await container.read(posConfigProvider.future);

  return container;
}

void main() {
  test('a variant becomes its own cart product with the child id, price, and stock', () {
    final child = _shirt.variantProduct(_shirt.variants.single);

    expect(child.id, 21);
    expect(child.stock, 4);
    expect(child.variantLabel, 'M / Hitam');
    expect(child.variants, isEmpty);
  });

  test('serial units set the quantity and travel with the checkout', () async {
    final container = await _container();
    final cart = container.read(cartProvider.notifier);

    cart.add(_phone, serials: const ['IMEI-1', 'IMEI-2']);
    var line = container.read(cartProvider).items.single;
    expect(line.quantity, 2);
    expect(line.needsSerials, isFalse);
    expect(line.toCheckoutJson()['serials'], ['IMEI-1', 'IMEI-2']);

    cart.add(_phone, serials: const ['IMEI-3']);
    expect(container.read(cartProvider).items.single.quantity, 3);

    expect(cart.setSerials(line.key, const ['A', 'B', 'C', 'D']), isNotNull);

    cart.setQuantity(line.key, 1);
    line = container.read(cartProvider).items.single;
    expect(line.serials, ['IMEI-1']);

    cart.applyRejection(ApiException(message: 'x', statusCode: 422, reason: 'serial_unavailable', context: {'serials': ['IMEI-1']}));
    expect(container.read(cartProvider).items.single.needsSerials, isTrue);
  });

  test('settling an order deducts its deposit and sends the order id', () async {
    final container = await _container();
    final cake = Product.fromJson({'id': 40, 'name': 'Kue', 'unit': 'pcs', 'price': 250000, 'track_stock': false, 'stock': '0'});

    container.read(cartProvider.notifier).loadOrder(const LinkedOrder(id: 7, number: 'PSN-00007', deposit: 100000), [(product: cake, quantity: 1, note: 'Tulisan ulang tahun')]);
    final cart = container.read(cartProvider);

    expect(cart.amountDue(_config), 150000);
    expect(cart.items.single.note, 'Tulisan ulang tahun');
    expect(PosRepository.checkoutPayload(cart: cart, payments: const [], expectedTotal: 250000, config: _config)['customer_order_id'], 7);

    final restored = Cart.fromJson(cart.toJson(), fallbackUuid: 'x');
    expect(restored.customerOrder?.number, 'PSN-00007');
  });

  test('order cart, order, and sale detail payloads are parsed', () {
    final orderCart = OrderCart.fromJson({
      'customer_order_id': 7,
      'number': 'PSN-00007',
      'deposit': 100000,
      'customer': {'id': 3, 'name': 'Bu Rina'},
      'items': [
        {'product_id': 40, 'quantity': 1, 'note': null},
      ],
      'skipped': ['Lilin'],
    });
    expect(orderCart.items.single.productId, 40);
    expect(orderCart.skipped, ['Lilin']);

    final order = CustomerOrder.fromJson({'id': 7, 'number': 'SRV-00001', 'type': 'service', 'status': 'ready', 'status_label': 'Siap Diambil', 'customer_name': 'Pak Andi', 'estimated_total': 0, 'deposit': 50000, 'remaining': 0});
    expect(order.isService, isTrue);
    expect(order.isOpen, isTrue);

    final sale = SaleDetail.fromJson({
      'id': 1,
      'number': 'TRX-1',
      'status': 'completed',
      'status_label': 'Selesai',
      'sold_at': '2026-10-06T10:00:00+07:00',
      'cashier': {'name': 'Kasir'},
      'subtotal': 0,
      'discount_amount': 0,
      'tax_rate': '0',
      'tax_amount': 0,
      'total': 0,
      'paid_amount': 0,
      'cash_received': 0,
      'change_amount': 0,
      'due_amount': 0,
      'service_charge_rate': '5.00',
      'service_charge_amount': 2800,
      'order_type_label': 'Makan di Tempat',
      'table_label': '5',
      'items': [
        {'product_name': 'HP', 'unit': 'unit', 'quantity': '1.000', 'price': 1, 'discount_amount': 0, 'total': 1, 'serials': ['IMEI-1'], 'modifiers': [{'id': 1, 'name': 'Large', 'price': 5000}]},
      ],
      'payments': [],
      'delivery_notes': [
        {'id': 9, 'number': 'SJ-1', 'recipient': 'Pak Budi', 'address': 'Jl. Melati', 'status': 'delivered'},
      ],
      'abilities': {'void': false},
    });
    expect(sale.orderLabel, 'Makan di Tempat · Meja 5');
    expect(sale.items.single.serials, ['IMEI-1']);
    expect(sale.items.single.modifiers, ['Large']);
    expect(sale.deliveryNotes.single.isDelivered, isTrue);
  });

  test('a customer credit limit leaves only the remaining room for new credit', () {
    final limited = CustomerOption.fromJson({'id': 1, 'name': 'Pak Tukang', 'due': 400000, 'credit_limit': 500000});
    const unlimited = CustomerOption(id: 2, name: 'Bu Warung', due: 900000);

    expect(limited.creditRoom, 100000);
    expect(unlimited.creditRoom, isNull);
    expect(CustomerOption.fromJson({'id': 3, 'name': 'Lewat', 'due': 700000, 'credit_limit': 500000}).creditRoom, 0);
  });

  test('a modifier group keeps its ingredient settings when sent back from the app', () {
    final group = ModifierGroupRecord.fromJson({
      'id': 4,
      'name': 'Tambahan Kopi',
      'min_select': 0,
      'max_select': null,
      'rule': 'Opsional',
      'is_active': true,
      'products_count': 2,
      'options': [
        {'id': 9, 'name': 'Extra Shot', 'price': 6000, 'product_id': 30, 'ingredient_quantity': '18.000', 'is_active': true},
      ],
      'products': [
        {'id': 3, 'name': 'Latte'},
      ],
    });

    expect(group.maxSelect, isNull);
    expect(group.products.single.name, 'Latte');
    expect(group.options.single.toJson(), {'id': 9, 'name': 'Extra Shot', 'price': 6000, 'product_id': 30, 'ingredient_quantity': '18.000', 'is_active': true});
  });

  test('kitchen tickets and delivery notes print without prices', () async {
    await initializeDateFormatting('id_ID');
    final ticket = KitchenTicket.fromJson({
      'id': 1,
      'label': 'Meja 5',
      'order_type_label': 'Makan di Tempat',
      'status': 'pending',
      'items': [
        {'name': 'Latte', 'quantity': 2, 'unit': 'cup', 'modifiers': ['Large'], 'note': 'Less ice'},
      ],
      'created_at': '2026-10-08T10:00:00+07:00',
    });
    final kitchen = kitchenTicketLines(ticket, paperWidth: '58').map((l) => l.text).join('\n');
    expect(kitchen, contains('2x Latte'));
    expect(kitchen, contains('+ Large'));
    expect(kitchen, contains('! Less ice'));
    expect(kitchen, isNot(contains('Rp')));

    final sale = SaleDetail.fromJson({
      'id': 1, 'number': 'TRX-9', 'status': 'completed', 'status_label': 'Selesai', 'sold_at': '2026-10-08T10:00:00+07:00', 'cashier': {'name': 'Kasir'},
      'subtotal': 650000, 'discount_amount': 0, 'tax_rate': '0', 'tax_amount': 0, 'total': 650000, 'paid_amount': 650000, 'cash_received': 0, 'change_amount': 0, 'due_amount': 0,
      'items': [
        {'product_name': 'Semen 50kg', 'unit': 'sak', 'quantity': '10.000', 'price': 65000, 'discount_amount': 0, 'total': 650000},
      ],
      'payments': [], 'abilities': <String, dynamic>{},
    });
    const note = DeliveryNoteInfo(id: 1, number: 'SJ-00001', recipient: 'Pak Budi', address: 'Jl. Melati 5', status: 'sent', driver: 'Joko');
    const profile = ReceiptProfile(storeName: 'Toko Bangunan', outletName: '', address: '', phone: '', header: '', footer: '', taxLabel: 'PPN', paperWidth: '58');
    final printed = deliveryNoteLines(sale, note, profile: profile, paperWidth: '58').map((l) => l.text).join('\n');
    expect(printed, contains('SURAT JALAN'));
    expect(printed, contains('Semen 50kg'));
    expect(printed, contains('Kepada: Pak Budi'));
    expect(printed, isNot(contains('65.000')));
  });

  test('near-expiry units are discounted across lines of the same product', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      posConfigProvider.overrideWith((ref) => Future.value(const PosConfig(
            taxRate: 0, taxLabel: 'PPN', allowNegativeStock: true, allowCredit: false, canDiscount: true, receiptWidth: '58', quickCash: [],
            paymentMethods: [], qrisEnabled: false, hasOpenShift: true, heldOrdersCount: 0, nearExpiryDiscountPercent: 30,
          ))),
    ]);
    addTearDown(container.dispose);
    await container.read(posConfigProvider.future);
    final bread = Product.fromJson({'id': 50, 'name': 'Roti', 'unit': 'pcs', 'price': 12000, 'track_stock': true, 'stock': '12', 'near_expiry_quantity': '2.000'});

    container.read(cartProvider.notifier).add(bread, quantity: 3);
    final line = container.read(cartProvider).items.single;

    expect(line.autoDiscount, 7200);
    expect(line.total, 28800);
    expect(line.toCheckoutJson()['auto_discount'], 7200);
    expect(line.toCheckoutJson()['discount'], 0);
  });
}
