import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/prompt_dialog.dart';
import '../../../core/widgets/state_views.dart';
import '../../outlets/outlet_controller.dart';
import '../data/stock_count_models.dart';
import '../data/stock_count_repository.dart';
import '../stock_count_providers.dart';

final _previewProvider = FutureProvider.autoDispose.family<CountPreview, int>((ref, id) => ref.read(stockCountRepositoryProvider).preview(id));

final _varianceProvider = FutureProvider.autoDispose.family<List<CountItem>, int>((ref, id) async {
  final repository = ref.read(stockCountRepositoryProvider);
  final items = <CountItem>[];
  for (final filter in ['variance', 'recount']) {
    var page = 1;
    while (true) {
      final result = await repository.items(id, filter: filter, page: page);
      items.addAll(result.items.where((item) => !items.any((existing) => existing.id == item.id)));
      if (!result.hasMore || page >= 10) {
        break;
      }
      page++;
    }
  }
  items.sort((a, b) => (b.varianceValue ?? 0).abs().compareTo((a.varianceValue ?? 0).abs()));
  return items;
});

class StockCountReviewScreen extends ConsumerStatefulWidget {
  const StockCountReviewScreen({super.key, required this.countId});

  final int countId;

  @override
  ConsumerState<StockCountReviewScreen> createState() => _StockCountReviewScreenState();
}

class _StockCountReviewScreenState extends ConsumerState<StockCountReviewScreen> {
  String _policy = 'keep';
  bool _busy = false;

  int get _id => widget.countId;

  void _refresh() {
    ref
      ..invalidate(stockCountProvider(_id))
      ..invalidate(_previewProvider(_id))
      ..invalidate(_varianceProvider(_id))
      ..invalidate(stockCountsProvider);
  }

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    setState(() => _busy = true);
    try {
      await action();
      _refresh();
      if (mounted && done != null) {
        showMessage(context, done);
      }
    } on ApiException catch (error) {
      if (mounted) {
        showError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _post(CountPreview preview) async {
    final uncounted = preview.uncounted == 0
        ? ''
        : _policy == 'zero'
            ? StockCountStrings.uncountedZero(thousands(preview.uncounted), rupiah(preview.uncountedValue))
            : StockCountStrings.uncountedKeep(thousands(preview.uncounted));
    final ok = await confirmAction(
      context,
      title: StockCountStrings.postTitle,
      message: StockCountStrings.postMessage(thousands(preview.changed), rupiah(preview.shortageValue), rupiah(preview.surplusValue), uncounted),
      confirmLabel: StockCountStrings.post,
    );
    if (!ok) {
      return;
    }
    await _run(() async {
      final count = await ref.read(stockCountRepositoryProvider).post(_id, uncountedPolicy: _policy);
      if (mounted) {
        showMessage(context, count.status == StockCountStatuses.posted ? StockCountStrings.posted : StockCountStrings.posting);
        context.pop();
      }
    });
  }

  Future<void> _cancel() async {
    final reason = await promptText(context, title: StockCountStrings.cancel, label: StockCountStrings.cancelReason, confirmLabel: StockCountStrings.cancel);
    if (reason == null) {
      return;
    }
    await _run(() async {
      await ref.read(stockCountRepositoryProvider).cancel(_id, reason: reason.isEmpty ? null : reason);
      if (mounted) {
        showMessage(context, StockCountStrings.cancelled);
        context.pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(stockCountProvider(_id));
    final preview = ref.watch(_previewProvider(_id));
    final items = ref.watch(_varianceProvider(_id));
    final colors = StatusColors.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ownOutlet = count.value?.belongsTo(ref.watch(currentOutletIdProvider)) ?? true;
    final locked = _busy || !ownOutlet;

    return Scaffold(
      appBar: AppBar(
        title: Text(count.value?.number ?? StockCountStrings.reviewTitle),
        actions: [
          IconButton(tooltip: StockCountStrings.cancel, onPressed: locked ? null : _cancel, icon: const Icon(AppIcons.ban)),
        ],
      ),
      body: AsyncView<CountPreview>(
        value: preview,
        onRetry: _refresh,
        data: (summary) => RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
            children: [
              if (!ownOutlet) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.s12),
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: colors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.r8),
                    border: Border.all(color: colors.warning.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(AppIcons.alertTriangle, size: AppSizes.s18, color: colors.warning),
                      const SizedBox(width: AppSizes.s8),
                      Expanded(
                        child: Text(
                          StockCountStrings.otherOutlet(count.value?.number ?? '', count.value?.outletName ?? ''),
                          style: TextStyle(color: colors.warning, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              GridView.count(
                crossAxisCount: MediaQuery.sizeOf(context).width >= 600 ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSizes.s8,
                crossAxisSpacing: AppSizes.s8,
                childAspectRatio: MediaQuery.sizeOf(context).width >= 600 ? 2.0 : 1.5,
                children: [
                  StatTile(label: StockCountStrings.changed, value: thousands(summary.changed), icon: AppIcons.boxes),
                  StatTile(
                    label: StockCountStrings.shortage,
                    value: rupiah(summary.shortageValue),
                    caption: '${quantity(summary.shortageQty)} barang',
                    icon: AppIcons.arrowDownToLine,
                    color: colors.danger,
                  ),
                  StatTile(
                    label: StockCountStrings.surplus,
                    value: rupiah(summary.surplusValue),
                    caption: '${quantity(summary.surplusQty)} barang',
                    icon: AppIcons.arrowUpFromLine,
                    color: colors.success,
                  ),
                  StatTile(
                    label: StockCountStrings.uncounted,
                    value: thousands(summary.uncounted),
                    caption: rupiah(summary.uncountedValue),
                    icon: AppIcons.clockAlert,
                    color: colors.warning,
                  ),
                ],
              ),
              if (summary.uncounted > 0) ...[
                const SizedBox(height: AppSizes.s12),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate800 : Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.r10),
                    border: Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(AppIcons.layers, size: AppSizes.s16, color: theme.colorScheme.primary),
                          const SizedBox(width: AppSizes.s8),
                          Expanded(
                            child: Text(
                              StockCountStrings.uncountedPolicy,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.s4),
                      Text(
                        StockCountStrings.uncountedPolicyHint(thousands(summary.uncounted)),
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: AppSizes.s10),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'keep', label: Text(StockCountStrings.policyKeep)),
                          ButtonSegment(value: 'zero', label: Text(StockCountStrings.policyZero)),
                        ],
                        selected: {_policy},
                        onSelectionChanged: (selected) => setState(() => _policy = selected.first),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSizes.s12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate800 : AppColors.slate100,
                  borderRadius: BorderRadius.circular(AppRadius.r8),
                ),
                child: Row(
                  children: [
                    Icon(AppIcons.info, size: AppSizes.s16, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: AppSizes.s8),
                    Expanded(
                      child: Text(
                        StockCountStrings.offlineWarning,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.s16, bottom: AppSpacing.s8),
                child: SectionTitle(StockCountStrings.filterVariance),
              ),
              items.when(
                loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.s24), child: Center(child: CircularProgressIndicator())),
                error: (error, _) => ErrorState(error: error, onRetry: _refresh),
                data: (rows) => rows.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.s24),
                        child: Center(
                          child: Text(
                            StockCountStrings.noVariance,
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          for (final item in rows)
                            _VarianceTile(
                              item: item,
                              onReason: (reason) => _run(() => ref.read(stockCountRepositoryProvider).updateItem(_id, item.id, reason: reason, clearReason: reason == null)),
                              onRecount: () => _run(() => ref.read(stockCountRepositoryProvider).updateItem(_id, item.id, needsRecount: !item.needsRecount)),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: AppSpacing.s96),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.slate900 : Colors.white,
          border: Border(top: BorderSide(color: isDark ? AppColors.slate800 : AppColors.slate200)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s12),
            child: Row(
              children: [
                if (count.value?.status == StockCountStatuses.review)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: locked ? null : () => _run(() => ref.read(stockCountRepositoryProvider).reopen(_id)),
                      child: const Text(StockCountStrings.backToCounting),
                    ),
                  ),
                if (count.value?.status == StockCountStatuses.review) const SizedBox(width: AppSizes.s8),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: locked || preview.value == null
                        ? null
                        : count.value?.status == StockCountStatuses.counting
                            ? () => _run(() => ref.read(stockCountRepositoryProvider).submit(_id))
                            : () => _post(preview.value!),
                    icon: Icon(
                      count.value?.status == StockCountStatuses.counting ? AppIcons.check : AppIcons.circleCheck,
                      size: AppSizes.s18,
                    ),
                    label: Text(count.value?.status == StockCountStatuses.counting ? StockCountStrings.toReview : StockCountStrings.post),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VarianceTile extends StatelessWidget {
  const _VarianceTile({required this.item, required this.onReason, required this.onRecount});

  final CountItem item;
  final ValueChanged<String?> onReason;
  final VoidCallback onRecount;

  @override
  Widget build(BuildContext context) {
    final variance = item.varianceQty ?? 0;
    final colors = StatusColors.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.s8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.r10),
        border: Border.all(
          color: item.needsRecount
              ? colors.warning.withValues(alpha: 0.7)
              : isDark
                  ? AppColors.slate700
                  : AppColors.slate200,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s2),
                  decoration: BoxDecoration(
                    color: (variance < 0 ? colors.danger : colors.success).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.r4),
                  ),
                  child: Text(
                    '${variance > 0 ? '+' : ''}${quantity(variance)} ${item.unit}',
                    style: TextStyle(
                      color: variance < 0 ? colors.danger : colors.success,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.s8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s6),
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate900.withValues(alpha: 0.5) : AppColors.slate100,
                borderRadius: BorderRadius.circular(AppRadius.r6),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(StockCountStrings.labelSystem, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 10)),
                        const SizedBox(height: AppSizes.s2),
                        Text(quantity(item.systemQty ?? 0), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(StockCountStrings.labelCounted, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 10)),
                        const SizedBox(height: AppSizes.s2),
                        Text(item.countedQty == null ? '-' : quantity(item.countedQty!), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
                  ),
                  if (item.varianceValue != null)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(StockCountStrings.labelVarianceValue, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 10)),
                          const SizedBox(height: AppSizes.s2),
                          Text(
                            rupiah(item.varianceValue!),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: variance < 0 ? colors.danger : colors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.s10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: item.reason,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: StockCountStrings.reason, isDense: true),
                    items: [
                      const DropdownMenuItem(value: null, child: Text(StockCountStrings.noReason)),
                      for (final MapEntry(key: value, value: label) in StockCountStrings.reasons.entries) DropdownMenuItem(value: value, child: Text(label)),
                    ],
                    onChanged: onReason,
                  ),
                ),
                const SizedBox(width: AppSizes.s8),
                FilterChip(
                  label: const Text(StockCountStrings.recount),
                  selected: item.needsRecount,
                  avatar: Icon(AppIcons.rotateCcw, size: AppSizes.s14, color: item.needsRecount ? theme.colorScheme.primary : null),
                  onSelected: (_) => onRecount(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
