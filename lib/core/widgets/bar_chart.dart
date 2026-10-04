import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/formatters.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({
    super.key,
    required this.points,
    this.height = 180,
    this.money = true,
    this.highlightLast = false,
    this.highlightPredicate,
    this.highlightColor,
  });

  final List<({String label, num value})> points;
  final double height;
  final bool money;
  final bool highlightLast;
  final bool Function(int index)? highlightPredicate;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final muted = theme.colorScheme.onSurfaceVariant;
    final maxValue = points.fold<num>(0, (m, p) => max(m, p.value));
    final top = maxValue == 0 ? 1.0 : maxValue * 1.15;
    final labelEvery = max(1, (points.length / 8).ceil());

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: top.toDouble(),
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: top / 4,
            getDrawingHorizontalLine: (_) => FlLine(color: theme.dividerColor.withValues(alpha: 0.5), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: top / 4,
                getTitlesWidget: (value, meta) => value == meta.max
                    ? const SizedBox.shrink()
                    : Text(compactNumber(value), style: TextStyle(fontSize: 10, color: muted)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= points.length || i % labelEvery != 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.s4),
                    child: Text(points[i].label, style: TextStyle(fontSize: 10, color: muted)),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => theme.colorScheme.surfaceContainerHigh,
              getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                CoreStrings.chartTooltip(points[group.x].label, money ? rupiah(rod.toY) : thousands(rod.toY)),
                TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
          ),
          barGroups: [
            for (final (i, point) in points.indexed)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: point.value.toDouble(),
                    width: points.length > 20 ? 6 : 14,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    color: highlightPredicate != null && highlightPredicate!(i)
                        ? (highlightColor ?? AppColors.amber500)
                        : (highlightLast && i < points.length - 1 ? primary.withValues(alpha: 0.45) : primary),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Labelled horizontal bar showing a share of a total, for breakdown lists.
class ShareBar extends StatelessWidget {
  const ShareBar({super.key, required this.label, required this.value, required this.share, this.caption, this.color});

  final String label;
  final String value;
  final double share;
  final String? caption;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500))),
              Text(value, style: AppTypography.money(fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: AppSizes.s4),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.r4),
            child: LinearProgressIndicator(
              value: share.clamp(0, 1),
              minHeight: 6,
              color: color ?? theme.colorScheme.primary,
              backgroundColor: theme.colorScheme.surfaceContainerHigh,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: AppSizes.s2),
            Text(caption!, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}
