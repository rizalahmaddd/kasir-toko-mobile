import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/network/api_client.dart';
import '../../core/offline/cached_notifier.dart';
import '../../core/paging/paged.dart';
import '../../core/utils/json.dart';

final _apiDate = DateFormat('yyyy-MM-dd');

typedef ProductLine = ({String name, String unit, String category, double qty, int revenue, int profit, double margin});

ProductLine _productLine(Map<String, dynamic> json) => (
      name: json['product_name'] as String? ?? '-',
      unit: json['unit'] as String? ?? '',
      category: json['category_name'] as String? ?? '-',
      qty: asDouble(json['qty']),
      revenue: asInt(json['revenue']),
      profit: asInt(json['profit']),
      margin: asDouble(json['margin']),
    );

class SalesSummaryReport {
  SalesSummaryReport(Map<String, dynamic> json)
      : totals = asMap(json['totals']),
        chart = [for (final p in asList(asMap(json['chart'])['points'])) (label: '${p['label']}', value: asInt(p['value']))],
        payments = [for (final p in asList(json['payments'])) (label: p['label'] as String, total: asInt(p['total']), count: asInt(p['count']))],
        topProducts = asList(json['top_products']).map(_productLine).toList(),
        byCategory = [for (final c in asList(json['by_category'])) (name: c['name'] as String, revenue: asInt(c['revenue']), profit: asInt(c['profit']))],
        byCashier = [for (final c in asList(json['by_cashier'])) (name: c['name'] as String, revenue: asInt(c['revenue']), count: asInt(c['count']))],
        hourly = [for (final h in asList(json['hourly'])) (label: h['hour'] as String, value: asInt(h['revenue']), peak: h['is_peak'] == true)],
        topCustomers = [for (final c in asList(json['top_customers'])) (name: c['name'] as String, revenue: asInt(c['revenue']), count: asInt(c['count']))],
        segments = asMap(json['customer_segments']);

  final Map<String, dynamic> totals;
  final List<({String label, num value})> chart;
  final List<({String label, int total, int count})> payments;
  final List<ProductLine> topProducts;
  final List<({String name, int revenue, int profit})> byCategory;
  final List<({String name, int revenue, int count})> byCashier;
  final List<({String label, int value, bool peak})> hourly;
  final List<({String name, int revenue, int count})> topCustomers;
  final Map<String, dynamic> segments;

  int total(String key) => asInt(totals[key]);
  double ratio(String key) => asDouble(totals[key]);
  double? growth(String key) => totals[key] == null ? null : asDouble(totals[key]);
}

typedef DailyLine = ({DateTime date, int count, double qty, int total, int discount, int profit, double margin});

class DailyReport {
  DailyReport(Map<String, dynamic> json)
      : days = [
          for (final d in asList(json['days']))
            (
              date: DateTime.parse(d['date'] as String),
              count: asInt(d['count']),
              qty: asDouble(d['qty']),
              total: asInt(d['total']),
              discount: asInt(d['discount']),
              profit: asInt(d['profit']),
              margin: asDouble(d['margin']),
            ),
        ],
        summary = asMap(json['summary']);

  final List<DailyLine> days;
  final Map<String, dynamic> summary;
}

class ProductReport {
  ProductReport(Map<String, dynamic> json)
      : products = asList(json['products']).map(_productLine).toList(),
        summary = asMap(json['summary']);

  final List<ProductLine> products;
  final Map<String, dynamic> summary;
}

class Activity {
  Activity(Map<String, dynamic> json)
      : id = json['id'] as int,
        logName = json['log_name'] as String?,
        event = json['event_label'] as String? ?? json['event'] as String?,
        description = json['description'] as String? ?? '',
        subject = json['subject_label'] as String?,
        causer = asMap(json['causer'])['name'] as String?,
        changes = asMap(json['changes']),
        reason = json['reason'] as String?,
        ipAddress = json['ip_address'] as String?,
        createdAt = DateTime.parse(json['created_at'] as String);

  final int id;
  final String? logName;
  final String? event;
  final String description;
  final String? subject;
  final String? causer;
  final Map<String, dynamic> changes;
  final String? reason;
  final String? ipAddress;
  final DateTime createdAt;
}

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) => ReportsRepository(ref.watch(apiClientProvider)));

class ReportsRepository {
  ReportsRepository(this._api);

  final ApiClient _api;

  Map<String, dynamic> _range(DateTimeRange range) => {'from': _apiDate.format(range.start), 'to': _apiDate.format(range.end)};

  Future<SalesSummaryReport> summary(DateTimeRange range) async =>
      SalesSummaryReport(ApiClient.data(await _api.get('reports/sales/summary', query: _range(range))));

  Future<SalesSummaryReport?> getCachedSummary(DateTimeRange range) async {
    final copy = await _api.offlineCopy('reports/sales/summary', query: _range(range));
    if (copy == null) return null;
    try {
      return SalesSummaryReport(ApiClient.data(copy));
    } catch (_) {
      return null;
    }
  }

  Future<DailyReport> daily(DateTimeRange range) async => DailyReport(ApiClient.data(await _api.get('reports/sales/daily', query: _range(range))));

  Future<DailyReport?> getCachedDaily(DateTimeRange range) async {
    final copy = await _api.offlineCopy('reports/sales/daily', query: _range(range));
    if (copy == null) return null;
    try {
      return DailyReport(ApiClient.data(copy));
    } catch (_) {
      return null;
    }
  }

  Future<ProductReport> products(DateTimeRange range, {required String sort, String? search}) async => ProductReport(
        ApiClient.data(await _api.get('reports/sales/products', query: {..._range(range), 'sort': sort, 'direction': 'desc', 'search': search})),
      );

  Future<ProductReport?> getCachedProducts(DateTimeRange range, {required String sort, String? search}) async {
    final copy = await _api.offlineCopy('reports/sales/products', query: {..._range(range), 'sort': sort, 'direction': 'desc', 'search': search});
    if (copy == null) return null;
    try {
      return ProductReport(ApiClient.data(copy));
    } catch (_) {
      return null;
    }
  }

  Future<Paginated<Activity>> activity({String? search, String? logName, int page = 1}) async => Paginated.fromJson(
        await _api.get('reports/activity-log', query: {'search': search, 'log_name': logName, 'page': page, 'per_page': 30}),
        Activity.new,
      );
}

DateTimeRange todayRange() {
  final today = DateUtils.dateOnly(DateTime.now());
  return DateTimeRange(start: today, end: today);
}

final reportRangeProvider = NotifierProvider<QueryNotifier<DateTimeRange>, DateTimeRange>(() {
  final today = DateUtils.dateOnly(DateTime.now());
  return QueryNotifier(DateTimeRange(start: DateTime(today.year, today.month), end: today));
});

final salesSummaryProvider = AsyncNotifierProvider.autoDispose<SalesSummaryNotifier, SalesSummaryReport>(SalesSummaryNotifier.new);

class SalesSummaryNotifier extends CachedNotifier<SalesSummaryReport> {
  @override
  Future<SalesSummaryReport?> loadCache() {
    final range = ref.watch(reportRangeProvider);
    return ref.read(reportsRepositoryProvider).getCachedSummary(range);
  }

  @override
  Future<SalesSummaryReport> fetchRemote() {
    final range = ref.watch(reportRangeProvider);
    return ref.read(reportsRepositoryProvider).summary(range);
  }
}

final dailyReportProvider = AsyncNotifierProvider.autoDispose<DailyReportNotifier, DailyReport>(DailyReportNotifier.new);

class DailyReportNotifier extends CachedNotifier<DailyReport> {
  @override
  Future<DailyReport?> loadCache() {
    final range = ref.watch(reportRangeProvider);
    return ref.read(reportsRepositoryProvider).getCachedDaily(range);
  }

  @override
  Future<DailyReport> fetchRemote() {
    final range = ref.watch(reportRangeProvider);
    return ref.read(reportsRepositoryProvider).daily(range);
  }
}

typedef ProductReportQuery = ({String sort, String search});

final productReportQueryProvider = NotifierProvider<QueryNotifier<ProductReportQuery>, ProductReportQuery>(() => QueryNotifier((sort: 'revenue', search: '')));

final productReportProvider = AsyncNotifierProvider.autoDispose<ProductReportNotifier, ProductReport>(ProductReportNotifier.new);

class ProductReportNotifier extends CachedNotifier<ProductReport> {
  @override
  Future<ProductReport?> loadCache() {
    final range = ref.watch(reportRangeProvider);
    final query = ref.watch(productReportQueryProvider);
    return ref.read(reportsRepositoryProvider).getCachedProducts(range, sort: query.sort, search: query.search);
  }

  @override
  Future<ProductReport> fetchRemote() {
    final range = ref.watch(reportRangeProvider);
    final query = ref.watch(productReportQueryProvider);
    return ref.read(reportsRepositoryProvider).products(range, sort: query.sort, search: query.search);
  }
}

typedef ActivityQuery = ({String search, String? logName});

final activityQueryProvider = NotifierProvider<QueryNotifier<ActivityQuery>, ActivityQuery>(() => QueryNotifier((search: '', logName: null)));

final activityProvider = AsyncNotifierProvider<ActivityNotifier, PagedState<Activity>>(ActivityNotifier.new);

class ActivityNotifier extends PagedNotifier<Activity> {
  @override
  Future<Paginated<Activity>> fetch(int page) {
    final query = ref.watch(activityQueryProvider);
    return ref.read(reportsRepositoryProvider).activity(search: query.search, logName: query.logName, page: page);
  }
}
