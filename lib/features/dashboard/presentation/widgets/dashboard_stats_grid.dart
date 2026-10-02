import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/json.dart';

const _statRoutes = {
  'customers_active': '/customers',
  'low_stock': '/stock',
  'receivables_unpaid': '/receivables',
};

const _statIcons = {
  'customers_active': LucideIcons.users,
  'low_stock': LucideIcons.triangleAlert,
  'receivables_unpaid': LucideIcons.handCoins,
};

class DashboardStatsGrid extends StatelessWidget {
  const DashboardStatsGrid({
    super.key,
    required this.stats,
    this.receivables,
  });

  final List<({String key, String label, int count})> stats;
  final Map<String, dynamic>? receivables;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth >= 600;

        // On tablet/desktop (>= 600px), display all stats side-by-side (up to 3 columns)
        if (isWideScreen) {
          final columns = stats.length >= 3 ? 3 : stats.length;
          final width = (constraints.maxWidth - 10 * (columns - 1)) / columns;

          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final stat in stats)
                SizedBox(
                  width: width,
                  height: 118,
                  child: _GridStatCard(
                    label: stat.label,
                    value: thousands(stat.count),
                    icon: _statIcons[stat.key],
                    caption: _captionFor(stat.key, stat.count),
                    color: _colorFor(stat.key, stat.count, isDark),
                    onTap: _onTapFor(context, stat.key),
                  ),
                ),
            ],
          );
        }

        // On mobile (< 600px):
        // If there are exactly 3 stats (or an odd count), the last item spans full width
        // so there is no awkward empty space on row 2.
        final hasOddLastItem = stats.length % 2 == 1 && stats.length > 1;
        final halfWidth = (constraints.maxWidth - 10) / 2;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              if (hasOddLastItem && i == stats.length - 1)
                SizedBox(
                  width: constraints.maxWidth,
                  child: _WideStatCard(
                    label: stats[i].label,
                    value: thousands(stats[i].count),
                    icon: _statIcons[stats[i].key],
                    caption: _captionFor(stats[i].key, stats[i].count),
                    color: _colorFor(stats[i].key, stats[i].count, isDark),
                    onTap: _onTapFor(context, stats[i].key),
                  ),
                )
              else
                SizedBox(
                  width: stats.length == 1 ? constraints.maxWidth : halfWidth,
                  height: 118,
                  child: _GridStatCard(
                    label: stats[i].label,
                    value: thousands(stats[i].count),
                    icon: _statIcons[stats[i].key],
                    caption: _captionFor(stats[i].key, stats[i].count),
                    color: _colorFor(stats[i].key, stats[i].count, isDark),
                    onTap: _onTapFor(context, stats[i].key),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  String? _captionFor(String key, int count) {
    if (key == 'receivables_unpaid' && receivables != null) {
      return 'Total ${rupiah(asInt(receivables!['total_due']))}';
    }
    if (key == 'low_stock' && count > 0) {
      return 'Perlu restock segera';
    }
    return 'Lihat daftar detail';
  }

  Color? _colorFor(String key, int count, bool isDark) {
    if (key == 'low_stock' && count > 0) {
      return isDark ? AppColors.amber500 : AppColors.amber600;
    }
    if (key == 'receivables_unpaid' && count > 0) {
      return isDark ? AppColors.sky500 : AppColors.sky600;
    }
    return null;
  }

  VoidCallback? _onTapFor(BuildContext context, String key) {
    final route = _statRoutes[key];
    if (route == null) return null;
    return () {
      unawaited(HapticFeedback.lightImpact());
      context.push(route);
    };
  }
}

class _GridStatCard extends StatelessWidget {
  const _GridStatCard({
    required this.label,
    required this.value,
    this.caption,
    this.icon,
    this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final String? caption;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final accent = color ?? theme.colorScheme.primary;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: isDark ? 0.2 : 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 16, color: accent),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.slate300 : AppColors.slate700,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: color ?? (isDark ? Colors.white : AppColors.slate900),
                        fontFeatures: const [FontFeature.tabularFigures()],
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  if (caption != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      caption!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: color ?? muted,
                        fontWeight: color != null ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WideStatCard extends StatelessWidget {
  const _WideStatCard({
    required this.label,
    required this.value,
    this.caption,
    this.icon,
    this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final String? caption;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final accent = color ?? theme.colorScheme.primary;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: accent),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.slate200 : AppColors.slate800,
                      ),
                    ),
                    if (caption != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        caption!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: color != null ? FontWeight.w600 : FontWeight.w400,
                          color: color ?? muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: color ?? (isDark ? Colors.white : AppColors.slate900),
                      fontFeatures: const [FontFeature.tabularFigures()],
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: isDark ? AppColors.slate500 : AppColors.slate400,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
