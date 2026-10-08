import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/prompt_dialog.dart';
import '../../../core/widgets/state_views.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(count.value?.number ?? StockCountStrings.reviewTitle),
        actions: [
          IconButton(tooltip: StockCountStrings.cancel, onPressed: _busy ? null : _cancel, icon: const Icon(AppIcons.ban)),
        ],
      ),
      body: AsyncView<CountPreview>(
        value: preview,
        onRetry: _refresh,
        data: (summary) => RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.s16),
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSizes.s8,
                crossAxisSpacing: AppSizes.s8,
                childAspectRatio: 2,
                children: [
                  StatTile(label: StockCountStrings.changed, value: thousands(summary.changed)),
                  StatTile(label: StockCountStrings.shortage, value: rupiah(summary.shortageValue), caption: quantity(summary.shortageQty), color: colors.danger),
                  StatTile(label: StockCountStrings.surplus, value: rupiah(summary.surplusValue), caption: quantity(summary.surplusQty), color: colors.success),
                  StatTile(label: StockCountStrings.uncounted, value: thousands(summary.uncounted), caption: rupiah(summary.uncountedValue), color: colors.warning),
                ],
              ),
              if (summary.uncounted > 0) ...[
                const SectionTitle(StockCountStrings.uncountedPolicy),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'keep', label: Text(StockCountStrings.policyKeep)),
                    ButtonSegment(value: 'zero', label: Text(StockCountStrings.policyZero)),
                  ],
                  selected: {_policy},
                  onSelectionChanged: (selected) => setState(() => _policy = selected.first),
                ),
              ],
              const SizedBox(height: AppSizes.s12),
              Text(StockCountStrings.offlineWarning, style: Theme.of(context).textTheme.bodySmall),
              const SectionTitle(StockCountStrings.filterVariance),
              items.when(
                loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.s16), child: Center(child: CircularProgressIndicator())),
                error: (error, _) => ErrorState(error: error, onRetry: _refresh),
                data: (rows) => rows.isEmpty
                    ? const Padding(padding: EdgeInsets.symmetric(vertical: AppSpacing.s16), child: Text(StockCountStrings.noVariance))
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s12),
          child: Row(
            children: [
              if (count.value?.status == StockCountStatuses.review)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _run(() => ref.read(stockCountRepositoryProvider).reopen(_id)),
                    child: const Text(StockCountStrings.backToCounting),
                  ),
                ),
              if (count.value?.status == StockCountStatuses.review) const SizedBox(width: AppSizes.s8),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _busy || preview.value == null
                      ? null
                      : count.value?.status == StockCountStatuses.counting
                          ? () => _run(() => ref.read(stockCountRepositoryProvider).submit(_id))
                          : () => _post(preview.value!),
                  child: Text(count.value?.status == StockCountStatuses.counting ? StockCountStrings.toReview : StockCountStrings.post),
                ),
              ),
            ],
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

    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.s8),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(item.displayName, style: const TextStyle(fontWeight: FontWeight.w600))),
                Text(
                  '${variance > 0 ? '+' : ''}${quantity(variance)} ${item.unit}',
                  style: TextStyle(color: variance < 0 ? colors.danger : colors.success, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            Text(
              [
                StockCountStrings.system(quantity(item.systemQty ?? 0)),
                StockCountStrings.counted(item.countedQty == null ? '-' : quantity(item.countedQty!)),
                if (item.varianceValue != null) rupiah(item.varianceValue!),
              ].join(' · '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSizes.s8),
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
                FilterChip(label: const Text(StockCountStrings.recount), selected: item.needsRecount, onSelected: (_) => onRecount()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
