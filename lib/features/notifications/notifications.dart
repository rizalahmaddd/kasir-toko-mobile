import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web_pos_mobile/core/constants/api_endpoints.dart';
import 'package:web_pos_mobile/core/constants/app_routes.dart';
import 'package:web_pos_mobile/core/constants/status_values.dart';

import '../../core/network/api_client.dart';
import '../../core/offline/cached_notifier.dart';
import '../../core/utils/json.dart';

class AppNotification {
  AppNotification(Map<String, dynamic> json)
      : id = json['id'] as String,
        message = json['message'] as String? ?? '',
        color = json['color'] as String?,
        target = json['target'] == null ? null : (type: asMap(json['target'])['type'] as String, id: asInt(asMap(json['target'])['id'])),
        readAt = asDate(json['read_at']),
        createdAt = DateTime.parse(json['created_at'] as String);

  final String id;
  final String message;
  final String? color;
  final ({String type, int id})? target;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isUnread => readAt == null;
}

class SearchGroup {
  SearchGroup(Map<String, dynamic> json)
      : group = json['group'] as String,
        items = [
          for (final i in asList(json['items']))
            (
              label: i['label'] as String,
              sub: i['sub'] as String?,
              flags: [for (final f in asList(i['flags'])) f['label'] as String],
              target: i['target'] == null ? null : (type: asMap(i['target'])['type'] as String, id: asInt(asMap(i['target'])['id'])),
            ),
        ];

  final String group;
  final List<({String label, String? sub, List<String> flags, ({String type, int id})? target})> items;
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) => NotificationsRepository(ref.watch(apiClientProvider)));

class NotificationsRepository {
  NotificationsRepository(this._api);

  final ApiClient _api;

  Future<List<AppNotification>> list() async => ApiClient.list(await _api.get(ApiEndpoints.notifications)).map(AppNotification.new).toList();

  Future<List<AppNotification>?> getCachedList() async {
    final copy = await _api.offlineCopy(ApiEndpoints.notifications);
    if (copy == null) return null;
    try {
      return ApiClient.list(copy).map(AppNotification.new).toList();
    } catch (_) {
      return null;
    }
  }

  Future<int> unreadCount() async => asInt(ApiClient.data(await _api.get(ApiEndpoints.notificationsUnreadCount))['unread_count']);

  Future<void> markRead(String id) => _api.post(ApiEndpoints.notificationRead(id));

  Future<void> markAllRead() => _api.post(ApiEndpoints.notificationsReadAll);

  Future<List<SearchGroup>> search(String term) async => ApiClient.list(await _api.get(ApiEndpoints.search, query: {'q': term})).map(SearchGroup.new).toList();
}

final notificationsProvider = AsyncNotifierProvider.autoDispose<NotificationsNotifier, List<AppNotification>>(NotificationsNotifier.new);

class NotificationsNotifier extends CachedNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>?> loadCache() => ref.read(notificationsRepositoryProvider).getCachedList();

  @override
  Future<List<AppNotification>> fetchRemote() => ref.read(notificationsRepositoryProvider).list();
}

final unreadCountProvider = FutureProvider<int>((ref) => ref.watch(notificationsRepositoryProvider).unreadCount());

/// Opens the record an API `target` points to; returns false when the app has no screen for it.
bool openTarget(BuildContext context, ({String type, int id})? target) {
  final path = switch (target?.type) {
    NotificationTargets.sale => AppRoutes.saleDetail(target!.id),
    NotificationTargets.customer => AppRoutes.customerDetail(target!.id),
    NotificationTargets.shift => AppRoutes.shiftDetail(target!.id),
    _ => null,
  };
  if (path != null) {
    context.push(path);
  }

  return path != null;
}
