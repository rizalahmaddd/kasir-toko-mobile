import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_routes.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';

import '../../../core/paging/paged.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/filter_pills.dart';
import '../../../core/widgets/state_views.dart';
import '../data/shift_models.dart';
import '../shifts_providers.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

class ShiftsScreen extends ConsumerWidget {
  const ShiftsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(shiftsStatusProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text(ShiftStrings.historyTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s4, AppSpacing.s16, AppSpacing.s8),
            child: Row(
              children: [
                FilterDropdownPill<String>(
                  label: ShiftStrings.statusFilterLabel,
                  icon: AppIcons.wallet,
                  value: status,
                  items: const [
                    (null, ShiftStrings.allShifts),
                    ('open', ShiftStrings.openShifts),
                    ('closed', ShiftStrings.closedShifts),
                    ('variance', ShiftStrings.varianceShifts),
                  ],
                  onChanged: ref.read(shiftsStatusProvider.notifier).set,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.s2),
          Expanded(
            child: PagedListView(
              value: ref.watch(shiftsProvider),
              skeleton: const ShiftsListSkeleton(),
              onLoadMore: () => ref.read(shiftsProvider.notifier).loadMore(),
              onRefresh: () => ref.refresh(shiftsProvider.future),
              padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s4, AppSpacing.s16, AppSpacing.s24),
              empty: const EmptyState(
                icon: AppIcons.wallet,
                title: ShiftStrings.noShiftsTitle,
                description: ShiftStrings.noShiftsDescription,
              ),
              itemBuilder: (context, shift) => _ShiftCard(shift: shift, isDark: isDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({required this.shift, required this.isDark});

  final Shift shift;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final difference = shift.cashDifference ?? 0;
    final colors = StatusColors.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.r14),
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
          borderRadius: BorderRadius.circular(AppRadius.r14),
          onTap: () => context.push(AppRoutes.shiftDetail(shift.id)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top row: Shift number, Status badge, Sales Total
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s3),
                      decoration: BoxDecoration(
                        color: shift.isOpen
                            ? AppColors.emerald100
                            : isDark
                                ? AppColors.slate700
                                : AppColors.slate100,
                        borderRadius: BorderRadius.circular(AppRadius.r6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            AppIcons.wallet,
                            size: AppSizes.s12,
                            color: shift.isOpen
                                ? AppColors.emerald600
                                : isDark
                                    ? AppColors.slate300
                                    : AppColors.slate700,
                          ),
                          const SizedBox(width: AppSizes.s4),
                          Text(
                            shift.number,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: shift.isOpen
                                  ? AppColors.emerald600
                                  : isDark
                                      ? AppColors.slate300
                                      : AppColors.slate800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSizes.s8),
                    if (shift.isOpen)
                      const StatusBadge(label: ShiftStrings.openBadge, tone: BadgeTone.success)
                    else if (difference != 0)
                      StatusBadge(
                        label: difference > 0 ? ShiftStrings.overBadge : ShiftStrings.shortBadge,
                        tone: BadgeTone.warning,
                      )
                    else
                      const StatusBadge(label: ShiftStrings.doneBadge, tone: BadgeTone.muted),
                    const Spacer(),
                    Text(
                      rupiah(shift.salesTotal ?? 0),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.emerald600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSizes.s10),

                // Middle: Cashier & Time range
                Row(
                  children: [
                    Icon(AppIcons.user, size: AppSizes.s13, color: isDark ? AppColors.slate400 : AppColors.slate500),
                    const SizedBox(width: AppSizes.s4),
                    Text(
                      shift.cashierName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.slate300 : AppColors.slate700,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6),
                      child: Text('·', style: TextStyle(color: isDark ? AppColors.slate500 : AppColors.slate400)),
                    ),
                    Icon(AppIcons.clock, size: AppSizes.s13, color: isDark ? AppColors.slate400 : AppColors.slate500),
                    const SizedBox(width: AppSizes.s4),
                    Flexible(
                      child: Text(
                        ShiftStrings.shiftTimeRange(dateTime(shift.openedAt), shift.closedAt == null ? null : timeOnly(shift.closedAt!)),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.slate400 : AppColors.slate500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSizes.s10),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark ? AppColors.slate700 : AppColors.slate100,
                ),
                const SizedBox(height: AppSizes.s8),

                // Bottom metrics: Transaction count & Cash Difference or Starting Cash
                Row(
                  children: [
                    Text(
                      ShiftStrings.transactionCount(shift.salesCount ?? 0),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.slate400 : AppColors.slate600,
                      ),
                    ),
                    const Spacer(),
                    if (difference != 0) ...[
                      Text(
                        ShiftStrings.cashDifferenceLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.slate400 : AppColors.slate500,
                        ),
                      ),
                      Text(
                        '${difference > 0 ? '+' : '-'}${rupiah(difference.abs())}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colors.warning,
                        ),
                      ),
                    ] else ...[
                      const Icon(AppIcons.chevronRight, size: AppSizes.s16, color: AppColors.slate400),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
