import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_routes.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/access.dart';
import '../../auth/auth_controller.dart';
import '../../notifications/notifications.dart';
import '../../shift/shift_controller.dart';
import '../dashboard.dart';
import 'widgets/dashboard_stats_grid.dart';
import 'widgets/low_stock_section.dart';
import 'widgets/quick_actions_bar.dart';
import 'widgets/recent_sales_section.dart';
import 'widgets/shift_and_sync_banner.dart';
import 'widgets/today_sales_hero.dart';
import 'widgets/weekly_trend_card.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    return hour < 11
        ? DashboardStrings.greetingMorning
        : (hour < 15
            ? DashboardStrings.greetingAfternoon
            : (hour < 18 ? DashboardStrings.greetingEvening : DashboardStrings.greetingNight));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final unread = dashboard.value?.unreadNotifications ?? 0;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Tooltip(
              message: DashboardStrings.tooltipProfile,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.r20),
                onTap: () {
                  unawaited(HapticFeedback.lightImpact());
                  context.push(AppRoutes.account);
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    (user?.name.characters.take(1).toString() ?? DashboardStrings.avatarInitialFallback).toUpperCase(),
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSizes.s10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          DashboardStrings.greetingLine(_greeting(), user?.name.split(' ').first ?? ''),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (user?.roleLabel != null && user!.roleLabel != '-') ...[
                        const SizedBox(width: AppSizes.s6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: AppSpacing.s1_5),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.slate800 : AppColors.slate200,
                            borderRadius: BorderRadius.circular(AppRadius.r4),
                          ),
                          child: Text(
                            user.roleLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.slate300 : AppColors.slate700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    weekdayDate(DateTime.now()),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: DashboardStrings.tooltipSearch,
            icon: const Icon(AppIcons.search, size: AppSizes.s20),
            onPressed: () {
              unawaited(HapticFeedback.lightImpact());
              context.push(AppRoutes.search);
            },
          ),
          IconButton(
            tooltip: DashboardStrings.tooltipNotifications,
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(AppIcons.bell, size: AppSizes.s20),
            ),
            onPressed: () async {
              unawaited(HapticFeedback.lightImpact());
              await context.push(AppRoutes.notifications);
              ref.invalidate(dashboardProvider);
            },
          ),
          IconButton(
            tooltip: ref.watch(themeModeProvider) == ThemeMode.dark ? DashboardStrings.themeLightTooltip : DashboardStrings.themeDarkTooltip,
            icon: Icon(
              ref.watch(themeModeProvider) == ThemeMode.dark ? AppIcons.sun : AppIcons.moon,
              size: AppSizes.s20,
            ),
            onPressed: () {
              unawaited(HapticFeedback.lightImpact());
              ref.read(themeModeProvider.notifier).toggle();
            },
          ),
        ],
      ),
      body: AsyncView(
        value: dashboard,
        onRetry: () => ref.invalidate(dashboardProvider),
        loading: const DashboardSkeleton(),
        data: (data) {
          final lowStockStat = data.stats.where((s) => s.key == 'low_stock').firstOrNull;
          final lowStockCount = lowStockStat?.count ?? (data.lowStock?.length ?? 0);
          final receivablesStat = data.stats.where((s) => s.key == 'receivables_unpaid').firstOrNull;
          final unpaidReceivablesCount = receivablesStat?.count ?? 0;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(unreadCountProvider);
              if (user?.canSell ?? false) {
                await ref.read(currentShiftProvider.notifier).refresh();
              }
              await ref.read(dashboardProvider.notifier).refresh();
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
              children: [
                MaxWidth(
                  width: 960,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const ShiftAndSyncBanner(),
                      const SizedBox(height: AppSizes.s12),
                      if (data.today != null) ...[
                        TodaySalesHero(today: data.today!),
                        const SizedBox(height: AppSizes.s14),
                      ],
                      QuickActionsBar(
                        lowStockCount: lowStockCount,
                        unpaidReceivablesCount: unpaidReceivablesCount,
                      ),
                      if (data.stats.isNotEmpty) ...[
                        const SizedBox(height: AppSizes.s14),
                        DashboardStatsGrid(stats: data.stats, receivables: data.receivables),
                      ],
                      if (data.weekChart != null && data.weekChart!.isNotEmpty) ...[
                        const SizedBox(height: AppSizes.s14),
                        WeeklyTrendCard(points: data.weekChart!),
                      ],
                      if (data.lowStock != null) ...[
                        const SizedBox(height: AppSizes.s8),
                        LowStockSection(products: data.lowStock!),
                      ],
                      if (data.recentSales != null && data.recentSales!.isNotEmpty) ...[
                        const SizedBox(height: AppSizes.s8),
                        RecentSalesSection(sales: data.recentSales!),
                      ],
                      const SizedBox(height: AppSizes.s24),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
