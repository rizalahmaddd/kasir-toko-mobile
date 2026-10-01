import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/money_field.dart';
import '../../../core/widgets/state_views.dart';
import '../../pos/pos_providers.dart';
import '../data/shift_models.dart';
import '../shift_controller.dart';
import 'open_shift_card.dart';

const _methodLabels = {'qris': 'QRIS', 'transfer': 'Transfer', 'card': 'Kartu'};

class ShiftScreen extends ConsumerWidget {
  const ShiftScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shift = ref.watch(currentShiftProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shift saya'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            icon: const Icon(LucideIcons.refreshCw, size: 20),
            onPressed: () => ref.read(currentShiftProvider.notifier).refresh(),
          ),
        ],
      ),
      body: switch (shift) {
        AsyncData(value: null) => const OpenShiftCard(),
        AsyncData(:final value?) => _ShiftDetail(shift: value),
        AsyncError(:final error) => ShiftLoadError(error: error),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _ShiftDetail extends ConsumerWidget {
  const _ShiftDetail({required this.shift});

  final Shift shift;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = shift.summary;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return RefreshIndicator(
      onRefresh: () => ref.read(currentShiftProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DrawerPanel(shift: shift),
                  const SizedBox(height: 12),
                  if (shift.canRecordCash || shift.canClose)
                    Row(
                      children: [
                        if (shift.canRecordCash) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showCashSheet(context, 'in'),
                              icon: const Icon(LucideIcons.arrowDownToLine, size: 18),
                              label: const Text('Kas Masuk'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showCashSheet(context, 'out'),
                              icon: const Icon(LucideIcons.arrowUpFromLine, size: 18),
                              label: const Text('Kas Keluar'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  const SizedBox(height: 16),
                  if (summary != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _Row('Modal awal', rupiah(summary.opening)),
                            _Row('Penjualan tunai', rupiah(summary.cashSales)),
                            if (summary.cashReceivables > 0) _Row('Pelunasan kasbon tunai', rupiah(summary.cashReceivables)),
                            _Row('Kas masuk', rupiah(summary.cashIn)),
                            _Row('Kas keluar', summary.cashOut > 0 ? '-${rupiah(summary.cashOut)}' : rupiah(0)),
                            const Divider(height: 24),
                            _Row('Transaksi selesai', '${summary.salesCount}'),
                            _Row('Total penjualan', rupiah(summary.salesTotal)),
                            if (summary.voidedCount > 0) _Row('Dibatalkan', '${summary.voidedCount}'),
                            for (final entry in summary.nonCash.entries)
                              if (entry.value > 0) _Row(_methodLabels[entry.key] ?? entry.key, rupiah(entry.value)),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text('Kas masuk & keluar', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (shift.cashMovements.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
                                color: movement.isIn ? StatusColors.of(context).success : StatusColors.of(context).warning,
                              ),
                              title: Text(movement.reason),
                              subtitle: Text('${movement.typeLabel} · ${timeOnly(movement.createdAt)}'),
                              trailing: Text(
                                '${movement.isIn ? '+' : '-'}${rupiah(movement.amount)}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (shift.canClose) ...[
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: StatusColors.of(context).danger),
                      onPressed: () => _showCloseSheet(context, shift),
                      icon: const Icon(LucideIcons.lockKeyhole, size: 18),
                      label: const Text('Tutup Shift'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCashSheet(BuildContext context, String type) {
    showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => _CashMovementSheet(type: type));
  }

  void _showCloseSheet(BuildContext context, Shift shift) {
    showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => _CloseShiftSheet(shift: shift));
  }
}

class _DrawerPanel extends StatelessWidget {
  const _DrawerPanel({required this.shift});

  final Shift shift;

  @override
  Widget build(BuildContext context) {
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
              const StatusBadge(label: 'Aktif', tone: BadgeTone.success),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Uang di laci seharusnya', style: TextStyle(color: AppColors.slate400)),
          const SizedBox(height: 4),
          Text(
            rupiah(shift.summary?.expected ?? shift.openingCash),
            style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Dibuka ${dateTime(shift.openedAt)} oleh ${shift.cashierName}',
            style: const TextStyle(color: AppColors.slate400, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _CashMovementSheet extends ConsumerStatefulWidget {
  const _CashMovementSheet({required this.type});

  final String type;

  @override
  ConsumerState<_CashMovementSheet> createState() => _CashMovementSheetState();
}

class _CashMovementSheetState extends ConsumerState<_CashMovementSheet> {
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
      await ref.read(currentShiftProvider.notifier).recordCash(type: widget.type, amount: parseRupiah(_amount.text), reason: _reason.text.trim());
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

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_isIn ? 'Catat kas masuk' : 'Catat kas keluar', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
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
      ),
    );
  }
}

class _CloseShiftSheet extends ConsumerStatefulWidget {
  const _CloseShiftSheet({required this.shift});

  final Shift shift;

  @override
  ConsumerState<_CloseShiftSheet> createState() => _CloseShiftSheetState();
}

class _CloseShiftSheetState extends ConsumerState<_CloseShiftSheet> {
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
      final closed = await ref.read(currentShiftProvider.notifier).close(countedCash: _countedValue!, note: _note.text.trim());
      ref.invalidate(posConfigProvider);
      if (mounted) {
        Navigator.pop(context);
        final difference = closed.cashDifference ?? 0;
        showMessage(
          context,
          difference == 0
              ? 'Shift ${closed.number} ditutup. Uang laci pas.'
              : 'Shift ${closed.number} ditutup dengan selisih ${difference > 0 ? '+' : ''}${rupiah(difference)}.',
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

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Tutup shift ${widget.shift.number}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Seharusnya ada ${rupiah(_expected)} di laci.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
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
              difference == 0 ? 'Pas, tidak ada selisih.' : 'Selisih ${difference > 0 ? '+' : ''}${rupiah(difference)}',
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
      ),
    );
  }
}
