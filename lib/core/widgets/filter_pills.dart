import 'package:flutter/material.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';

import '../constants/status_values.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';
import 'package:web_pos_mobile/core/theme/app_durations.dart';

/// A sleek, compact dropdown filter pill for mobile POS screens.
/// Replaces stacked horizontal ChoiceChips with a space-saving single-row dropdown.
class FilterDropdownPill<T> extends StatelessWidget {
  const FilterDropdownPill({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.icon,
    this.prefixLabel = true,
  });

  final String label;
  final T? value;
  final List<(T?, String)> items;
  final ValueChanged<T?> onChanged;
  final IconData? icon;
  final bool prefixLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = value != null;

    final selectedItem = items.where((item) => item.$1 == value).firstOrNull;
    final displayLabel = selectedItem?.$2 ?? items.firstOrNull?.$2 ?? CoreStrings.filterAll;

    final text = prefixLabel && isActive ? CoreStrings.filterActiveLabel(label, displayLabel) : displayLabel;

    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r14)),
          elevation: 6,
          color: isDark ? AppColors.slate800 : Colors.white,
        ),
      ),
      child: PopupMenuButton<T?>(
        tooltip: CoreStrings.filterTooltip(label),
        initialValue: value,
        onSelected: onChanged,
        offset: const Offset(0, 38),
        itemBuilder: (context) => [
          for (final item in items)
            PopupMenuItem<T?>(
              value: item.$1,
              height: 40,
              child: Row(
                children: [
                  Icon(
                    item.$1 == value ? AppIcons.check : AppIcons.circle,
                    size: AppSizes.s15,
                    color: item.$1 == value
                        ? AppColors.emerald500
                        : (isDark ? AppColors.slate600 : AppColors.slate300),
                  ),
                  const SizedBox(width: AppSizes.s10),
                  Text(
                    item.$2,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: item.$1 == value ? FontWeight.w700 : FontWeight.w500,
                      color: item.$1 == value
                          ? (isDark ? Colors.white : AppColors.slate900)
                          : (isDark ? AppColors.slate300 : AppColors.slate700),
                    ),
                  ),
                ],
              ),
            ),
        ],
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10),
          decoration: BoxDecoration(
            color: isActive
                ? (isDark
                    ? AppColors.emerald600.withValues(alpha: 0.22)
                    : AppColors.emerald50)
                : (isDark ? AppColors.slate800 : AppColors.slate100),
            borderRadius: BorderRadius.circular(AppRadius.r9),
            border: Border.all(
              color: isActive
                  ? (isDark ? AppColors.emerald500 : AppColors.emerald500.withValues(alpha: 0.6))
                  : (isDark ? AppColors.slate700 : AppColors.slate300),
              width: isActive ? 1.2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: AppSizes.s14,
                  color: isActive
                      ? (isDark ? AppColors.emerald400 : AppColors.emerald600)
                      : (isDark ? AppColors.slate400 : AppColors.slate500),
                ),
                const SizedBox(width: AppSizes.s6),
              ],
              Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive
                      ? (isDark ? AppColors.emerald300 : AppColors.emerald700)
                      : (isDark ? AppColors.slate300 : AppColors.slate700),
                ),
              ),
              const SizedBox(width: AppSizes.s4),
              Icon(
                AppIcons.chevronDown,
                size: AppSizes.s13,
                color: isActive
                    ? (isDark ? AppColors.emerald400 : AppColors.emerald600)
                    : (isDark ? AppColors.slate400 : AppColors.slate500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact date preset & custom range dropdown pill.
class DateFilterPill extends StatelessWidget {
  const DateFilterPill({
    super.key,
    required this.selectedRange,
    required this.onRangeChanged,
    this.defaultPreset = DateRangePresets.today,
  });

  final DateTimeRange selectedRange;
  final ValueChanged<DateTimeRange> onRangeChanged;

  /// Preset the screen opens with; the pill only looks highlighted once the user moves away from it.
  final String defaultPreset;

  String _detectPresetKey() {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final start = DateUtils.dateOnly(selectedRange.start);
    final end = DateUtils.dateOnly(selectedRange.end);

    if (start == today && end == today) return DateRangePresets.today;
    final yest = today.subtract(AppDurations.days1);
    if (start == yest && end == yest) return 'yesterday';
    final d7 = today.subtract(AppDurations.days6);
    if (start == d7 && end == today) return DateRangePresets.last7Days;
    final mStart = DateTime(today.year, today.month, 1);
    if (start == mStart && end == today) return DateRangePresets.month;
    final lastMonthEnd = mStart.subtract(AppDurations.days1);
    if (start == DateTime(lastMonthEnd.year, lastMonthEnd.month, 1) && end == lastMonthEnd) return 'lastMonth';

    return DateRangePresets.custom;
  }

  String _label() {
    final key = _detectPresetKey();
    switch (key) {
      case DateRangePresets.today:
        return CoreStrings.dateToday;
      case 'yesterday':
        return CoreStrings.dateYesterday;
      case DateRangePresets.last7Days:
        return CoreStrings.dateLast7Short;
      case DateRangePresets.month:
        return CoreStrings.dateThisMonth;
      case 'lastMonth':
        return CoreStrings.dateLastMonth;
      default:
        if (selectedRange.start == selectedRange.end) {
          return dateOnly(selectedRange.start);
        }
        return CoreStrings.dateRange(dateOnly(selectedRange.start), dateOnly(selectedRange.end));
    }
  }

  void _applyKey(BuildContext context, String key) async {
    final today = DateUtils.dateOnly(DateTime.now());
    switch (key) {
      case DateRangePresets.today:
        onRangeChanged(DateTimeRange(start: today, end: today));
      case 'yesterday':
        final yest = today.subtract(AppDurations.days1);
        onRangeChanged(DateTimeRange(start: yest, end: yest));
      case DateRangePresets.last7Days:
        final d7 = today.subtract(AppDurations.days6);
        onRangeChanged(DateTimeRange(start: d7, end: today));
      case DateRangePresets.month:
        final mStart = DateTime(today.year, today.month, 1);
        onRangeChanged(DateTimeRange(start: mStart, end: today));
      case 'lastMonth':
        final lastMonthEnd = DateTime(today.year, today.month, 1).subtract(AppDurations.days1);
        onRangeChanged(DateTimeRange(start: DateTime(lastMonthEnd.year, lastMonthEnd.month, 1), end: lastMonthEnd));
      case DateRangePresets.custom:
        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          initialDateRange: selectedRange,
        );
        if (range != null) {
          onRangeChanged(range);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final key = _detectPresetKey();
    final isActive = key != defaultPreset;

    const options = [
      (DateRangePresets.today, CoreStrings.dateToday),
      ('yesterday', CoreStrings.dateYesterday),
      (DateRangePresets.last7Days, CoreStrings.dateLast7),
      (DateRangePresets.month, CoreStrings.dateThisMonth),
      ('lastMonth', CoreStrings.dateLastMonth),
    ];

    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r14)),
          elevation: 6,
          color: isDark ? AppColors.slate800 : Colors.white,
        ),
      ),
      child: PopupMenuButton<String>(
        tooltip: CoreStrings.datePickerTooltip,
        initialValue: key,
        onSelected: (val) => _applyKey(context, val),
        offset: const Offset(0, 38),
        itemBuilder: (context) => [
          for (final (optKey, optLabel) in options)
            PopupMenuItem<String>(
              value: optKey,
              height: 40,
              child: Row(
                children: [
                  Icon(
                    key == optKey ? AppIcons.check : AppIcons.circle,
                    size: AppSizes.s15,
                    color: key == optKey
                        ? AppColors.emerald500
                        : (isDark ? AppColors.slate600 : AppColors.slate300),
                  ),
                  const SizedBox(width: AppSizes.s10),
                  Text(
                    optLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: key == optKey ? FontWeight.w700 : FontWeight.w500,
                      color: key == optKey
                          ? (isDark ? Colors.white : AppColors.slate900)
                          : (isDark ? AppColors.slate300 : AppColors.slate700),
                    ),
                  ),
                ],
              ),
            ),
          const PopupMenuDivider(height: 8),
          PopupMenuItem<String>(
            value: DateRangePresets.custom,
            height: 40,
            child: Row(
              children: [
                Icon(
                  AppIcons.calendarRange,
                  size: AppSizes.s15,
                  color: key == DateRangePresets.custom
                      ? AppColors.emerald500
                      : (isDark ? AppColors.slate400 : AppColors.slate500),
                ),
                const SizedBox(width: AppSizes.s10),
                Text(
                  CoreStrings.dateCustomRange,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: key == DateRangePresets.custom ? FontWeight.w700 : FontWeight.w500,
                  color: key == DateRangePresets.custom
                        ? (isDark ? Colors.white : AppColors.slate900)
                        : (isDark ? AppColors.slate300 : AppColors.slate700),
                  ),
                ),
              ],
            ),
          ),
        ],
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10),
          decoration: BoxDecoration(
            color: isActive
                ? (isDark
                    ? AppColors.emerald600.withValues(alpha: 0.22)
                    : AppColors.emerald50)
                : (isDark ? AppColors.slate800 : AppColors.slate100),
            borderRadius: BorderRadius.circular(AppRadius.r9),
            border: Border.all(
              color: isActive
                  ? (isDark ? AppColors.emerald500 : AppColors.emerald500.withValues(alpha: 0.6))
                  : (isDark ? AppColors.slate700 : AppColors.slate300),
              width: isActive ? 1.2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AppIcons.calendar,
                size: AppSizes.s14,
                color: isActive
                    ? (isDark ? AppColors.emerald400 : AppColors.emerald600)
                    : (isDark ? AppColors.slate400 : AppColors.slate500),
              ),
              const SizedBox(width: AppSizes.s6),
              Text(
                _label(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive
                      ? (isDark ? AppColors.emerald300 : AppColors.emerald700)
                      : (isDark ? AppColors.slate300 : AppColors.slate700),
                ),
              ),
              const SizedBox(width: AppSizes.s4),
              Icon(
                AppIcons.chevronDown,
                size: AppSizes.s13,
                color: isActive
                    ? (isDark ? AppColors.emerald400 : AppColors.emerald600)
                    : (isDark ? AppColors.slate400 : AppColors.slate500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

