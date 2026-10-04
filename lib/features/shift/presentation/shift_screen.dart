import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_routes.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';
import 'package:web_pos_mobile/core/constants/status_values.dart';

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
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

const _methodLabels = {PaymentMethods.qris: ShiftStrings.methodQris, PaymentMethods.transfer: ShiftStrings.methodTransfer, PaymentMethods.card: ShiftStrings.methodCard};

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
        title: const Text(ShiftStrings.myShiftTitle),
        actions: [
          if (canSeeHistory)
            IconButton(tooltip: ShiftStrings.shiftHistoryTooltip, icon: const Icon(AppIcons.history, size: AppSizes.s20), onPressed: () => context.push(AppRoutes.shifts)),
          if (shift.value != null && ref.watch(printerSettingsProvider).isConfigured)
            IconButton(
              tooltip: ShiftStrings.printRecapTooltip,
              icon: const Icon(AppIcons.printer, size: AppSizes.s20),
              onPressed: () => runPrint(context, () => ref.read(printerServiceProvider).printShift(shift.value!), success: ShiftStrings.recapPrinted),
            ),
          IconButton(tooltip: ShiftStrings.reloadTooltip, icon: const Icon(AppIcons.refreshCw, size: AppSizes.s20), onPressed: notifier.refresh),
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
        title: Text(shift.value?.number ?? ShiftStrings.shiftFallbackTitle),
        actions: [
          if (shift.value != null && ref.watch(printerSettingsProvider).isConfigured)
            IconButton(
              tooltip: ShiftStrings.printRecapTooltip,
              icon: const Icon(AppIcons.printer, size: AppSizes.s20),
              onPressed: () => runPrint(context, () => ref.read(printerServiceProvider).printShift(shift.value!), success: ShiftStrings.recapPrinted),
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
        padding: const EdgeInsets.all(AppSpacing.s16),
        children: [
          MaxWidth(
            width: 640,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DrawerCashCard(shift: shift),
                if (shift.canRecordCash) ...[
                  const SizedBox(height: AppSizes.s14),
                  Row(
                    children: [
                      Expanded(
                        child: _ShiftActionCard(
                          title: ShiftStrings.cashInMiniLabel,
                          subtitle: ShiftStrings.setOpeningCashSubtitle,
                          icon: AppIcons.arrowDownToLine,
                          color: colors.success,
                          onTap: () => FormSheet.show<void>(context, CashMovementSheet(type: CashMovementTypes.cashIn, recordCash: recordCash)),
                        ),
                      ),
                      const SizedBox(width: AppSizes.s10),
                      Expanded(
                        child: _ShiftActionCard(
                          title: ShiftStrings.cashOutMiniLabel,
                          subtitle: ShiftStrings.withdrawCashSubtitle,
                          icon: AppIcons.arrowUpFromLine,
                          color: colors.warning,
                          onTap: () => FormSheet.show<void>(context, CashMovementSheet(type: CashMovementTypes.cashOut, recordCash: recordCash)),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSizes.s16),
                if (summary != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.s18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(AppIcons.fileSpreadsheet, size: AppSizes.s18, color: colors.info),
                              const SizedBox(width: AppSizes.s8),
                              const Expanded(
                                child: Text(ShiftStrings.cashFlowRecapTitle, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSizes.s14),
                          InfoRow(ShiftStrings.openingCashLabel, rupiah(summary.opening)),
                          InfoRow(ShiftStrings.cashSalesLabel, rupiah(summary.cashSales)),
                          if (summary.cashReceivables > 0) InfoRow(ShiftStrings.cashReceivableSettlementLabel, rupiah(summary.cashReceivables)),
                          InfoRow(ShiftStrings.cashInLabel, rupiah(summary.cashIn)),
                          InfoRow(ShiftStrings.cashOutLabel, summary.cashOut > 0 ? '-${rupiah(summary.cashOut)}' : rupiah(0)),
                          if (!shift.isOpen) ...[
                            InfoRow(ShiftStrings.expectedInDrawerLabel, rupiah(summary.expected), bold: true),
                            InfoRow(ShiftStrings.countedCashLabel, rupiah(shift.countedCash ?? 0)),
                            InfoRow(
                              ShiftStrings.differenceLabel,
                              _signed(shift.cashDifference ?? 0),
                              valueColor: (shift.cashDifference ?? 0) == 0 ? colors.success : colors.warning,
                            ),
                          ],
                          const Divider(height: 24),
                          Row(
                            children: [
                              Icon(AppIcons.trendingUp, size: AppSizes.s18, color: colors.success),
                              const SizedBox(width: AppSizes.s8),
                              const Expanded(
                                child: Text(ShiftStrings.salesPerformanceTitle, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSizes.s14),
                          InfoRow(ShiftStrings.completedTransactionsLabel, '${summary.salesCount}'),
                          InfoRow(ShiftStrings.totalSalesLabel, rupiah(summary.salesTotal)),
                          if (summary.voidedCount > 0) InfoRow(ShiftStrings.voidedLabel, '${summary.voidedCount}'),
                          for (final entry in summary.nonCash.entries)
                            if (entry.value > 0) InfoRow(_methodLabels[entry.key] ?? entry.key, rupiah(entry.value)),
                        ],
                      ),
                    ),
                  ),
                if (shift.closingNote != null && shift.closingNote!.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.s8),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.slate800 : AppColors.slate100,
                      borderRadius: BorderRadius.circular(AppRadius.r10),
                    ),
                    child: Text(ShiftStrings.closingNoteLabel(shift.closingNote!), style: TextStyle(color: muted, fontSize: 13)),
                  ),
                ],
                const SizedBox(height: AppSizes.s12),
                const SectionTitle(ShiftStrings.cashMovementsTitle),
                if (shift.cashMovements.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8, horizontal: AppSpacing.s4),
                    child: Text(ShiftStrings.noCashMovements, style: TextStyle(color: muted)),
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        for (final movement in shift.cashMovements)
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(AppSpacing.s8),
                              decoration: BoxDecoration(
                                color: (movement.isIn ? colors.success : colors.warning).withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                movement.isIn ? AppIcons.arrowDownToLine : AppIcons.arrowUpFromLine,
                                size: AppSizes.s16,
                                color: movement.isIn ? colors.success : colors.warning,
                              ),
                            ),
                            title: Text(movement.reason, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text(ShiftStrings.movementSubtitle(movement.typeLabel, timeOnly(movement.createdAt)), style: TextStyle(color: muted, fontSize: 12)),
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
                  const SizedBox(height: AppSizes.s24),
                  Card(
                    color: isDark ? AppColors.slate900 : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.s18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            ShiftStrings.closeShiftCardTitle,
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          const SizedBox(height: AppSizes.s4),
                          Text(
                            ShiftStrings.closeShiftCardDescription,
                            style: TextStyle(color: muted, fontSize: 13),
                          ),
                          const SizedBox(height: AppSizes.s16),
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
                                  ShiftStrings.pendingOfflineMessage(waiting),
                                  isError: true,
                                );
                                return;
                              }
                              FormSheet.show<void>(context, CloseShiftSheet(shift: shift, close: close));
                            },
                            icon: const Icon(AppIcons.lockKeyhole, size: AppSizes.s18),
                            label: const Text(ShiftStrings.closeShiftButton),
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
      borderRadius: BorderRadius.circular(AppRadius.r14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.r14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.r14),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.s8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.r10),
                ),
                child: Icon(icon, size: AppSizes.s18, color: color),
              ),
              const SizedBox(width: AppSizes.s10),
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
                    const SizedBox(height: AppSizes.s2),
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
        SectionTitle(ShiftStrings.transactionsHeader(sales.value?.length ?? 0)),
        switch (sales) {
          AsyncData(:final value) when value.isEmpty =>
            Text(ShiftStrings.noTransactions, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          AsyncData(:final value) => Column(
              children: [
                for (final sale in value)
                  SaleTile(sale: sale, margin: const EdgeInsets.only(bottom: AppSpacing.s8)),
              ],
            ),
          AsyncError(:final error) => Text(errorMessage(error)),
          _ => const SalesListSkeleton(itemCount: 3, showSummary: false, shrinkWrap: true),
        },
      ],
    );
  }
}
