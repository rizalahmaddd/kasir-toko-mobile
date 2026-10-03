import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../../dashboard/dashboard.dart';
import '../notifications.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';
import 'package:web_pos_mobile/core/theme/app_colors.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _markAll(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(notificationsRepositoryProvider).markAllRead();
      ref
        ..invalidate(notificationsProvider)
        ..invalidate(unreadCountProvider)
        ..invalidate(dashboardProvider);
    } on ApiException catch (error) {
      if (context.mounted) {
        showError(context, error);
      }
    }
  }

  Future<void> _open(BuildContext context, WidgetRef ref, AppNotification notification) async {
    if (notification.isUnread) {
      try {
        await ref.read(notificationsRepositoryProvider).markRead(notification.id);
        ref
          ..invalidate(notificationsProvider)
          ..invalidate(unreadCountProvider)
          ..invalidate(dashboardProvider);
      } on ApiException {
        // Opening the record matters more than the read flag.
      }
    }
    if (context.mounted) {
      openTarget(context, notification.target);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(NotificationStrings.notificationsTitle),
        actions: [
          if (notifications.value?.any((n) => n.isUnread) ?? false)
            TextButton(onPressed: () => _markAll(context, ref), child: const Text(NotificationStrings.markAllRead)),
        ],
      ),
      body: AsyncView(
        value: notifications,
        onRetry: () => ref.invalidate(notificationsProvider),
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(notificationsProvider.future),
          child: items.isEmpty
              ? ListView(children: const [SizedBox(height: AppSizes.s320, child: EmptyState(icon: AppIcons.bellOff, title: NotificationStrings.emptyState))])
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final n = items[i];
                    return _NotificationCard(
                      notification: n,
                      onTap: () => _open(context, ref, n),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final isUnread = notification.isUnread;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s4),
      decoration: BoxDecoration(
        color: isUnread
            ? (isDark ? AppColors.slate800 : AppColors.slate50)
            : (isDark ? AppColors.slate900 : Colors.white),
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(
          color: isUnread
              ? theme.colorScheme.primary.withValues(alpha: 0.4)
              : (isDark ? AppColors.slate700 : AppColors.slate200),
          width: isUnread ? 1.2 : 1.0,
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.r12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isUnread
                        ? theme.colorScheme.primary.withValues(alpha: 0.15)
                        : (isDark ? AppColors.slate700 : AppColors.slate100),
                    borderRadius: BorderRadius.circular(AppRadius.r10),
                  ),
                  child: Icon(
                    isUnread ? AppIcons.bellDot : AppIcons.bell,
                    size: AppSizes.s18,
                    color: isUnread ? theme.colorScheme.primary : muted,
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
                              notification.message,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                                color: isDark ? Colors.white : AppColors.slate900,
                              ),
                            ),
                          ),
                          if (isUnread) ...[
                            const SizedBox(width: AppSizes.s6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSizes.s4),
                      Row(
                        children: [
                          Icon(AppIcons.clock, size: AppSizes.s11, color: muted),
                          const SizedBox(width: AppSizes.s4),
                          Text(
                            dateTime(notification.createdAt),
                            style: TextStyle(fontSize: 11.5, color: muted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSizes.s8),
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.s8),
                  child: Icon(AppIcons.chevronRight, size: AppSizes.s16, color: AppColors.slate400),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
