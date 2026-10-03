import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_routes.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/access.dart';
import '../../auth/auth_controller.dart';
import '../../notifications/notifications.dart';
import '../../offline/offline_queue.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

typedef _Link = ({
  IconData icon,
  String label,
  String path,
  String? caption,
  Color color,
  int? badgeCount,
  Color? badgeColor,
});

class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    final waiting = ref.watch(myQueueProvider).length;

    final sections = <(String, List<_Link>)>[
      (
        HomeStrings.menuSectionSales,
        [
          if (user.canSell)
            (
              icon: AppIcons.wallet,
              label: HomeStrings.menuShiftMineLabel,
              path: AppRoutes.shift,
              caption: HomeStrings.menuShiftMineCaption,
              color: AppColors.emerald500,
              badgeCount: null,
              badgeColor: null,
            ),
          if (user.canSell)
            (
              icon: AppIcons.cloudOff,
              label: HomeStrings.menuOfflineLabel,
              path: AppRoutes.offline,
              caption: waiting > 0 ? HomeStrings.menuOfflineQueueCaption(waiting) : HomeStrings.menuOfflineCaption,
              color: AppColors.amber500,
              badgeCount: waiting > 0 ? waiting : null,
              badgeColor: AppColors.amber500,
            ),
          if (user.canViewShifts)
            (
              icon: AppIcons.history,
              label: HomeStrings.menuShiftHistoryLabel,
              path: AppRoutes.shifts,
              caption: HomeStrings.menuShiftHistoryCaption,
              color: AppColors.teal600,
              badgeCount: null,
              badgeColor: null,
            ),
          if (user.canManageReceivables)
            (
              icon: AppIcons.handCoins,
              label: HomeStrings.menuReceivablesLabel,
              path: AppRoutes.receivables,
              caption: HomeStrings.menuReceivablesCaption,
              color: AppColors.amber600,
              badgeCount: null,
              badgeColor: null,
            ),
        ],
      ),
      (
        HomeStrings.menuSectionProductsStock,
        [
          if (user.canViewCategories)
            (
              icon: AppIcons.tags,
              label: HomeStrings.menuCategoriesLabel,
              path: AppRoutes.categories,
              caption: HomeStrings.menuCategoriesCaption,
              color: AppColors.cyan500,
              badgeCount: null,
              badgeColor: null,
            ),
          if (user.canViewStock)
            (
              icon: AppIcons.warehouse,
              label: HomeStrings.menuStockLabel,
              path: AppRoutes.stock,
              caption: HomeStrings.menuStockCaption,
              color: AppColors.blue500,
              badgeCount: null,
              badgeColor: null,
            ),
          if (user.canViewStock)
            (
              icon: AppIcons.scrollText,
              label: HomeStrings.menuStockCardLabel,
              path: AppRoutes.stockMovements,
              caption: HomeStrings.menuStockCardCaption,
              color: AppColors.indigo500,
              badgeCount: null,
              badgeColor: null,
            ),
          if (user.canViewCustomers)
            (
              icon: AppIcons.users,
              label: HomeStrings.menuCustomersLabel,
              path: AppRoutes.customers,
              caption: HomeStrings.menuCustomersCaption,
              color: AppColors.violet500,
              badgeCount: null,
              badgeColor: null,
            ),
        ],
      ),
      (
        HomeStrings.menuSectionReportsActivity,
        [
          if (user.canViewSalesReport)
            (
              icon: AppIcons.trendingUp,
              label: HomeStrings.menuSalesReportLabel,
              path: AppRoutes.reportsSales,
              caption: HomeStrings.menuSalesReportCaption,
              color: AppColors.emerald500,
              badgeCount: null,
              badgeColor: null,
            ),
          if (user.canViewActivityLog)
            (
              icon: AppIcons.fileClock,
              label: HomeStrings.menuActivityLogLabel,
              path: AppRoutes.activity,
              caption: HomeStrings.menuActivityLogCaption,
              color: AppColors.slate500,
              badgeCount: null,
              badgeColor: null,
            ),
        ],
      ),
      (
        HomeStrings.menuSectionSettingsOthers,
        [
          (
            icon: AppIcons.search,
            label: HomeStrings.menuGlobalSearchLabel,
            path: AppRoutes.search,
            caption: HomeStrings.menuGlobalSearchCaption,
            color: AppColors.slate500,
            badgeCount: null,
            badgeColor: null,
          ),
          (
            icon: AppIcons.bell,
            label: HomeStrings.menuNotificationsLabel,
            path: AppRoutes.notifications,
            caption: unread > 0 ? HomeStrings.menuNotificationsCaption(unread) : HomeStrings.menuNotificationsCaptionEmpty,
            color: AppColors.red500,
            badgeCount: unread > 0 ? unread : null,
            badgeColor: AppColors.red500,
          ),
          if (user.isSuperadmin && user.tenant != null)
            (
              icon: AppIcons.store,
              label: HomeStrings.menuStorePresetLabel,
              path: AppRoutes.onboarding,
              caption: HomeStrings.menuStorePresetCaption,
              color: AppColors.sky500,
              badgeCount: null,
              badgeColor: null,
            ),
          (
            icon: AppIcons.printer,
            label: HomeStrings.menuReceiptPrinterLabel,
            path: AppRoutes.printer,
            caption: HomeStrings.menuReceiptPrinterCaption,
            color: AppColors.sky600,
            badgeCount: null,
            badgeColor: null,
          ),
          if (user.canManagePosSettings)
            (
              icon: AppIcons.slidersHorizontal,
              label: HomeStrings.menuPosSettingsLabel,
              path: AppRoutes.posSettings,
              caption: HomeStrings.menuPosSettingsCaption,
              color: AppColors.indigo500,
              badgeCount: null,
              badgeColor: null,
            ),
          (
            icon: AppIcons.circleUser,
            label: HomeStrings.menuAccountLabel,
            path: AppRoutes.account,
            caption: HomeStrings.menuAccountCaption,
            color: AppColors.indigo500,
            badgeCount: null,
            badgeColor: null,
          ),
        ],
      ),
    ];

    final query = _search.trim().toLowerCase();
    final filteredSections = query.isEmpty
        ? sections
        : [
            for (final (title, links) in sections)
              (
                title,
                links
                    .where((l) =>
                        title.toLowerCase().contains(query) ||
                        l.label.toLowerCase().contains(query) ||
                        (l.caption?.toLowerCase().contains(query) ?? false))
                    .toList(),
              ),
          ];
    final hasResults = filteredSections.any((s) => s.$2.isNotEmpty);

    return Scaffold(
      appBar: SearchableAppBar(
        title: const Text(HomeStrings.menuTitle),
        hint: HomeStrings.menuSearchHint,
        initialSearch: _search,
        onSearchChanged: (val) => setState(() => _search = val),
        onSearchClosed: () => setState(() => _search = ''),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(unreadCountProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s4, AppSpacing.s16, AppSpacing.s32),
          children: [
            MaxWidth(
              width: 640,
              child: hasResults
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (title, links) in filteredSections)
                          if (links.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(left: AppSpacing.s4, top: AppSpacing.s14, bottom: AppSpacing.s8),
                              child: Text(
                                title.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.slate800 : Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.r16),
                          border: Border.all(
                            color: isDark ? AppColors.slate700 : AppColors.slate200,
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
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (final (i, link) in links.indexed) ...[
                              if (i > 0)
                                Divider(
                                  height: 1,
                                  indent: 60,
                                  color: isDark ? AppColors.slate700 : AppColors.slate100,
                                ),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => context.push(link.path),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s12),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            color: link.color.withValues(alpha: isDark ? 0.2 : 0.12),
                                            borderRadius: BorderRadius.circular(AppRadius.r10),
                                          ),
                                          child: Icon(link.icon, size: AppSizes.s19, color: link.color),
                                        ),
                                        const SizedBox(width: AppSizes.s14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                link.label,
                                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                              ),
                                              if (link.caption != null) ...[
                                                const SizedBox(height: AppSizes.s2),
                                                Text(
                                                  link.caption!,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: theme.colorScheme.onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        if (link.badgeCount != null) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s2),
                                            decoration: BoxDecoration(
                                              color: (link.badgeColor ?? theme.colorScheme.primary).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(AppRadius.r10),
                                            ),
                                            child: Text(
                                              '${link.badgeCount}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: link.badgeColor ?? theme.colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: AppSizes.s6),
                                        ],
                                        const Icon(AppIcons.chevronRight, size: AppSizes.s16, color: AppColors.slate400),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                ],
              )
              : Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s48),
                  child: EmptyState(
                    icon: AppIcons.searchX,
                    title: HomeStrings.menuSearchEmptyTitle,
                    description: HomeStrings.menuSearchEmptyDescription(_search),
                  ),
                ),
            ),
          ],
        ),
      ),
    );
  }
}
