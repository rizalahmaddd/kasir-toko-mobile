import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/paging/paged.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/access.dart';
import '../../auth/auth_controller.dart';
import '../data/stock_count_models.dart';
import '../data/stock_count_repository.dart';
import '../stock_count_providers.dart';

BadgeTone stockCountTone(String status) => switch (status) {
      StockCountStatuses.counting => BadgeTone.info,
      StockCountStatuses.review => BadgeTone.warning,
      StockCountStatuses.posted => BadgeTone.success,
      StockCountStatuses.cancelled => BadgeTone.danger,
      _ => BadgeTone.muted,
    };

class StockCountsScreen extends ConsumerWidget {
  const StockCountsScreen({super.key});

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    var blind = true;
    var hold = true;
    final note = TextEditingController();

    final confirmed = await FormSheet.show<bool>(
      context,
      StatefulBuilder(
        builder: (context, setState) => FormSheet(
          title: StockCountStrings.start,
          subtitle: StockCountStrings.scopeHint,
          children: [
            const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(AppIcons.boxes), title: Text(StockCountStrings.scopeAll)),
            AppSwitchListTile(value: blind, onChanged: (value) => setState(() => blind = value), title: const Text(StockCountStrings.blindCount)),
            AppSwitchListTile(value: hold, onChanged: (value) => setState(() => hold = value), title: const Text(StockCountStrings.holdAdjustments)),
            const SizedBox(height: AppSizes.s8),
            TextField(controller: note, decoration: const InputDecoration(labelText: StockCountStrings.note)),
            const SizedBox(height: AppSizes.s16),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text(StockCountStrings.startAction)),
          ],
        ),
      ),
    );

    final text = note.text.trim();
    note.dispose();
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      final count = await ref.read(stockCountRepositoryProvider).start(scope: 'all', blindCount: blind, holdAdjustments: hold, note: text.isEmpty ? null : text);
      ref.invalidate(stockCountsProvider);
      if (context.mounted) {
        await context.push(AppRoutes.stockCountDetail(count.id));
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        showError(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(stockCountsTabProvider);
    final canManage = ref.watch(currentUserProvider)?.canManageStockCount ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text(StockCountStrings.screenTitle)),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(onPressed: () => _start(context, ref), icon: const Icon(AppIcons.plus), label: const Text(StockCountStrings.start))
          : null,
      body: Column(
        children: [
          const SizedBox(height: AppSizes.s8),
          ChoiceChips<String>(
            options: const [('open', StockCountStrings.tabOpen), ('posted', StockCountStrings.tabPosted), ('cancelled', StockCountStrings.tabCancelled)],
            selected: tab,
            onSelected: (value) => ref.read(stockCountsTabProvider.notifier).set(value ?? 'open'),
          ),
          Expanded(
            child: PagedListView<StockCountDoc>(
              value: ref.watch(stockCountsProvider),
              onLoadMore: () => ref.read(stockCountsProvider.notifier).loadMore(),
              onRefresh: () => ref.refresh(stockCountsProvider.future),
              padding: const EdgeInsets.only(bottom: AppSpacing.s96),
              empty: const EmptyState(icon: AppIcons.clipboardCheck, title: StockCountStrings.empty, description: StockCountStrings.emptyHint),
              itemBuilder: (context, count) => ListTile(
                onTap: () => context.push(AppRoutes.stockCountDetail(count.id)),
                leading: const Icon(AppIcons.clipboardCheck),
                title: Text(count.number),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        count.scopeLabel,
                        if (count.outletName != null) count.outletName!,
                        if (count.startedAt != null) dateTime(count.startedAt!),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSizes.s4),
                    LinearProgressIndicator(value: count.progress, minHeight: 4),
                    const SizedBox(height: AppSizes.s2),
                    Text(StockCountStrings.progress(thousands(count.countedCount), thousands(count.itemsCount))),
                  ],
                ),
                trailing: StatusBadge(label: count.statusLabel.toUpperCase(), tone: stockCountTone(count.status)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
