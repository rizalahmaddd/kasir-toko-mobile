import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_routes.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/access.dart';
import '../../../auth/auth_controller.dart';
import '../../../offline/offline_queue.dart';
import '../../../shift/shift_controller.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

class ShiftAndSyncBanner extends ConsumerWidget {
  const ShiftAndSyncBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Check offline pending sales
    final queuedSales = ref.watch(myQueueProvider);
    final syncState = ref.watch(syncStateProvider);

    // Check shift status for cashiers
    final shiftAsync = (user?.canSell ?? false) ? ref.watch(currentShiftProvider) : null;
    final shift = shiftAsync?.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (user?.tenant != null && user!.tenant!.isExpiringSoon) ...[
          SubscriptionExpiringBanner(daysUntilExpiration: user.tenant!.daysUntilExpiration ?? 0),
          const SizedBox(height: AppSizes.s10),
        ],
        if (queuedSales.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.amber600.withValues(alpha: 0.15) : AppColors.amber500.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.r12),
              border: Border.all(
                color: isDark ? AppColors.amber600.withValues(alpha: 0.4) : AppColors.amber500.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  AppIcons.cloudOff,
                  size: AppSizes.s18,
                  color: isDark ? AppColors.amber500 : AppColors.amber600,
                ),
                const SizedBox(width: AppSizes.s10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DashboardStrings.offlineSalesCount(queuedSales.length),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.amber500 : AppColors.amber600,
                        ),
                      ),
                      Text(
                        DashboardStrings.offlineNotSynced,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.slate400 : AppColors.slate600,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s4),
                  ),
                  onPressed: syncState.syncing
                      ? null
                      : () async {
                          unawaited(HapticFeedback.lightImpact());
                          final synced = await ref.read(offlineQueueProvider.notifier).sync(includeFailed: true);
                          if (context.mounted && synced > 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(DashboardStrings.syncSuccess(synced))),
                            );
                          }
                        },
                  icon: syncState.syncing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(AppIcons.refreshCw, size: AppSizes.s14),
                  label: Text(syncState.syncing ? DashboardStrings.syncInProgress : DashboardStrings.syncAction),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.s10),
        ],
        if (user?.canSell ?? false) ...[
          if (shift != null && shift.isOpen) ...[
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate900 : Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.r14),
                border: Border.all(
                  color: isDark ? AppColors.slate800 : AppColors.slate200,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.r14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.r14),
                  onTap: () {
                    unawaited(HapticFeedback.lightImpact());
                    context.push(AppRoutes.shift);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s12),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.emerald500,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppSizes.s10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    DashboardStrings.shiftActiveTitle,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? AppColors.slate200 : AppColors.slate800,
                                    ),
                                  ),
                                  const SizedBox(width: AppSizes.s6),
                                  Text(
                                    DashboardStrings.shiftNumber(shift.number),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.slate400 : AppColors.slate500,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSizes.s2),
                              Text(
                                DashboardStrings.shiftCashSummary(rupiah(shift.openingCash), shift.expectedCash != null ? rupiah(shift.expectedCash!) : null),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.slate400 : AppColors.slate600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.slate800 : AppColors.slate100,
                            borderRadius: BorderRadius.circular(AppRadius.r6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DashboardStrings.manageCashLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.slate300 : AppColors.slate700,
                                ),
                              ),
                              const SizedBox(width: AppSizes.s2),
                              Icon(
                                AppIcons.chevronRight,
                                size: AppSizes.s14,
                                color: isDark ? AppColors.slate400 : AppColors.slate500,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ] else if (shiftAsync != null && !shiftAsync.isLoading && shift == null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate900 : Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.r14),
                border: Border.all(
                  color: isDark ? AppColors.slate800 : AppColors.slate200,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.slate800 : AppColors.slate100,
                      borderRadius: BorderRadius.circular(AppRadius.r10),
                    ),
                    child: Icon(
                      AppIcons.wallet,
                      size: AppSizes.s18,
                      color: isDark ? AppColors.slate400 : AppColors.slate600,
                    ),
                  ),
                  const SizedBox(width: AppSizes.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DashboardStrings.shiftClosedTitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.slate200 : AppColors.slate800,
                          ),
                        ),
                        Text(
                          DashboardStrings.shiftClosedSubtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.slate400 : AppColors.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s6),
                    ),
                    onPressed: () {
                      unawaited(HapticFeedback.lightImpact());
                      context.push(AppRoutes.shift);
                    },
                    child: const Text(DashboardStrings.openShiftButton, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}

/// Banner pengingat masa aktif toko yang mendekati tanggal kedaluwarsa.
class SubscriptionExpiringBanner extends StatelessWidget {
  const SubscriptionExpiringBanner({super.key, required this.daysUntilExpiration});

  final int daysUntilExpiration;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? AppColors.amber500 : AppColors.amber600;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s10),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.amber600 : AppColors.amber500).withValues(alpha: isDark ? 0.15 : 0.12),
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(
          color: (isDark ? AppColors.amber600 : AppColors.amber500).withValues(alpha: isDark ? 0.4 : 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            AppIcons.clockAlert,
            size: AppSizes.s18,
            color: accentColor,
          ),
          const SizedBox(width: AppSizes.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  daysUntilExpiration == 0
                      ? DashboardStrings.subscriptionExpiringToday
                      : DashboardStrings.subscriptionExpiringDays(daysUntilExpiration),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
                Text(
                  DashboardStrings.subscriptionExpiringSubtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.slate400 : AppColors.slate600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

