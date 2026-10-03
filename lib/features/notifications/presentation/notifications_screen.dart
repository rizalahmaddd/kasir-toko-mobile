import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../../dashboard/dashboard.dart';
import '../notifications.dart';

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
        title: const Text('Notifikasi'),
        actions: [
          if (notifications.value?.any((n) => n.isUnread) ?? false)
            TextButton(onPressed: () => _markAll(context, ref), child: const Text('Tandai semua dibaca')),
        ],
      ),
      body: AsyncView(
        value: notifications,
        onRetry: () => ref.invalidate(notificationsProvider),
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(notificationsProvider.future),
          child: items.isEmpty
              ? ListView(children: const [SizedBox(height: 320, child: EmptyState(icon: LucideIcons.bellOff, title: 'Belum ada notifikasi'))])
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isUnread
            ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC))
            : (isDark ? const Color(0xFF0F172A) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnread
              ? theme.colorScheme.primary.withValues(alpha: 0.4)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isUnread
                        ? theme.colorScheme.primary.withValues(alpha: 0.15)
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isUnread ? LucideIcons.bellDot : LucideIcons.bell,
                    size: 18,
                    color: isUnread ? theme.colorScheme.primary : muted,
                  ),
                ),
                const SizedBox(width: 12),
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
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (isUnread) ...[
                            const SizedBox(width: 6),
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
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(LucideIcons.clock, size: 11, color: muted),
                          const SizedBox(width: 4),
                          Text(
                            dateTime(notification.createdAt),
                            style: TextStyle(fontSize: 11.5, color: muted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Icon(LucideIcons.chevronRight, size: 16, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
