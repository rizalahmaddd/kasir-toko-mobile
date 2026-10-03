import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_pos_mobile/core/constants/api_endpoints.dart';

import '../../core/network/api_client.dart';
import '../../core/offline/cached_notifier.dart';
import '../../core/utils/json.dart';
import '../products/data/product_models.dart';
import '../sales/data/sale_models.dart';

class DashboardData {
  DashboardData(Map<String, dynamic> json)
      : unreadNotifications = asInt(json['unread_notifications']),
        stats = [
          for (final s in asList(json['stats']))
            (key: s['key'] as String, label: s['label'] as String, count: asInt(s['count'])),
        ],
        today = json['today'] == null ? null : asMap(json['today']),
        receivables = json['receivables'] == null ? null : asMap(json['receivables']),
        weekChart = json['week_chart'] == null ? null : [for (final p in asList(json['week_chart'])) (label: '${p['label']}', value: asInt(p['value']))],
        lowStock = json['low_stock'] == null ? null : asList(json['low_stock']).map(ProductRecord.fromJson).toList(),
        recentSales = json['recent_sales'] == null ? null : asList(json['recent_sales']).map(SaleSummary.fromJson).toList();

  final int unreadNotifications;
  final List<({String key, String label, int count})> stats;
  final Map<String, dynamic>? today;
  final Map<String, dynamic>? receivables;
  final List<({String label, num value})>? weekChart;
  final List<ProductRecord>? lowStock;
  final List<SaleSummary>? recentSales;
}

final dashboardProvider = AsyncNotifierProvider.autoDispose<DashboardNotifier, DashboardData>(DashboardNotifier.new);

class DashboardNotifier extends CachedNotifier<DashboardData> {
  @override
  Future<DashboardData?> loadCache() async {
    final copy = await ref.read(apiClientProvider).offlineCopy(ApiEndpoints.dashboard);
    if (copy == null) {
      return null;
    }
    try {
      return DashboardData(ApiClient.data(copy));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<DashboardData> fetchRemote() async {
    final body = await ref.read(apiClientProvider).get(ApiEndpoints.dashboard);
    return DashboardData(ApiClient.data(body));
  }
}
