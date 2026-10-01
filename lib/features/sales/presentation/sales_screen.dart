import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../data/sale_models.dart';
import 'sale_tile.dart';
import '../sales_controller.dart';

const _statuses = [(null, 'Semua'), ('completed', 'Selesai'), ('credit', 'Kasbon'), ('voided', 'Dibatalkan')];

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        ref.read(salesProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  SalesFilter get _filter => ref.read(salesFilterProvider);

  void _apply(SalesFilter filter) => ref.read(salesFilterProvider.notifier).update(filter);

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _filter.range,
    );
    if (range != null) {
      _apply(_filter.copyWith(range: range));
    }
  }

  String _rangeLabel(DateTimeRange range) {
    final today = DateUtils.dateOnly(DateTime.now());
    if (range.start == range.end) {
      if (range.start == today) {
        return 'Hari ini';
      }
      if (range.start == today.subtract(const Duration(days: 1))) {
        return 'Kemarin';
      }
      return dateOnly(range.start);
    }
    return '${dateOnly(range.start)} – ${dateOnly(range.end)}';
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(salesFilterProvider);
    final sales = ref.watch(salesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat transaksi'),
        actions: [
          TextButton.icon(onPressed: _pickRange, icon: const Icon(LucideIcons.calendar, size: 18), label: Text(_rangeLabel(filter.range))),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'No. transaksi, pelanggan, atau nama barang',
                prefixIcon: Icon(LucideIcons.search, size: 18),
              ),
              onChanged: (value) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), () => _apply(_filter.copyWith(search: value.trim())));
              },
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final (value, label) in _statuses)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: filter.status == value,
                      showCheckmark: false,
                      onSelected: (_) => _apply(value == null ? filter.copyWith(clearStatus: true) : filter.copyWith(status: value)),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AsyncView(
              value: sales,
              onRetry: () => ref.invalidate(salesProvider),
              data: (state) => RefreshIndicator(
                onRefresh: () => ref.refresh(salesProvider.future),
                child: CustomScrollView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _Summary(page: state.page)),
                    if (state.page.items.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(
                          icon: LucideIcons.receiptText,
                          title: 'Belum ada transaksi',
                          description: 'Tidak ada transaksi di rentang tanggal dan filter ini.',
                        ),
                      )
                    else
                      SliverList.separated(
                        itemCount: state.page.items.length,
                        separatorBuilder: (_, _) => const Divider(indent: 16, endIndent: 16),
                        itemBuilder: (context, index) => SaleTile(sale: state.page.items[index]),
                      ),
                    if (state.loadingMore)
                      const SliverToBoxAdapter(
                        child: Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.page});

  final SalesPage page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total penjualan', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                Text(rupiah(page.total), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${page.count} transaksi', style: const TextStyle(fontWeight: FontWeight.w600)),
              if (page.voided > 0) Text('${page.voided} dibatalkan', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
            ],
          ),
        ],
      ),
    );
  }
}
