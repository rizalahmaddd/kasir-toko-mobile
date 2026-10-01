import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';
import '../../../core/widgets/bar_chart.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/access.dart';
import '../../auth/auth_controller.dart';
import '../../notifications/notifications.dart';
import '../../products/presentation/product_widgets.dart';
import '../../sales/presentation/sale_tile.dart';
import '../dashboard.dart';

const _statRoutes = {'customers_active': '/customers', 'low_stock': '/stock', 'receivables_unpaid': '/receivables'};
const _statIcons = {'customers_active': LucideIcons.users, 'low_stock': LucideIcons.triangleAlert, 'receivables_unpaid': LucideIcons.handCoins};

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    return hour < 11 ? 'Selamat pagi' : (hour < 15 ? 'Selamat siang' : (hour < 18 ? 'Selamat sore' : 'Selamat malam'));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    final user = ref.watch(currentUserProvider);
    final unread = dashboard.value?.unreadNotifications ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_greeting()}, ${user?.name.split(' ').first ?? ''}'),
            Text(dateOnly(DateTime.now()), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
        actions: [
          IconButton(tooltip: 'Cari', icon: const Icon(LucideIcons.search, size: 20), onPressed: () => context.push('/search')),
          IconButton(
            tooltip: 'Notifikasi',
            icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(LucideIcons.bell, size: 20)),
            onPressed: () async {
              await context.push('/notifications');
              ref.invalidate(dashboardProvider);
            },
          ),
        ],
      ),
      body: AsyncView(
        value: dashboard,
        onRetry: () => ref.invalidate(dashboardProvider),
        data: (data) => RefreshIndicator(
          onRefresh: () {
            ref.invalidate(unreadCountProvider);
            return ref.refresh(dashboardProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              MaxWidth(
                width: 960,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (data.today != null) _TodayPanel(today: data.today!),
                    if (user?.canSell ?? false) ...[
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                        onPressed: () => context.go('/pos'),
                        icon: const Icon(LucideIcons.shoppingCart, size: 20),
                        label: const Text('Buka Kasir'),
                      ),
                    ],
                    if (data.stats.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 600 ? 3 : 2;
                          final width = (constraints.maxWidth - 8 * (columns - 1)) / columns;
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final stat in data.stats)
                                SizedBox(
                                  width: width,
                                  child: StatTile(
                                    label: stat.label,
                                    value: thousands(stat.count),
                                    icon: _statIcons[stat.key],
                                    caption: stat.key == 'receivables_unpaid' && data.receivables != null
                                        ? rupiah(asInt(data.receivables!['total_due']))
                                        : null,
                                    color: stat.key == 'low_stock' && stat.count > 0 ? StatusColors.of(context).warning : null,
                                    onTap: _statRoutes[stat.key] == null ? null : () => context.push(_statRoutes[stat.key]!),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                    if (data.weekChart != null) ...[
                      const SectionTitle('Omzet 7 hari'),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                          child: SimpleBarChart(points: data.weekChart!, height: 170, highlightLast: true),
                        ),
                      ),
                    ],
                    if (data.lowStock != null && data.lowStock!.isNotEmpty) ...[
                      SectionTitle(
                        'Stok menipis',
                        trailing: TextButton(onPressed: () => context.push('/stock'), child: const Text('Lihat semua')),
                      ),
                      Card(
                        child: Column(
                          children: [
                            for (final product in data.lowStock!)
                              ProductTile(product: product, showPrice: false, onTap: () => context.push('/product/${product.id}')),
                          ],
                        ),
                      ),
                    ],
                    if (data.recentSales != null && data.recentSales!.isNotEmpty) ...[
                      SectionTitle(
                        'Transaksi terakhir',
                        trailing: TextButton(onPressed: () => context.go('/sales'), child: const Text('Lihat semua')),
                      ),
                      Card(child: Column(children: [for (final sale in data.recentSales!) SaleTile(sale: sale)])),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayPanel extends StatelessWidget {
  const _TodayPanel({required this.today});

  final Map<String, dynamic> today;

  @override
  Widget build(BuildContext context) {
    final revenue = asInt(today['revenue']);
    final yesterday = asInt(today['yesterday']);
    final profit = today['profit'] == null ? null : asInt(today['profit']);
    final diff = yesterday == 0 ? null : (revenue - yesterday) / yesterday * 100;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(colors: [AppColors.slate900, AppColors.slate800], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Penjualan hari ini', style: TextStyle(color: AppColors.slate400)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(rupiah(revenue), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              Text('${asInt(today['count'])} transaksi', style: const TextStyle(color: AppColors.slate300)),
              if (profit != null) Text('Laba ${rupiah(profit)}', style: const TextStyle(color: AppColors.emerald400)),
              Text(
                diff == null ? 'Kemarin ${rupiah(yesterday)}' : '${diff >= 0 ? '▲' : '▼'} ${percent(diff.abs())} dari kemarin',
                style: TextStyle(color: diff == null || diff >= 0 ? AppColors.slate300 : AppColors.amber500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
