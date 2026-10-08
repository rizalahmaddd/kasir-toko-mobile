import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/paging/paged.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/access.dart';
import '../../auth/auth_controller.dart';
import '../../outlets/outlet_controller.dart';
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
    final outlet = ref.read(currentOutletProvider);

    final confirmed = await FormSheet.show<bool>(
      context,
      StatefulBuilder(
        builder: (context, setState) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;

          return FormSheet(
            title: StockCountStrings.start,
            subtitle: StockCountStrings.startTitle,
            children: [
              if (outlet != null)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.s12),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate800 : AppColors.slate100,
                    borderRadius: BorderRadius.circular(AppRadius.r8),
                    border: Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
                  ),
                  child: Row(
                    children: [
                      Icon(AppIcons.briefcaseBusiness, size: AppSizes.s16, color: theme.colorScheme.primary),
                      const SizedBox(width: AppSizes.s8),
                      Expanded(
                        child: Text(
                          outlet.name,
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(StockCountStrings.activeOutlet, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.s12),
                padding: const EdgeInsets.all(AppSpacing.s12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate800 : AppColors.slate50,
                  borderRadius: BorderRadius.circular(AppRadius.r8),
                  border: Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.r8),
                      ),
                      child: Icon(AppIcons.boxes, size: AppSizes.s20, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: AppSizes.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(StockCountStrings.scopeAll, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: AppSizes.s2),
                          Text(StockCountStrings.scopeHint, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              AppSwitchListTile(
                value: blind,
                onChanged: (value) => setState(() => blind = value),
                title: const Text(StockCountStrings.blindCount, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text(StockCountStrings.blindCountHint, style: TextStyle(fontSize: 12)),
              ),
              const Divider(height: AppSizes.s16),
              AppSwitchListTile(
                value: hold,
                onChanged: (value) => setState(() => hold = value),
                title: const Text(StockCountStrings.holdAdjustments, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text(StockCountStrings.holdAdjustmentsHint, style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(height: AppSizes.s12),
              TextField(
                controller: note,
                decoration: const InputDecoration(
                  labelText: StockCountStrings.note,
                  hintText: StockCountStrings.startNoteHint,
                ),
              ),
              const SizedBox(height: AppSizes.s20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(AppIcons.clipboardCheck, size: AppSizes.s18),
                  label: const Text(StockCountStrings.startAction),
                ),
              ),
            ],
          );
        },
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
          ? AppFloatingActionButton.extended(
              onPressed: () => _start(context, ref),
              icon: const Icon(AppIcons.plus),
              label: const Text(StockCountStrings.start),
            )
          : null,
      body: Column(
        children: [
          const SizedBox(height: AppSizes.s8),
          ChoiceChips<String>(
            options: const [
              ('open', StockCountStrings.tabOpen),
              ('posted', StockCountStrings.tabPosted),
              ('cancelled', StockCountStrings.tabCancelled),
            ],
            selected: tab,
            onSelected: (value) => ref.read(stockCountsTabProvider.notifier).set(value ?? 'open'),
          ),
          const SizedBox(height: AppSizes.s4),
          Expanded(
            child: PagedListView<StockCountDoc>(
              value: ref.watch(stockCountsProvider),
              onLoadMore: () => ref.read(stockCountsProvider.notifier).loadMore(),
              onRefresh: () => ref.refresh(stockCountsProvider.future),
              padding: const EdgeInsets.only(top: AppSpacing.s4, bottom: AppSpacing.s96),
              empty: const EmptyState(icon: AppIcons.clipboardCheck, title: StockCountStrings.empty, description: StockCountStrings.emptyHint),
              itemBuilder: (context, count) => _StockCountCard(
                count: count,
                onTap: () => context.push(AppRoutes.stockCountDetail(count.id)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StockCountCard extends StatelessWidget {
  const _StockCountCard({required this.count, required this.onTap});

  final StockCountDoc count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final percent = (count.progress * 100).toInt();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.slate200,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.r12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.r8),
                      ),
                      child: Icon(
                        AppIcons.clipboardCheck,
                        size: AppSizes.s20,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: AppSizes.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  count.number,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              StatusBadge(
                                label: count.statusLabel.toUpperCase(),
                                tone: stockCountTone(count.status),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSizes.s6),
                          Wrap(
                            spacing: AppSizes.s12,
                            runSpacing: AppSizes.s4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (count.outletName != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(AppIcons.briefcaseBusiness, size: AppSizes.s12, color: theme.colorScheme.onSurfaceVariant),
                                    const SizedBox(width: AppSizes.s4),
                                    Text(
                                      count.outletName!,
                                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(AppIcons.boxes, size: AppSizes.s12, color: theme.colorScheme.onSurfaceVariant),
                                  const SizedBox(width: AppSizes.s4),
                                  Text(
                                    count.scopeLabel,
                                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                              if (count.startedAt != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(AppIcons.clock, size: AppSizes.s12, color: theme.colorScheme.onSurfaceVariant),
                                    const SizedBox(width: AppSizes.s4),
                                    Text(
                                      dateTime(count.startedAt!),
                                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (count.note != null && count.note!.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSizes.s10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s6),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.slate900.withValues(alpha: 0.5) : AppColors.slate100,
                      borderRadius: BorderRadius.circular(AppRadius.r6),
                    ),
                    child: Text(
                      count.note!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSizes.s12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      StockCountStrings.progress(thousands(count.countedCount), thousands(count.itemsCount)),
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: AppSpacing.s2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.r4),
                      ),
                      child: Text(
                        '$percent%',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.s6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.r4),
                  child: LinearProgressIndicator(
                    value: count.progress,
                    minHeight: 6,
                    backgroundColor: isDark ? AppColors.slate700 : AppColors.slate200,
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
