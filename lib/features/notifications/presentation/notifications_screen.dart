import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../notifications.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _markAll(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(notificationsRepositoryProvider).markAllRead();
      ref
        ..invalidate(notificationsProvider)
        ..invalidate(unreadCountProvider);
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
          ..invalidate(unreadCountProvider);
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
    final theme = Theme.of(context);

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
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(indent: 16, endIndent: 16),
                  itemBuilder: (context, i) {
                    final n = items[i];
                    return ListTile(
                      onTap: () => _open(context, ref, n),
                      leading: Icon(
                        n.isUnread ? LucideIcons.bellDot : LucideIcons.bell,
                        size: 20,
                        color: n.isUnread ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                      ),
                      title: Text(n.message, style: TextStyle(fontWeight: n.isUnread ? FontWeight.w600 : FontWeight.w400)),
                      subtitle: Text(dateTime(n.createdAt)),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
