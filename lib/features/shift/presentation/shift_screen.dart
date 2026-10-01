import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/money_field.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/access.dart';
import '../../auth/auth_controller.dart';
import '../../pos/pos_providers.dart';
import '../../printing/presentation/printer_screen.dart';
import '../../printing/printer.dart';
import '../../sales/presentation/sale_tile.dart';
import '../data/shift_models.dart';
import '../data/shift_repository.dart';
import '../shift_controller.dart';
import '../shifts_providers.dart';
import 'open_shift_card.dart';

const _methodLabels = {'qris': 'QRIS', 'transfer': 'Transfer', 'card': 'Kartu'};

typedef RecordCash = Future<void> Function({required String type, required int amount, required String reason});
typedef CloseShift = Future<Shift> Function({required int countedCash, String? note});

/// The logged-in cashier's own shift.
class ShiftScreen extends ConsumerWidget {
  const ShiftScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shift = ref.watch(currentShiftProvider);
    final notifier = ref.read(currentShiftProvider.notifier);
    final canSeeHistory = ref.watch(currentUserProvider)?.canViewShifts ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shift saya'),
        actions: [
          if (canSeeHistory)
            IconButton(tooltip: 'Riwayat shift', icon: const Icon(LucideIcons.history, size: 20), onPressed: () => context.push('/shifts')),
          if (shift.value != null && ref.watch(printerSettingsProvider).isConfigured)
            IconButton(
              tooltip: 'Cetak rekap',
              icon: const Icon(LucideIcons.printer, size: 20),
              onPressed: () => runPrint(context, () => ref.read(printerServiceProvider).printShift(shift.value!), success: 'Rekap shift dicetak.'),
            ),
          IconButton(tooltip: 'Muat ulang', icon: const Icon(LucideIcons.refreshCw, size: 20), onPressed: notifier.refresh),
        ],
      ),
      body: switch (shift) {
        AsyncData(value: null) => const OpenShiftCard(),
        AsyncData(:final value?) => ShiftView(
            shift: value,
            onRefresh: notifier.refresh,
            recordCash: notifier.recordCash,
            close: ({required countedCash, note}) async {
              final closed = await notifier.close(countedCash: countedCash, note: note);
              ref.invalidate(posConfigProvider);
              return closed;
            },
          ),
        AsyncError(:final error) => ShiftLoadError(error: error),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// Any shift by id, for the shift history.
class ShiftDetailScreen extends ConsumerWidget {
  const ShiftDetailScreen({super.key, required this.shiftId});

  final int shiftId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shift = ref.watch(shiftDetailProvider(shiftId));
    final repository = ref.read(shiftRepositoryProvider);

    void refreshAll() => ref
      ..invalidate(shiftDetailProvider(shiftId))
      ..invalidate(shiftSalesProvider(shiftId))
      ..invalidate(shiftsProvider)
      ..invalidate(currentShiftProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(shift.value?.number ?? 'Shift'),
        actions: [
          if (shift.value != null && ref.watch(printerSettingsProvider).isConfigured)
            IconButton(
              tooltip: 'Cetak rekap',
              icon: const Icon(LucideIcons.printer, size: 20),
              onPressed: () => runPrint(context, () => ref.read(printerServiceProvider).printShift(shift.value!), success: 'Rekap shift dicetak.'),
            ),
        ],
      ),
      body: AsyncView(
        value: shift,
        onRetry: () => ref.invalidate(shiftDetailProvider(shiftId)),
        data: (shift) => ShiftView(
          shift: shift,
          showSales: true,
          onRefresh: () async => refreshAll(),
          recordCash: ({required type, required amount, required reason}) async {
            await repository.recordCashFor(shiftId, type: type, amount: amount, reason: reason);
            refreshAll();
          },
          close: ({required countedCash, note}) async {
            final closed = await repository.close(shiftId, countedCash: countedCash, note: note);
            refreshAll();
            ref.invalidate(posConfigProvider);
            return closed;
          },
        ),
      ),
    );
  }
}

class ShiftView extends ConsumerWidget {
  const ShiftView({super.key, required this.shift, required this.onRefresh, required this.recordCash, required this.close, this.showSales = false});

  final Shift shift;
  final Future<void> Function() onRefresh;
  final RecordCash recordCash;
  final CloseShift close;
  final bool showSales;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = shift.summary;
    final colors = StatusColors.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          MaxWidth(
            width: 640,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DrawerPanel(shift: shift),
                if (shift.canRecordCash) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => FormSheet.show<void>(context, _CashMovementSheet(type: 'in', recordCash: recordCash)),
                          icon: const Icon(LucideIcons.arrowDownToLine, size: 18),
                          label: const Text('Kas Masuk'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => FormSheet.show<void>(context, _CashMovementSheet(type: 'out', recordCash: recordCash)),
                          icon: const Icon(LucideIcons.arrowUpFromLine, size: 18),
                          label: const Text('Kas Keluar'),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                if (summary != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          InfoRow('Modal awal', rupiah(summary.opening)),
                          InfoRow('Penjualan tunai', rupiah(summary.cashSales)),
                          if (summary.cashReceivables > 0) InfoRow('Pelunasan kasbon tunai', rupiah(summary.cashReceivables)),
                          InfoRow('Kas masuk', rupiah(summary.cashIn)),
                          InfoRow('Kas keluar', summary.cashOut > 0 ? '-${rupiah(summary.cashOut)}' : rupiah(0)),
                          if (!shift.isOpen) ...[
                            InfoRow('Uang di laci seharusnya', rupiah(summary.expected), bold: true),
                            InfoRow('Uang fisik dihitung', rupiah(shift.countedCash ?? 0)),
                            InfoRow(
                              'Selisih',
                              _signed(shift.cashDifference ?? 0),
                              valueColor: (shift.cashDifference ?? 0) == 0 ? colors.success : colors.warning,
                            ),
                          ],
                          const Divider(height: 24),
                          InfoRow('Transaksi selesai', '${summary.salesCount}'),
                          InfoRow('Total penjualan', rupiah(summary.salesTotal)),
                          if (summary.voidedCount > 0) InfoRow('Dibatalkan', '${summary.voidedCount}'),
                          for (final entry in summary.nonCash.entries)
                            if (entry.value > 0) InfoRow(_methodLabels[entry.key] ?? entry.key, rupiah(entry.value)),
                        ],
                      ),
                    ),
                  ),
                if (shift.closingNote != null && shift.closingNote!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Catatan tutup: ${shift.closingNote}', style: TextStyle(color: muted)),
                ],
                const SectionTitle('Kas masuk & keluar'),
                if (shift.cashMovements.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                    child: Text('Belum ada kas masuk atau keluar di shift ini.', style: TextStyle(color: muted)),
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        for (final movement in shift.cashMovements)
                          ListTile(
                            leading: Icon(
                              movement.isIn ? LucideIcons.arrowDownToLine : LucideIcons.arrowUpFromLine,
                              size: 18,
                              color: movement.isIn ? colors.success : colors.warning,
                            ),
                            title: Text(movement.reason),
                            subtitle: Text('${movement.typeLabel} · ${timeOnly(movement.createdAt)}'),
                            trailing: Text('${movement.isIn ? '+' : '-'}${rupiah(movement.amount)}'),
                          ),
                      ],
                    ),
                  ),
                if (showSales) _ShiftSales(shiftId: shift.id),
                if (shift.canClose) ...[
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: colors.danger),
                    onPressed: () => FormSheet.show<void>(context, _CloseShiftSheet(shift: shift, close: close)),
                    icon: const Icon(LucideIcons.lockKeyhole, size: 18),
                    label: const Text('Tutup Shift'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _signed(int value) => value == 0 ? rupiah(0) : '${value > 0 ? '+' : '-'}${rupiah(value.abs())}';

class _DrawerPanel extends StatelessWidget {
  const _DrawerPanel({required this.shift});

  final Shift shift;

  @override
  Widget build(BuildContext context) {
    final expected = shift.summary?.expected ?? shift.expectedCash ?? shift.openingCash;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(colors: [AppColors.slate900, AppColors.slate800], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(shift.number, style: const TextStyle(color: AppColors.slate300, fontWeight: FontWeight.w600)),
              const Spacer(),
              StatusBadge(label: shift.isOpen ? 'Aktif' : 'Ditutup', tone: shift.isOpen ? BadgeTone.success : BadgeTone.muted),
            ],
          ),
          const SizedBox(height: 16),
          Text(shift.isOpen ? 'Uang di laci seharusnya' : 'Uang fisik saat ditutup', style: const TextStyle(color: AppColors.slate400)),
          const SizedBox(height: 4),
          Text(
            rupiah(shift.isOpen ? expected : shift.countedCash ?? expected),
            style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text('Dibuka ${dateTime(shift.openedAt)} oleh ${shift.cashierName}', style: const TextStyle(color: AppColors.slate400, fontSize: 13)),
          if (shift.closedAt != null)
            Text(
              'Ditutup ${dateTime(shift.closedAt!)}${shift.closedByName == null ? '' : ' oleh ${shift.closedByName}'}',
              style: const TextStyle(color: AppColors.slate400, fontSize: 13),
            ),
        ],
      ),
    );
  }
}

class _ShiftSales extends ConsumerWidget {
  const _ShiftSales({required this.shiftId});

  final int shiftId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sales = ref.watch(shiftSalesProvider(shiftId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle('Transaksi (${sales.value?.length ?? 0})'),
        switch (sales) {
          AsyncData(:final value) when value.isEmpty =>
            Text('Belum ada transaksi.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          AsyncData(:final value) => Card(child: Column(children: [for (final sale in value) SaleTile(sale: sale)])),
          AsyncError(:final error) => Text(errorMessage(error)),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ],
    );
  }
}

class _CashMovementSheet extends StatefulWidget {
  const _CashMovementSheet({required this.type, required this.recordCash});

  final String type;
  final RecordCash recordCash;

  @override
  State<_CashMovementSheet> createState() => _CashMovementSheetState();
}

class _CashMovementSheetState extends State<_CashMovementSheet> {
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  bool _busy = false;
  ApiException? _error;

  bool get _isIn => widget.type == 'in';

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await widget.recordCash(type: widget.type, amount: parseRupiah(_amount.text), reason: _reason.text.trim());
      if (mounted) {
        Navigator.pop(context);
        showMessage(context, _isIn ? 'Kas masuk dicatat.' : 'Kas keluar dicatat.');
      }
    } on ApiException catch (error) {
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final generalError = _error != null && _error!.fieldError('amount') == null && _error!.fieldError('reason') == null ? _error!.message : null;

    return FormSheet(
      title: _isIn ? 'Catat kas masuk' : 'Catat kas keluar',
      children: [
        MoneyField(controller: _amount, label: 'Nominal', autofocus: true, errorText: _error?.fieldError('amount')),
        const SizedBox(height: 12),
        TextField(
          controller: _reason,
          maxLength: 150,
          decoration: InputDecoration(
            labelText: 'Keperluan',
            hintText: _isIn ? 'mis. tambah uang kembalian' : 'mis. beli es batu, setor ke pemilik',
            errorText: _error?.fieldError('reason'),
          ),
        ),
        if (generalError != null) Text(generalError, style: TextStyle(color: StatusColors.of(context).danger)),
        const SizedBox(height: 8),
        FilledButton(onPressed: _busy ? null : _save, child: Text(_isIn ? 'Simpan Kas Masuk' : 'Simpan Kas Keluar')),
      ],
    );
  }
}

class _CloseShiftSheet extends StatefulWidget {
  const _CloseShiftSheet({required this.shift, required this.close});

  final Shift shift;
  final CloseShift close;

  @override
  State<_CloseShiftSheet> createState() => _CloseShiftSheetState();
}

class _CloseShiftSheetState extends State<_CloseShiftSheet> {
  final _counted = TextEditingController();
  final _note = TextEditingController();
  int? _countedValue;
  bool _busy = false;
  String? _error;

  int get _expected => widget.shift.summary?.expected ?? widget.shift.openingCash;

  @override
  void dispose() {
    _counted.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_countedValue == null) {
      setState(() => _error = 'Hitung dan isi uang fisik di laci.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final closed = await widget.close(countedCash: _countedValue!, note: _note.text.trim());
      if (mounted) {
        Navigator.pop(context);
        final difference = closed.cashDifference ?? 0;
        showMessage(
          context,
          difference == 0 ? 'Shift ${closed.number} ditutup. Uang laci pas.' : 'Shift ${closed.number} ditutup dengan selisih ${_signed(difference)}.',
        );
      }
    } on ApiException catch (error) {
      setState(() => _error = error.fieldError('counted_cash') ?? error.message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = StatusColors.of(context);
    final difference = _countedValue == null ? null : _countedValue! - _expected;

    return FormSheet(
      title: 'Tutup shift ${widget.shift.number}',
      subtitle: 'Seharusnya ada ${rupiah(_expected)} di laci.',
      children: [
        MoneyField(
          controller: _counted,
          label: 'Uang fisik yang dihitung',
          autofocus: true,
          errorText: _error,
          onChanged: (value) => setState(() => _countedValue = _counted.text.isEmpty ? null : value),
        ),
        if (difference != null) ...[
          const SizedBox(height: 8),
          Text(
            difference == 0 ? 'Pas, tidak ada selisih.' : 'Selisih ${_signed(difference)}',
            style: TextStyle(fontWeight: FontWeight.w600, color: difference == 0 ? colors.success : colors.warning),
          ),
        ],
        const SizedBox(height: 12),
        TextField(controller: _note, maxLength: 255, decoration: const InputDecoration(labelText: 'Catatan (opsional)')),
        const SizedBox(height: 8),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: colors.danger),
          onPressed: _busy ? null : _close,
          child: const Text('Tutup Shift'),
        ),
      ],
    );
  }
}
