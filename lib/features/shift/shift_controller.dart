import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/shift_models.dart';
import 'data/shift_repository.dart';

/// The logged-in cashier's open shift, or null when none is open.
final currentShiftProvider = AsyncNotifierProvider<CurrentShiftController, Shift?>(CurrentShiftController.new);

class CurrentShiftController extends AsyncNotifier<Shift?> {
  ShiftRepository get _repository => ref.read(shiftRepositoryProvider);

  @override
  Future<Shift?> build() => _repository.current();

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repository.current);
  }

  Future<void> open(int openingCash) async {
    state = AsyncData(await _repository.open(openingCash));
  }

  Future<void> recordCash({required String type, required int amount, required String reason}) async {
    await _repository.recordCash(type: type, amount: amount, reason: reason);
    await refresh();
  }

  Future<Shift> close({required int countedCash, String? note}) async {
    final shift = state.value;
    if (shift == null) {
      throw StateError('No open shift');
    }

    final closed = await _repository.close(shift.id, countedCash: countedCash, note: note);
    state = const AsyncData(null);

    return closed;
  }
}
