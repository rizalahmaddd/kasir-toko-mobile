import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_pos_mobile/core/network/api_exception.dart';
import 'package:web_pos_mobile/core/storage/app_storage.dart';
import 'package:web_pos_mobile/features/auth/auth_controller.dart';
import 'package:web_pos_mobile/features/auth/data/current_user.dart';
import 'package:web_pos_mobile/features/offline/catalog_snapshot.dart';
import 'package:web_pos_mobile/features/pos/cart_controller.dart';
import 'package:web_pos_mobile/features/pos/data/pos_models.dart';
import 'package:web_pos_mobile/features/pos/data/pos_repository.dart';
import 'package:web_pos_mobile/features/pos/pos_providers.dart';

final _paracetamol = Product.fromJson({
  'id': 7,
  'name': 'Paracetamol',
  'unit': 'tablet',
  'price': 500,
  'track_stock': true,
  'stock': '250.000',
  'requires_prescription': true,
  'units': [
    {'id': 11, 'name': 'strip', 'factor': '10.000', 'price': 5000, 'is_default_sale': false},
    {'id': 12, 'name': 'box', 'factor': '100.000', 'price': 45000, 'is_default_sale': true},
  ],
});

CurrentUser _user(Set<String> features) => CurrentUser(
      id: 1,
      name: 'Kasir',
      username: 'kasir',
      roles: const ['kasir'],
      permissions: const {'pos.sell'},
      isSuperadmin: false,
      enabledFeatures: features,
    );

Future<ProviderContainer> _container({Set<String> features = const {'business.multi-unit', 'business.prescription'}}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final List<Override> overrides = [
    sharedPreferencesProvider.overrideWithValue(prefs),
    posConfigProvider.overrideWith((ref) => Completer<PosConfig>().future),
    currentUserProvider.overrideWithValue(_user(features)),
  ];
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);

  return container;
}

void main() {
  test('a product is added in its default sale unit and stock is checked in the base unit', () async {
    final container = await _container();
    final cart = container.read(cartProvider.notifier);

    expect(cart.add(_paracetamol), isNull);
    expect(cart.add(_paracetamol, unitId: 11, quantity: 5), isNull);
    expect(cart.add(_paracetamol), isNull);
    expect(cart.add(_paracetamol, unitId: 11), contains('tersisa 250'));

    final items = container.read(cartProvider).items;
    expect(items.map((item) => item.key), ['7:11:', '7:12:']);
    expect(items.firstWhere((item) => item.unitId == 12).price, 45000);
    expect(items.fold<double>(0, (sum, item) => sum + item.baseQuantity), 250);
  });

  test('changing a line unit takes the new price and factor', () async {
    final container = await _container();
    final cart = container.read(cartProvider.notifier)..add(_paracetamol);
    final line = container.read(cartProvider).items.single;

    cart.updateItem(line.key, quantity: 3, discount: 0, unit: line.units.first, changeUnit: true);

    final updated = container.read(cartProvider).items.single;
    expect(updated.unit, 'strip');
    expect(updated.price, 5000);
    expect(updated.baseQuantity, 30);
  });

  test('units are ignored while multi-unit is off', () async {
    final container = await _container(features: const {});
    container.read(cartProvider.notifier).add(_paracetamol);

    final line = container.read(cartProvider).items.single;
    expect(line.unitId, isNull);
    expect(line.price, 500);
    expect(line.units, isEmpty);
  });

  test('checkout carries unit ids and the prescription, and rejections update unit prices', () async {
    final container = await _container();
    final cart = container.read(cartProvider.notifier)
      ..add(_paracetamol)
      ..setPrescription(const LinkedPrescription(id: 4, number: 'RSP-2026-00004', patient: 'Ani'));

    expect(container.read(cartProvider).needsPrescription, isTrue);

    final payload = PosRepository.checkoutPayload(cart: container.read(cartProvider), payments: const [], expectedTotal: 45000);
    expect((payload['items'] as List).single['unit_id'], 12);
    expect(payload['prescription_id'], 4);
    expect(payload.containsKey('prescription'), isFalse);

    cart.applyRejection(ApiException(message: '', reason: 'price_changed', context: {
      'prices': <String, dynamic>{},
      'unit_prices': {
        '12': {'price': 47000},
      },
    }));
    expect(container.read(cartProvider).items.single.price, 47000);

    cart.applyRejection(ApiException(message: '', reason: 'unit_unavailable', context: {
      'unit_ids': [12],
    }));
    final line = container.read(cartProvider).items.single;
    expect(line.unitId, isNull);
    expect(line.price, 500);
  });

  test('a typed prescription replaces a linked one and survives the held-order format', () async {
    final container = await _container();
    container.read(cartProvider.notifier)
      ..add(_paracetamol)
      ..setPrescription(const LinkedPrescription(id: 4, number: 'RSP-1', patient: 'Ani'))
      ..setPrescriptionDraft(const PrescriptionDraft(doctorName: 'Budi', patientName: 'Ani'));

    final json = container.read(cartProvider).toJson();
    final restored = Cart.fromJson(json, fallbackUuid: 'x');

    expect(restored.prescription, isNull);
    expect(restored.prescriptionDraft?.doctorName, 'Budi');
    expect(restored.items.single.units.length, 2);
    expect(restored.items.single.requiresPrescription, isTrue);
    expect(PosRepository.checkoutPayload(cart: restored, payments: const [], expectedTotal: 0)['prescription'], {'doctor_name': 'Budi', 'patient_name': 'Ani'});
  });

  test('the offline catalog finds a product by the barcode of one of its units', () {
    final snapshot = CatalogSnapshot(
      [
        {
          'id': 7,
          'name': 'Paracetamol',
          'unit': 'tablet',
          'price': 500,
          'units': [
            {'id': 12, 'name': 'box', 'factor': '100.000', 'price': 45000, 'barcode': 'BOX-1'},
          ],
        },
      ],
      DateTime(2026),
    );

    final product = snapshot.lookup('BOX-1');
    expect(product?.id, 7);
    expect(product?.matchedUnitId, 12);
  });
}
