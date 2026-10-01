import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../sales/data/sale_models.dart';
import 'shift_models.dart';

final shiftRepositoryProvider = Provider<ShiftRepository>((ref) => ShiftRepository(ref.watch(apiClientProvider)));

class ShiftRepository {
  ShiftRepository(this._api);

  final ApiClient _api;

  Future<Shift?> current() async {
    final shift = ApiClient.data(await _api.get('pos/shift'))['shift'];

    return shift == null ? null : Shift.fromJson(shift as Map<String, dynamic>);
  }

  Future<Shift> open(int openingCash) async => Shift.fromJson(ApiClient.data(await _api.post('pos/shift', data: {'opening_cash': openingCash})));

  Future<void> recordCash({required String type, required int amount, required String reason}) =>
      _api.post('pos/shift/cash-movements', data: {'type': type, 'amount': amount, 'reason': reason});

  Future<Paginated<Shift>> list({String? status, int page = 1}) async =>
      Paginated.fromJson(await _api.get('shifts', query: {'status': status, 'page': page, 'per_page': 30}), Shift.fromJson);

  Future<Shift> show(int id) async => Shift.fromJson(ApiClient.data(await _api.get('shifts/$id')));

  Future<List<SaleSummary>> sales(int id) async => ApiClient.list(await _api.get('shifts/$id/sales')).map(SaleSummary.fromJson).toList();

  Future<void> recordCashFor(int shiftId, {required String type, required int amount, required String reason}) =>
      _api.post('shifts/$shiftId/cash-movements', data: {'type': type, 'amount': amount, 'reason': reason});

  Future<Shift> close(int shiftId, {required int countedCash, String? note}) async => Shift.fromJson(
        ApiClient.data(await _api.post('shifts/$shiftId/close', data: {'counted_cash': countedCash, 'closing_note': note})),
      );
}
