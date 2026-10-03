import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../data_changes.dart';
import '../../auth/access.dart';
import '../../auth/auth_controller.dart';
import '../../offline/offline_queue.dart';
import '../../printing/presentation/printer_screen.dart';
import '../../printing/printer.dart';
import '../../sales/presentation/sale_tile.dart';
import '../data/shift_models.dart';
import '../data/shift_repository.dart';
import '../shift_controller.dart';
import '../shifts_providers.dart';
import 'open_shift_card.dart';
import 'widgets/cash_movement_sheet.dart';
import 'widgets/close_shift_sheet.dart';
import 'widgets/drawer_cash_card.dart';

const _methodLabels = {'qris': 'QRIS', 'transfer': 'Transfer', 'card': 'Kartu'};

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
            recordCash: ({required type, required amount, required reason}) async {
              await notifier.recordCash(type: type, amount: amount, reason: reason);
              ref.read(dataChangesProvider).after({DataChange.shifts});
            },
            close: ({required countedCash, note}) async {
              final closed = await notifier.close(countedCash: countedCash, note: note);
              ref.read(dataChangesProvider).after({DataChange.shifts});
              return closed;
            },
          ),
        AsyncError(:final error) => ShiftLoadError(error: error),
        _ => const ShiftsListSkeleton(),
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

    Future<void> reload() => Future.wait([
      ref.read(shiftDetailProvider(shiftId).notifier).refresh(),
      ref.read(shiftSalesProvider(shiftId).notifier).refresh(),
    ]);
    void changed() => ref.read(dataChangesProvider).after({DataChange.shifts});

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
          onRefresh: () async => reload(),
          recordCash: ({required type, required amount, required reason}) async {
            await repository.recordCashFor(shiftId, type: type, amount: amount, reason: reason);
            changed();
          },
          close: ({required countedCash, note}) async {
            final closed = await repository.close(shiftId, countedCash: countedCash, note: note);
            changed();
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

  static String _signed(int value) => value == 0 ? rupiah(0) : '${value > 0 ? '+' : '-'}${rupiah(value.abs())}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = shift.summary;
    final colors = StatusColors.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                DrawerCashCard(shift: shift),
                if (shift.canRecordCash) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _ShiftActionCard(
                          title: 'Kas Masuk',
                          subtitle: 'Setor modal / penerimaan',
                          icon: LucideIcons.arrowDownToLine,
                          color: colors.success,
                          onTap: () => FormSheet.show<void>(context, CashMovementSheet(type: 'in', recordCash: recordCash)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ShiftActionCard(
                          title: 'Kas Keluar',
                          subtitle: 'Tarik kas / pengeluaran',
                          icon: LucideIcons.arrowUpFromLine,
                          color: colors.warning,
                          onTap: () => FormSheet.show<void>(context, CashMovementSheet(type: 'out', recordCash: recordCash)),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                if (summary != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(LucideIcons.fileSpreadsheet, size: 18, color: colors.info),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text('Rekapitulasi Arus Kas', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
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
                          Row(
                            children: [
                              Icon(LucideIcons.trendingUp, size: 18, color: colors.success),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text('Performa Penjualan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
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
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.slate800 : AppColors.slate100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('Catatan tutup: ${shift.closingNote}', style: TextStyle(color: muted, fontSize: 13)),
                  ),
                ],
                const SizedBox(height: 12),
                const SectionTitle('Kas masuk & keluar'),
                if (shift.cashMovements.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Text('Belum ada kas masuk atau keluar di shift ini.', style: TextStyle(color: muted)),
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        for (final movement in shift.cashMovements)
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (movement.isIn ? colors.success : colors.warning).withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                movement.isIn ? LucideIcons.arrowDownToLine : LucideIcons.arrowUpFromLine,
                                size: 16,
                                color: movement.isIn ? colors.success : colors.warning,
                              ),
                            ),
                            title: Text(movement.reason, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text('${movement.typeLabel} · ${timeOnly(movement.createdAt)}', style: TextStyle(color: muted, fontSize: 12)),
                            trailing: Text(
                              '${movement.isIn ? '+' : '-'}${rupiah(movement.amount)}',
                              style: AppTypography.money(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: movement.isIn ? colors.success : colors.warning,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (showSales) _ShiftSales(shiftId: shift.id),
                if (shift.canClose) ...[
                  const SizedBox(height: 24),
                  Card(
                    color: isDark ? AppColors.slate900 : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Tutup Shift Kasir',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pastikan semua pesanan telah selesai dan hitung uang tunai di laci kasir.',
                            style: TextStyle(color: muted, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: colors.danger,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48),
                            ),
                            onPressed: () {
                              final waiting = ref.read(myQueueProvider).length;
                              if (waiting > 0) {
                                showMessage(
                                  context,
                                  'Masih ada $waiting transaksi offline yang belum terkirim. Kirim dulu di Menu → Mode offline.',
                                  isError: true,
                                );
                                return;
                              }
                              FormSheet.show<void>(context, CloseShiftSheet(shift: shift, close: close));
                            },
                            icon: const Icon(LucideIcons.lockKeyhole, size: 18),
                            label: const Text('Tutup Shift'),
                          ),
                        ],
                      ),
                    ),
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

class _ShiftActionCard extends StatelessWidget {
  const _ShiftActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? AppColors.slate900 : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: isDark ? AppColors.slate100 : AppColors.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.slate400 : AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
          AsyncData(:final value) => Column(
              children: [
                for (final sale in value)
                  SaleTile(sale: sale, margin: const EdgeInsets.only(bottom: 8)),
              ],
            ),
          AsyncError(:final error) => Text(errorMessage(error)),
          _ => const SalesListSkeleton(itemCount: 3, showSummary: false, shrinkWrap: true),
        },
      ],
    );
  }
}
