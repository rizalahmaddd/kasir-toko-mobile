import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_pos_mobile/core/network/api_exception.dart';
import 'package:web_pos_mobile/core/storage/app_storage.dart';
import 'package:web_pos_mobile/features/auth/auth_controller.dart';
import 'package:web_pos_mobile/features/auth/data/current_user.dart';
import 'package:web_pos_mobile/features/offline/catalog_snapshot.dart';
import 'package:web_pos_mobile/features/offline/offline_queue.dart';
import 'package:web_pos_mobile/features/pos/data/pos_repository.dart';
import 'package:web_pos_mobile/features/sales/data/sale_models.dart';

class _MockRepository extends Mock implements PosRepository {}

const _cashier = CurrentUser(id: 7, name: 'Kasir', username: 'kasir', roles: ['kasir'], permissions: {'pos.sell'}, isSuperadmin: false, enabledFeatures: {});

Map<String, dynamic> _product(int id, String name, {String? barcode, int? category, num stock = 10, bool track = true}) => {
      'id': id,
      'name': name,
      'sku': 'BRG-$id',
      'barcode': barcode,
      'unit': 'pcs',
      'price': 1000 * id,
      'track_stock': track,
      'stock': '$stock',
      'category': category == null ? null : {'id': category, 'name': 'Kategori $category'},
    };

QueuedSale _queued(String uuid, {int userId = 7}) => QueuedSale(
      payload: {'client_uuid': uuid, 'items': const []},
      cart: const {},
      userId: userId,
      total: 5000,
      paid: 10000,
      itemCount: 1,
      createdAt: DateTime(2026, 10, 1, 10),
    );

final _sale = SaleDetail.fromJson({
  'id': 1,
  'number': 'TRX-1',
  'status': 'completed',
  'status_label': 'Selesai',
  'sold_at': '2026-10-01T10:00:00+07:00',
  'total': 5000,
  'items': const [],
  'payments': const [],
});

Future<(ProviderContainer, _MockRepository)> _container() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repository = _MockRepository();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      posRepositoryProvider.overrideWithValue(repository),
      currentUserProvider.overrideWithValue(_cashier),
    ],
  );
  addTearDown(container.dispose);

  return (container, repository);
}

void main() {
  group('catalog snapshot', () {
    final snapshot = CatalogSnapshot([
      _product(1, 'Air Mineral 600ml', barcode: '899001', category: 1),
      _product(2, 'Beras Premium 5kg', category: 2),
      _product(3, 'Air Galon', category: 1, track: false),
    ], DateTime(2026, 10, 1));

    test('searches by name, SKU, exact barcode and category', () {
      expect(snapshot.search(term: 'air').items.map((p) => p.id), [1, 3]);
      expect(snapshot.search(term: 'brg-2').items.single.id, 2);
      expect(snapshot.search(term: '899001').items.single.id, 1);
      expect(snapshot.search(term: '8990').items, isEmpty);
      expect(snapshot.search(categoryId: 2).items.single.name, 'Beras Premium 5kg');
    });

    test('pages results like the API', () {
      final big = CatalogSnapshot([for (var i = 1; i <= 100; i++) _product(i, 'Produk $i')], DateTime(2026));

      expect(big.search(page: 1).items, hasLength(CatalogSnapshot.pageSize));
      expect(big.search(page: 1).hasMore, isTrue);
      expect(big.search(page: 3).items, hasLength(100 - 2 * CatalogSnapshot.pageSize));
      expect(big.search(page: 3).hasMore, isFalse);
    });

    test('looks up barcode first, then SKU', () {
      expect(snapshot.lookup('899001')?.id, 1);
      expect(snapshot.lookup('BRG-2')?.id, 2);
      expect(snapshot.lookup('nope'), isNull);
    });

    test('deducting an offline sale only touches tracked stock', () {
      final after = snapshot.deduct({1: 3, 3: 2});

      expect(after.search(term: '899001').items.single.stock, 7);
      expect(after.search(term: 'galon').items.single.stock, 10);
    });
  });

  group('offline queue', () {
    test('sync sends pending sales in order and drops the ones the server stored', () async {
      final (container, repository) = await _container();
      final sent = <String>[];
      when(() => repository.submitCheckout(any())).thenAnswer((invocation) async {
        sent.add((invocation.positionalArguments.first as Map<String, dynamic>)['client_uuid'] as String);
        return _sale;
      });
      container.read(offlineQueueProvider.notifier)
        ..add(_queued('a'))
        ..add(_queued('b'));

      expect(await container.read(offlineQueueProvider.notifier).sync(), 2);
      expect(sent, ['a', 'b']);
      expect(container.read(offlineQueueProvider), isEmpty);
    });

    test('a network failure stops the run and keeps everything queued', () async {
      final (container, repository) = await _container();
      when(() => repository.submitCheckout(any())).thenThrow(ApiException(message: 'offline', isNetworkError: true));
      container.read(offlineQueueProvider.notifier)
        ..add(_queued('a'))
        ..add(_queued('b'));

      expect(await container.read(offlineQueueProvider.notifier).sync(), 0);
      verify(() => repository.submitCheckout(any())).called(1);
      expect(container.read(offlineQueueProvider).map((s) => s.status), [QueuedStatus.pending, QueuedStatus.pending]);
    });

    test('a business rejection marks that sale failed and continues', () async {
      final (container, repository) = await _container();
      when(() => repository.submitCheckout(any())).thenAnswer((invocation) async {
        final uuid = (invocation.positionalArguments.first as Map<String, dynamic>)['client_uuid'];
        if (uuid == 'a') {
          throw ApiException(message: 'Harga berubah', statusCode: 422, reason: 'price_changed');
        }
        return _sale;
      });
      container.read(offlineQueueProvider.notifier)
        ..add(_queued('a'))
        ..add(_queued('b'));

      expect(await container.read(offlineQueueProvider.notifier).sync(), 1);
      final left = container.read(offlineQueueProvider).single;
      expect(left.clientUuid, 'a');
      expect(left.status, QueuedStatus.failed);
      expect(left.error, 'Harga berubah');

      expect(await container.read(offlineQueueProvider.notifier).sync(), 0, reason: 'failed sales wait for the cashier');
    });

    test('another cashier\'s sales are left alone and the queue survives restarts', () async {
      final (container, repository) = await _container();
      when(() => repository.submitCheckout(any())).thenAnswer((_) async => _sale);
      container.read(offlineQueueProvider.notifier)
        ..add(_queued('mine'))
        ..add(_queued('theirs', userId: 99));

      expect(container.read(myQueueProvider).map((s) => s.clientUuid), ['mine']);
      await container.read(offlineQueueProvider.notifier).sync();

      final restarted = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance())]);
      addTearDown(restarted.dispose);
      expect(restarted.read(offlineQueueProvider).single.clientUuid, 'theirs');
    });
  });
}
