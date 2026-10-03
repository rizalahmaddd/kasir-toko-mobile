import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_pos_mobile/core/offline/offline_cache.dart';
import 'package:web_pos_mobile/core/storage/app_storage.dart';
import 'package:web_pos_mobile/features/data_changes.dart';
import 'package:web_pos_mobile/features/offline/catalog_snapshot.dart';
import 'package:web_pos_mobile/features/sales/data/sale_models.dart';
import 'package:web_pos_mobile/features/sales/data/sales_repository.dart';
import 'package:web_pos_mobile/features/sales/sales_controller.dart';

class _MockSales extends Mock implements SalesRepository {}

class _MemoryCache extends OfflineCache {
  _MemoryCache(SharedPreferences prefs) : super(prefs, 'test');

  final files = <String, Object>{};

  @override
  Future<void> writeFile(String name, Object value) async => files[name] = value;

  @override
  Future<dynamic> readFile(String name) async => files[name];
}

void main() {
  late ProviderContainer container;
  late _MockSales sales;
  var listed = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final cache = _MemoryCache(prefs)
      ..files['catalog'] = {
        'products': [
          {'id': 1, 'name': 'Sabun', 'sku': 'S1', 'unit': 'pcs', 'price': 3000, 'track_stock': true, 'stock': '10'},
        ],
        'updated_at': DateTime(2026).toIso8601String(),
      };
    sales = _MockSales();
    listed = 0;
    when(
      () => sales.list(
        from: any(named: 'from'),
        to: any(named: 'to'),
        status: any(named: 'status'),
        search: any(named: 'search'),
        page: any(named: 'page'),
      ),
    ).thenAnswer((_) async => SalesPage(items: const [], hasMore: false, page: 1, count: ++listed, total: 0, voided: 0));

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        offlineCacheProvider.overrideWithValue(cache),
        salesRepositoryProvider.overrideWithValue(sales),
      ],
    );
    addTearDown(container.dispose);
  });

  test('a sale stored by the server reloads the transaction list that is already open', () async {
    container.listen(salesProvider, (_, _) {});
    expect((await container.read(salesProvider.future)).page.count, 1);

    await container.read(dataChangesProvider).saleRecorded({1: 2});

    expect((await container.read(salesProvider.future)).page.count, 2);
    expect(container.read(catalogSnapshotProvider).value!.search(term: 'sabun').items.single.stock, 8);
  });

  test('the offline catalog shows the new stock as soon as the deduction starts', () async {
    await container.read(catalogSnapshotProvider.future);

    final saving = container.read(catalogSnapshotProvider.notifier).deduct({1: 3});

    expect(container.read(catalogSnapshotProvider).value!.search(term: 'sabun').items.single.stock, 7);
    await saving;
  });
}
