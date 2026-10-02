import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../products/products_providers.dart';
import '../notifications.dart';

typedef SearchItem = ({String label, String? sub, List<String> flags, ({String type, int id})? target});

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<SearchGroup> _results = const [];
  bool _loading = false;
  String? _error;
  int _request = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value.trim()));
  }

  Future<void> _search(String term) async {
    final request = ++_request;
    if (term.length < 2) {
      setState(() {
        _results = const [];
        _error = null;
      });
      return;
    }

    setState(() => _loading = true);
    try {
      final results = await ref.read(notificationsRepositoryProvider).search(term);
      if (mounted && request == _request) {
        setState(() {
          _results = results;
          _error = null;
        });
      }
    } on ApiException catch (error) {
      if (mounted && request == _request) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted && request == _request) {
        setState(() => _loading = false);
      }
    }
  }

  /// Products come back without a target, so open the product list filtered to the name instead.
  void _open(String group, String label, ({String type, int id})? target) {
    if (openTarget(context, target)) {
      return;
    }
    if (group.toLowerCase().contains('produk')) {
      final query = ref.read(productsQueryProvider);
      ref.read(productsQueryProvider.notifier).set((search: label, categoryId: null, status: null, sort: query.sort));
      context.go('/products');
    } else {
      showMessage(context, 'Data ini hanya bisa dibuka di aplikasi web.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Container(
          height: 42,
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.search, size: 18, color: Color(0xFF94A3B8)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  onChanged: (val) {
                    setState(() {});
                    _changed(val);
                  },
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Cari produk, transaksi, pelanggan…',
                    hintStyle: TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (_controller.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _controller.clear();
                    setState(() {
                      _results = const [];
                      _error = null;
                    });
                  },
                  child: const Icon(LucideIcons.x, size: 16, color: Color(0xFF94A3B8)),
                ),
            ],
          ),
        ),
        bottom: _loading ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2)) : null,
      ),
      body: _error != null
          ? EmptyState(icon: LucideIcons.circleAlert, title: 'Pencarian gagal', description: _error)
          : _results.isEmpty
              ? EmptyState(
                  icon: LucideIcons.search,
                  title: _controller.text.trim().length < 2 ? 'Ketik minimal 2 huruf' : 'Tidak ada hasil',
                  description: 'Cari produk berdasarkan nama, kode, nomor nota, atau nama pelanggan.',
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    for (final group in _results) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                        child: SectionTitle(group.group),
                      ),
                      for (final item in group.items)
                        _SearchResultCard(
                          groupName: group.group,
                          item: item,
                          onTap: () => _open(group.group, item.label, item.target),
                        ),
                    ],
                  ],
                ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.groupName,
    required this.item,
    required this.onTap,
  });

  final String groupName;
  final SearchItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final lower = groupName.toLowerCase();

    final (color, icon) = switch (lower) {
      final g when g.contains('produk') => (const Color(0xFF0D9488), LucideIcons.package),
      final g when g.contains('pelanggan') => (const Color(0xFF3B82F6), LucideIcons.user),
      final g when g.contains('transaksi') => (const Color(0xFF10B981), LucideIcons.receipt),
      _ => (const Color(0xFF64748B), LucideIcons.search),
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
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
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.sub != null || item.flags.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (item.sub != null)
                              Text(item.sub!, style: TextStyle(fontSize: 12, color: muted)),
                            for (final flag in item.flags)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(flag, style: TextStyle(fontSize: 10.5, color: muted, fontWeight: FontWeight.w600)),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(LucideIcons.chevronRight, size: 16, color: Color(0xFF94A3B8)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
