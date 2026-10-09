import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_pos_mobile/core/network/api_exception.dart';
import 'package:web_pos_mobile/core/storage/app_storage.dart';
import 'package:web_pos_mobile/features/auth/auth_controller.dart';
import 'package:web_pos_mobile/features/auth/data/current_user.dart';
import 'package:web_pos_mobile/features/stock_count/count_queue.dart';
import 'package:web_pos_mobile/features/stock_count/data/stock_count_models.dart';
import 'package:web_pos_mobile/features/stock_count/data/stock_count_repository.dart';
import 'package:web_pos_mobile/features/stock_count/stock_count_providers.dart';

class _MockRepository extends Mock implements StockCountRepository {}

const _counter = CurrentUser(id: 7, name: 'Penghitung', username: 'staf', roles: ['staff'], permissions: {'inventory.opname.count'}, isSuperadmin: false, enabledFeatures: {});

const _item = CountCatalogItem(itemId: 1, productId: 10, name: 'Indomie Goreng', unit: 'pcs', units: [CountUnit(id: 3, name: 'dus', factor: 40)]);

QueuedCount _entry(int countId, {double quantity = 1}) => countEntry(countId: countId, userId: 7, item: _item, lines: {null: quantity});

Future<(ProviderContainer, _MockRepository)> _container() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repository = _MockRepository();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      stockCountRepositoryProvider.overrideWithValue(repository),
      currentUserProvider.overrideWithValue(_counter),
    ],
  );
  addTearDown(container.dispose);

  return (container, repository);
}

List<Map<String, dynamic>> _results(Invocation invocation, String Function(int index) status, {String? reason}) {
  final entries = invocation.positionalArguments[1] as List<Map<String, dynamic>>;
  return [
    for (var index = 0; index < entries.length; index++)
      {'client_uuid': entries[index]['client_uuid'], 'status': status(index), 'reason': ?reason, 'entry_id': 100 + index},
  ];
}

void main() {
  setUpAll(() => registerFallbackValue(DateTime(2026)));

  test('queued counts are sent per document and removed once saved', () async {
    final (container, repository) = await _container();
    final sent = <int>[];
    when(() => repository.sendEntries(any(), any(), any())).thenAnswer((invocation) async {
      sent.add(invocation.positionalArguments.first as int);
      return _results(invocation, (_) => 'saved');
    });
    final queue = container.read(countQueueProvider.notifier)
      ..add(_entry(1))
      ..add(_entry(1, quantity: 3))
      ..add(_entry(2));

    expect(await queue.sync(), 3);
    expect(sent, [1, 2]);
    expect(container.read(countQueueProvider).pending, isEmpty);
    expect(container.read(countQueueProvider).sentEntryIds, hasLength(3));
  });

  test('a network failure keeps everything queued for the next try and survives a restart', () async {
    final (container, repository) = await _container();
    when(() => repository.sendEntries(any(), any(), any())).thenThrow(ApiException(message: 'offline', isNetworkError: true));
    container.read(countQueueProvider.notifier)
      ..add(_entry(1))
      ..add(_entry(1));

    expect(await container.read(countQueueProvider.notifier).sync(), 0);
    expect(container.read(countQueueProvider).pending, hasLength(2));

    final restarted = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance())]);
    addTearDown(restarted.dispose);
    expect(restarted.read(countQueueProvider).pending.map((item) => item.label), everyElement(contains('Indomie Goreng')));
  });

  test('counts for a closed document are moved aside and other rejections are marked failed', () async {
    final (container, repository) = await _container();
    when(() => repository.sendEntries(1, any(), any())).thenAnswer((invocation) async => _results(invocation, (_) => 'rejected', reason: 'stock_count_closed'));
    when(() => repository.sendEntries(2, any(), any())).thenAnswer((invocation) async => [
          {'client_uuid': (invocation.positionalArguments[1] as List<Map<String, dynamic>>).first['client_uuid'], 'status': 'rejected', 'reason': 'batch_not_found', 'error': 'Batch tidak ditemukan.'},
        ]);
    container.read(countQueueProvider.notifier)
      ..add(_entry(1))
      ..add(_entry(2));

    await container.read(countQueueProvider.notifier).sync();
    final state = container.read(countQueueProvider);

    expect(state.closedFor(1), hasLength(1));
    expect(state.pendingFor(1), isEmpty);
    expect(state.pendingFor(2).single.failed, isTrue);
    expect(state.pendingFor(2).single.error, 'Batch tidak ditemukan.');
    expect(await container.read(countQueueProvider.notifier).sync(), 0, reason: 'failed counts wait until retried on purpose');

    container.read(countQueueProvider.notifier).discardClosed(1);
    expect(container.read(countQueueProvider).closed, isEmpty);
  });

  test('a duplicate answer from the server counts as sent', () async {
    final (container, repository) = await _container();
    when(() => repository.sendEntries(any(), any(), any())).thenAnswer((invocation) async => _results(invocation, (_) => 'duplicate'));
    container.read(countQueueProvider.notifier).add(_entry(1));

    expect(await container.read(countQueueProvider.notifier).sync(), 1);
    expect(container.read(countQueueProvider).pending, isEmpty);
  });

  test('serial scans are sent separately and keep their match result', () async {
    final (container, repository) = await _container();
    when(() => repository.sendSerials(any(), any(), any())).thenAnswer((invocation) async {
      final serials = invocation.positionalArguments[1] as List<Map<String, dynamic>>;
      return [for (final serial in serials) {'client_uuid': serial['client_uuid'], 'status': 'saved', 'result': 'matched'}];
    });
    final scan = serialScan(countId: 1, userId: 7, serial: 'imei-1', productId: 10);
    container.read(countQueueProvider.notifier).add(scan);

    expect(scan.payload['serial'], 'IMEI-1');
    expect(await container.read(countQueueProvider.notifier).sync(), 1);
    expect(container.read(countQueueProvider).serialResults[scan.clientUuid], 'matched');
    verifyNever(() => repository.sendEntries(any(), any(), any()));
  });

  test('a queued count is sent for the outlet it was counted at, even after switching outlet', () async {
    final (container, repository) = await _container();
    int? sentFor;
    when(() => repository.sendEntries(any(), any(), any(), outletId: any(named: 'outletId'))).thenAnswer((invocation) async {
      sentFor = invocation.namedArguments[#outletId] as int?;
      return _results(invocation, (_) => 'saved');
    });
    final entry = countEntry(countId: 1, userId: 7, item: _item, lines: {null: 2}, outletId: 3);
    container.read(countQueueProvider.notifier).add(entry);

    final restarted = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance())]);
    addTearDown(restarted.dispose);
    expect(restarted.read(countQueueProvider).pending.single.outletId, 3);

    await container.read(countQueueProvider.notifier).sync();
    expect(sentFor, 3);
  });

  test('an unsent count can be taken back without the server', () async {
    final (container, _) = await _container();
    final entry = _entry(1);
    container.read(countQueueProvider.notifier).add(entry);

    expect(container.read(countQueueProvider.notifier).removePending(entry.clientUuid), isTrue);
    expect(container.read(countQueueProvider.notifier).removePending(entry.clientUuid), isFalse);
  });
}
