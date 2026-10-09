import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_pos_mobile/features/stock_count/data/stock_count_models.dart';
import 'package:web_pos_mobile/features/stock_count/stock_count_providers.dart';

const _units = [CountUnit(id: 3, name: 'dus', factor: 40, barcode: 'DUS-1'), CountUnit(id: 4, name: 'pak', factor: 5)];
const _noodle = CountCatalogItem(itemId: 1, productId: 10, name: 'Indomie Goreng', unit: 'pcs', sku: 'IDM-1', barcode: '8991', units: _units);
const _phone = CountCatalogItem(itemId: 2, productId: 11, name: 'HP Android', unit: 'unit', barcode: '8992', trackSerial: true);

void main() {
  test('quantities per unit add up to the base unit', () {
    expect(baseQuantity({3: 2, 4: 5, null: 3}, _units), 108);
    expect(baseQuantity({null: 1.255}, _units), 1.255);
  });

  test('one unit is sent as quantity and unit, several as a breakdown', () {
    final single = countEntry(countId: 1, userId: 7, item: _noodle, lines: {3: 1});
    final mixed = countEntry(countId: 1, userId: 7, item: _noodle, lines: {3: 2, null: 3}, note: ' rak depan ');

    expect(single.payload['quantity'], 1);
    expect(single.payload['unit_id'], 3);
    expect(single.payload.containsKey('breakdown'), isFalse);
    expect(single.label, 'Indomie Goreng · 1 dus');
    expect(mixed.payload['breakdown'], [
      {'unit_id': 3, 'quantity': 2.0},
      {'unit_id': null, 'quantity': 3.0},
    ]);
    expect(mixed.payload['note'], 'rak depan');
    expect(mixed.label, 'Indomie Goreng · 2 dus + 3 pcs');
    expect(single.clientUuid, isNot(mixed.clientUuid));
  });

  test('a new batch travels with its number and expiry', () {
    final entry = countEntry(countId: 1, userId: 7, item: _noodle, lines: {null: 4}, newBatchNumber: ' B-9 ', newBatchExpiry: '2027-01-31');

    expect(entry.payload['new_batch'], {'number': 'B-9', 'expires_at': '2027-01-31'});
    expect(entry.payload.containsKey('product_batch_id'), isFalse);
  });

  test('products in a running count get its number; an all-products count covers everything', () async {
    final picked = ProviderContainer(overrides: [
      openStockCountsProvider.overrideWith((ref) async => [_doc(1, 'products')]),
      countCatalogProvider(1).overrideWith((ref) async => CountCatalog([_noodle])),
    ]);
    addTearDown(picked.dispose);
    final everything = ProviderContainer(overrides: [openStockCountsProvider.overrideWith((ref) async => [_doc(2, 'all')])]);
    addTearDown(everything.dispose);

    expect(await picked.read(countingProductsProvider.future), {10: 'OPN-1'});
    expect(await everything.read(countingProductsProvider.future), {null: 'OPN-2'});
  });

  test('a scanned barcode finds the product and the unit it belongs to', () {
    final catalog = CountCatalog([_noodle, _phone]);

    expect(catalog.find('8991')!.$2, isNull);
    expect(catalog.find('DUS-1')!.$2!.factor, 40);
    expect(catalog.find('IDM-1')!.$1.productId, 10);
    expect(catalog.find('8992')!.$1.trackSerial, isTrue);
    expect(catalog.find('nope'), isNull);
    expect(catalog.search('indomie').single.productId, 10);
  });
}

StockCountDoc _doc(int id, String scope) => StockCountDoc(
      id: id,
      number: 'OPN-$id',
      status: StockCountStatuses.counting,
      statusLabel: 'Sedang dihitung',
      scope: scope,
      scopeLabel: scope,
      canSeeSystem: true,
      canManage: true,
      holdAdjustments: false,
    );
