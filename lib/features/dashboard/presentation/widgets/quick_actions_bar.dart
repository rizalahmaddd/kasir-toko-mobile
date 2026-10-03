import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_routes.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/access.dart';
import '../../../auth/auth_controller.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

class QuickActionsBar extends ConsumerWidget {
  const QuickActionsBar({
    super.key,
    this.lowStockCount = 0,
    this.unpaidReceivablesCount = 0,
  });

  final int lowStockCount;
  final int unpaidReceivablesCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final actions = <({IconData icon, String label, String route, int? badge, Color? badgeColor})>[
      if (user?.canViewStock ?? false)
        (
          icon: AppIcons.packageSearch,
          label: DashboardStrings.quickActionStock,
          route: AppRoutes.stock,
          badge: lowStockCount > 0 ? lowStockCount : null,
          badgeColor: AppColors.amber500,
        ),
      if (user?.canViewSales ?? false)
        (
          icon: AppIcons.receiptText,
          label: DashboardStrings.quickActionSales,
          route: AppRoutes.sales,
          badge: null,
          badgeColor: null,
        ),
      if (user?.canManageReceivables ?? false)
        (
          icon: AppIcons.handCoins,
          label: DashboardStrings.quickActionReceivables,
          route: AppRoutes.receivables,
          badge: unpaidReceivablesCount > 0 ? unpaidReceivablesCount : null,
          badgeColor: AppColors.sky500,
        ),
      if (user?.canManageMasterData ?? false)
        (
          icon: AppIcons.plus,
          label: DashboardStrings.quickActionAddProduct,
          route: AppRoutes.productNew,
          badge: null,
          badgeColor: null,
        ),
      if (user?.canViewSalesReport ?? false)
        (
          icon: AppIcons.trendingUp,
          label: DashboardStrings.quickActionReport,
          route: AppRoutes.reportsSales,
          badge: null,
          badgeColor: null,
        ),
      (
        icon: AppIcons.printer,
        label: DashboardStrings.quickActionPrinter,
        route: AppRoutes.printer,
        badge: null,
        badgeColor: null,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (user?.canSell ?? false) ...[
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.r16),
              gradient: LinearGradient(
                colors: isDark
                    ? const [AppColors.emerald600, AppColors.emerald700]
                    : const [AppColors.emerald500, AppColors.emerald600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.emerald500.withValues(alpha: isDark ? 0.25 : 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.r16),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.r16),
                onTap: () {
                  unawaited(HapticFeedback.lightImpact());
                  context.go(AppRoutes.pos);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s18, vertical: AppSpacing.s14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.s10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppRadius.r12),
                        ),
                        child: const Icon(
                          AppIcons.shoppingCart,
                          size: AppSizes.s22,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: AppSizes.s14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DashboardStrings.openPosTitle,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                            SizedBox(height: AppSizes.s2),
                            Text(
                              DashboardStrings.openPosSubtitle,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.s8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          AppIcons.arrowRight,
                          size: AppSizes.s18,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.s12),
        ],
        if (actions.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                for (final action in actions) ...[
                  _QuickActionChip(
                    icon: action.icon,
                    label: action.label,
                    badge: action.badge,
                    badgeColor: action.badgeColor,
                    onTap: () {
                      unawaited(HapticFeedback.lightImpact());
                      context.push(action.route);
                    },
                  ),
                  const SizedBox(width: AppSizes.s8),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
    this.badgeColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? badge;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(
          color: isDark ? AppColors.slate800 : AppColors.slate200,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.r12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: AppSizes.s16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSizes.s8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.slate200 : AppColors.slate800,
                  ),
                ),
                if (badge != null && badge! > 0) ...[
                  const SizedBox(width: AppSizes.s6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: AppSpacing.s2),
                    decoration: BoxDecoration(
                      color: badgeColor ?? theme.colorScheme.error,
                      borderRadius: BorderRadius.circular(AppRadius.r10),
                    ),
                    child: Text(
                      badge.toString(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
