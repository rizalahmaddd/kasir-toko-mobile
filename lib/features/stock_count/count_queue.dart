import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/storage/app_storage.dart';
import '../../core/utils/json.dart';
import '../auth/auth_controller.dart';
import 'data/stock_count_repository.dart';

enum CountKind { entry, serial }

/// Hitungan yang dicatat di HP dan menunggu terkirim. client_uuid dibuat di HP, jadi kiriman ulang
/// (koneksi putus di tengah, aplikasi ditutup) tidak membuat hitungan dobel di server.
class QueuedCount {
  const QueuedCount({
    required this.kind,
    required this.countId,
    required this.clientUuid,
    required this.userId,
    required this.payload,
    required this.label,
    required this.createdAt,
    this.outletId,
    this.failed = false,
    this.error,
  });

  factory QueuedCount.fromJson(Map<String, dynamic> json) => QueuedCount(
        kind: json['kind'] == CountKind.serial.name ? CountKind.serial : CountKind.entry,
        countId: asInt(json['count_id']),
        clientUuid: json['client_uuid'] as String,
        userId: asInt(json['user_id']),
        payload: asMap(json['payload']),
        label: json['label'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
        outletId: json['outlet_id'] as int?,
        failed: json['failed'] == true,
        error: json['error'] as String?,
      );

  final CountKind kind;
  final int countId;
  final String clientUuid;
  final int userId;
  final Map<String, dynamic> payload;

  /// Teks untuk daftar di HP, mis. "Indomie Goreng · 2 dus".
  final String label;
  final DateTime createdAt;

  /// Outlet aktif saat dihitung; antrean dikirim atas nama outlet itu walau pengguna sudah berganti outlet.
  final int? outletId;
  final bool failed;
  final String? error;

  QueuedCount failedWith(String message) => QueuedCount(
        kind: kind,
        countId: countId,
        clientUuid: clientUuid,
        userId: userId,
        payload: payload,
        label: label,
        createdAt: createdAt,
        outletId: outletId,
        failed: true,
        error: message,
      );

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'count_id': countId,
        'client_uuid': clientUuid,
        'user_id': userId,
        'payload': payload,
        'label': label,
        'created_at': createdAt.toIso8601String(),
        'outlet_id': outletId,
        'failed': failed,
        'error': error,
      };
}

class CountQueueState {
  const CountQueueState({this.pending = const [], this.closed = const [], this.sentEntryIds = const {}, this.serialResults = const {}, this.syncing = false});

  final List<QueuedCount> pending;

  /// Hitungan untuk opname yang sudah ditutup saat dikirim. Disimpan supaya penghitung bisa membagikan salinannya.
  final List<QueuedCount> closed;

  /// client_uuid => id entri di server, untuk membatalkan hitungan yang sudah terkirim.
  final Map<String, int> sentEntryIds;

  /// client_uuid => hasil cocok nomor seri dari server (matched, unknown, other_outlet, sold, removed).
  final Map<String, String> serialResults;
  final bool syncing;

  List<QueuedCount> pendingFor(int countId) => pending.where((item) => item.countId == countId).toList();
  List<QueuedCount> closedFor(int countId) => closed.where((item) => item.countId == countId).toList();

  CountQueueState copyWith({List<QueuedCount>? pending, List<QueuedCount>? closed, Map<String, int>? sentEntryIds, Map<String, String>? serialResults, bool? syncing}) =>
      CountQueueState(
        pending: pending ?? this.pending,
        closed: closed ?? this.closed,
        sentEntryIds: sentEntryIds ?? this.sentEntryIds,
        serialResults: serialResults ?? this.serialResults,
        syncing: syncing ?? this.syncing,
      );
}

final countQueueProvider = NotifierProvider<CountQueue, CountQueueState>(CountQueue.new);

class CountQueue extends Notifier<CountQueueState> {
  static const _key = StorageKeys.stockCountQueue;
  static const _batch = 500;

  @override
  CountQueueState build() {
    final raw = ref.read(sharedPreferencesProvider).getString(_key);
    if (raw == null) {
      return const CountQueueState();
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return CountQueueState(
        pending: asList(json['pending']).map(QueuedCount.fromJson).toList(),
        closed: asList(json['closed']).map(QueuedCount.fromJson).toList(),
      );
    } on Object {
      return const CountQueueState();
    }
  }

  @override
  set state(CountQueueState value) {
    super.state = value;
    ref.read(sharedPreferencesProvider).setString(
          _key,
          jsonEncode({
            'pending': value.pending.map((item) => item.toJson()).toList(),
            'closed': value.closed.map((item) => item.toJson()).toList(),
          }),
        );
  }

  void add(QueuedCount item) => state = state.copyWith(pending: [...state.pending, item]);

  /// Hapus hitungan yang belum terkirim. Mengembalikan false bila sudah terkirim (harus dibatalkan lewat server).
  bool removePending(String clientUuid) {
    final before = state.pending.length;
    state = state.copyWith(pending: state.pending.where((item) => item.clientUuid != clientUuid).toList());
    return state.pending.length < before;
  }

  void discardClosed(int countId) => state = state.copyWith(closed: state.closed.where((item) => item.countId != countId).toList());

  /// Kirim antrean per opname, terlama dulu. Berhenti di galat jaringan atau server (dicoba lagi nanti);
  /// penolakan per entri ditandai gagal, dan entri untuk opname yang sudah ditutup dipindah ke salinan.
  Future<int> sync({bool includeFailed = false}) async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null || state.syncing) {
      return 0;
    }

    final due = state.pending.where((item) => item.userId == userId && (includeFailed || !item.failed)).toList();
    if (due.isEmpty) {
      return 0;
    }

    state = state.copyWith(syncing: true);
    var sent = 0;
    try {
      final byCount = <(int, CountKind), List<QueuedCount>>{};
      for (final item in due) {
        byCount.putIfAbsent((item.countId, item.kind), () => []).add(item);
      }

      outer:
      for (final MapEntry(key: (countId, kind), value: items) in byCount.entries) {
        for (var start = 0; start < items.length; start += _batch) {
          final chunk = items.sublist(start, (start + _batch).clamp(0, items.length));
          final List<Map<String, dynamic>> results;
          try {
            final repository = ref.read(stockCountRepositoryProvider);
            final payloads = [for (final item in chunk) {...item.payload, 'client_uuid': item.clientUuid}];
            results = kind == CountKind.entry
                ? await repository.sendEntries(countId, payloads, DateTime.now(), outletId: chunk.first.outletId)
                : await repository.sendSerials(countId, payloads, DateTime.now(), outletId: chunk.first.outletId);
          } on ApiException catch (error) {
            final status = error.statusCode ?? 0;
            if (error.isNetworkError || error.isUnauthenticated || status >= 500 || status == 429) {
              break outer;
            }
            if (status == 404 || status == 403) {
              _close(chunk);
              continue;
            }
            rethrow;
          }
          sent += _apply(chunk, results);
        }
      }
    } finally {
      state = state.copyWith(syncing: false);
    }

    return sent;
  }

  int _apply(List<QueuedCount> chunk, List<Map<String, dynamic>> results) {
    final byUuid = {for (final result in results) '${result['client_uuid']}': result};
    final pending = [...state.pending];
    final closed = [...state.closed];
    final sentIds = {...state.sentEntryIds};
    final serialResults = {...state.serialResults};
    var sent = 0;

    for (var index = 0; index < chunk.length; index++) {
      final item = chunk[index];
      final result = byUuid[item.clientUuid] ?? (index < results.length ? results[index] : null);
      if (result == null) {
        continue;
      }
      final position = pending.indexWhere((queued) => queued.clientUuid == item.clientUuid);
      if (position < 0) {
        continue;
      }
      if (result['status'] == 'saved' || result['status'] == 'duplicate') {
        pending.removeAt(position);
        if (result['entry_id'] != null) {
          sentIds[item.clientUuid] = asInt(result['entry_id']);
        }
        if (result['result'] != null) {
          serialResults[item.clientUuid] = '${result['result']}';
        }
        sent++;
      } else if (result['reason'] == 'stock_count_closed') {
        closed.add(pending.removeAt(position));
      } else {
        pending[position] = item.failedWith('${result['error'] ?? result['reason'] ?? ''}');
      }
    }

    state = state.copyWith(pending: pending, closed: closed, sentEntryIds: sentIds, serialResults: serialResults);
    return sent;
  }

  void _close(List<QueuedCount> chunk) {
    final uuids = chunk.map((item) => item.clientUuid).toSet();
    state = state.copyWith(
      pending: state.pending.where((item) => !uuids.contains(item.clientUuid)).toList(),
      closed: [...state.closed, ...chunk],
    );
  }
}
