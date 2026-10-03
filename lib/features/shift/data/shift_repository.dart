import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/offline/offline_cache.dart';
import '../../sales/data/sale_models.dart';
import 'shift_models.dart';

final shiftRepositoryProvider = Provider<ShiftRepository>((ref) => ShiftRepository(ref.watch(apiClientProvider), ref.watch(offlineCacheProvider)));

class ShiftRepository {
  ShiftRepository(this._api, [this._cache]);

  final ApiClient _api;
  final OfflineCache? _cache;

  /// Falls back to the last known shift when offline, so the cashier can keep selling.
  Future<Shift?> current() async {
    try {
      final shift = ApiClient.data(await _api.get(ApiEndpoints.posShift))['shift'];
      await _cache?.put('current_shift', shift);
      return shift == null ? null : Shift.fromJson(shift as Map<String, dynamic>);
    } on ApiException catch (error) {
      final cached = _cache?.get('current_shift');
      if (!error.isNetworkError || cached == null) {
        rethrow;
      }
      return Shift.fromJson(cached as Map<String, dynamic>);
    }
  }

  Future<Shift> open(int openingCash) async {
    final data = ApiClient.data(await _api.post(ApiEndpoints.posShift, data: {'opening_cash': openingCash}));
    await _cache?.put('current_shift', data);
    return Shift.fromJson(data);
  }

  Future<void> recordCash({required String type, required int amount, required String reason}) =>
      _api.post(ApiEndpoints.posShiftCashMovements, data: {'type': type, 'amount': amount, 'reason': reason});

  Future<Paginated<Shift>> list({String? status, int page = 1}) async =>
      Paginated.fromJson(await _api.get(ApiEndpoints.shifts, query: {'status': status, 'page': page, 'per_page': 30}), Shift.fromJson);

  Future<Shift> show(int id) async => Shift.fromJson(ApiClient.data(await _api.get(ApiEndpoints.shift(id))));

  Future<Shift?> getCached(int id) async {
    final copy = await _api.offlineCopy(ApiEndpoints.shift(id));
    if (copy == null) {
      return null;
    }
    try {
      return Shift.fromJson(ApiClient.data(copy));
    } catch (_) {
      return null;
    }
  }

  Future<List<SaleSummary>> sales(int id) async => ApiClient.list(await _api.get(ApiEndpoints.shiftSales(id))).map(SaleSummary.fromJson).toList();

  Future<List<SaleSummary>?> getCachedSales(int id) async {
    final copy = await _api.offlineCopy(ApiEndpoints.shiftSales(id));
    if (copy == null) {
      return null;
    }
    try {
      return ApiClient.list(copy).map(SaleSummary.fromJson).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> recordCashFor(int shiftId, {required String type, required int amount, required String reason}) =>
      _api.post(ApiEndpoints.shiftCashMovements(shiftId.toString()), data: {'type': type, 'amount': amount, 'reason': reason});

  Future<Shift> close(int shiftId, {required int countedCash, String? note}) async {
    final data = ApiClient.data(await _api.post(ApiEndpoints.shiftClose(shiftId.toString()), data: {'counted_cash': countedCash, 'closing_note': note}));
    await _api.updateCached(ApiEndpoints.shift(shiftId), {'data': data});
    final cached = _cache?.get('current_shift');
    if (cached is Map && cached['id'] == shiftId) {
      await _cache?.put('current_shift', null);
    }
    return Shift.fromJson(data);
  }
}
