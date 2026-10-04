import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_routes.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../products/products_providers.dart';
import '../notifications.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';
import 'package:web_pos_mobile/core/theme/app_colors.dart';

typedef SearchItem = ({String label, String? sub, List<String> flags, ({String type, int id})? target});

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  List<SearchGroup> _results = const [];
  bool _loading = false;
  String? _error;
  int _request = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String term) async {
    final request = ++_request;
    if (term.length < 2) {
      setState(() {
        _results = const [];
        _error = null;
        _loading = false;
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
      context.go(AppRoutes.products);
    } else {
      showMessage(context, NotificationStrings.openInWebOnly);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.s16),
          child: SearchField(
            controller: _controller,
            hint: NotificationStrings.searchHint,
            autofocus: true,
            onChanged: (val) => _search(val.trim()),
            onSubmitted: (val) => _search(val.trim()),
          ),
        ),
        bottom: _loading && _results.isNotEmpty
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: _error != null
          ? EmptyState(icon: AppIcons.circleAlert, title: NotificationStrings.searchFailedTitle, description: _error)
          : _loading && _results.isEmpty
              ? const DefaultListSkeleton(itemCount: 6)
              : _results.isEmpty
                  ? EmptyState(
                      icon: AppIcons.search,
                      title: _controller.text.trim().length < 2 ? NotificationStrings.searchMinCharsTitle : NotificationStrings.searchNoResultsTitle,
                      description: NotificationStrings.searchEmptyDescription,
                    )
                  : ListView(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s32),
                  children: [
                    for (final group in _results) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s16, AppSpacing.s6),
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
      final g when g.contains('produk') => (AppColors.teal600, AppIcons.package),
      final g when g.contains('pelanggan') => (AppColors.blue500, AppIcons.user),
      final g when g.contains('transaksi') => (AppColors.emerald500, AppIcons.receipt),
      _ => (AppColors.slate500, AppIcons.search),
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.r12),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.r12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.r10),
                  ),
                  child: Icon(icon, size: AppSizes.s18, color: color),
                ),
                const SizedBox(width: AppSizes.s12),
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
                        const SizedBox(height: AppSizes.s3),
                        Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (item.sub != null)
                              Text(item.sub!, style: TextStyle(fontSize: 12, color: muted)),
                            for (final flag in item.flags)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s5, vertical: AppSpacing.s1),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.slate700 : AppColors.slate100,
                                  borderRadius: BorderRadius.circular(AppRadius.r4),
                                ),
                                child: Text(flag, style: TextStyle(fontSize: 10.5, color: muted, fontWeight: FontWeight.w600)),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(AppIcons.chevronRight, size: AppSizes.s16, color: AppColors.slate400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
