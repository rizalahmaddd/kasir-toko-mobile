import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';
import '../utils/formatters.dart';

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
    final displayLabel = selectedItem?.$2 ?? items.firstOrNull?.$2 ?? 'Semua';

    final text = prefixLabel && isActive ? '$label: $displayLabel' : displayLabel;

    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 6,
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
        ),
      ),
      child: PopupMenuButton<T?>(
        tooltip: 'Filter $label',
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
                    item.$1 == value ? LucideIcons.check : LucideIcons.circle,
                    size: 15,
                    color: item.$1 == value
                        ? AppColors.emerald500
                        : (isDark ? AppColors.slate600 : AppColors.slate300),
                  ),
                  const SizedBox(width: 10),
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
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isActive
                ? (isDark
                    ? AppColors.emerald600.withValues(alpha: 0.22)
                    : const Color(0xFFECFDF5))
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isActive
                  ? (isDark ? AppColors.emerald500 : AppColors.emerald500.withValues(alpha: 0.6))
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              width: isActive ? 1.2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: isActive
                      ? (isDark ? AppColors.emerald400 : AppColors.emerald600)
                      : (isDark ? AppColors.slate400 : AppColors.slate500),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive
                      ? (isDark ? const Color(0xFF6EE7B7) : AppColors.emerald700)
                      : (isDark ? AppColors.slate300 : AppColors.slate700),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                LucideIcons.chevronDown,
                size: 13,
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
  });

  final DateTimeRange selectedRange;
  final ValueChanged<DateTimeRange> onRangeChanged;

  String _detectPresetKey() {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final start = DateUtils.dateOnly(selectedRange.start);
    final end = DateUtils.dateOnly(selectedRange.end);

    if (start == today && end == today) return 'today';
    final yest = today.subtract(const Duration(days: 1));
    if (start == yest && end == yest) return 'yesterday';
    final d7 = today.subtract(const Duration(days: 6));
    if (start == d7 && end == today) return '7days';
    final mStart = DateTime(today.year, today.month, 1);
    if (start == mStart && end == today) return 'month';

    return 'custom';
  }

  String _label() {
    final key = _detectPresetKey();
    switch (key) {
      case 'today':
        return 'Hari ini';
      case 'yesterday':
        return 'Kemarin';
      case '7days':
        return '7 hari';
      case 'month':
        return 'Bulan ini';
      default:
        if (selectedRange.start == selectedRange.end) {
          return dateOnly(selectedRange.start);
        }
        return '${dateOnly(selectedRange.start)} – ${dateOnly(selectedRange.end)}';
    }
  }

  void _applyKey(BuildContext context, String key) async {
    final today = DateUtils.dateOnly(DateTime.now());
    switch (key) {
      case 'today':
        onRangeChanged(DateTimeRange(start: today, end: today));
      case 'yesterday':
        final yest = today.subtract(const Duration(days: 1));
        onRangeChanged(DateTimeRange(start: yest, end: yest));
      case '7days':
        final d7 = today.subtract(const Duration(days: 6));
        onRangeChanged(DateTimeRange(start: d7, end: today));
      case 'month':
        final mStart = DateTime(today.year, today.month, 1);
        onRangeChanged(DateTimeRange(start: mStart, end: today));
      case 'custom':
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
    final isActive = key != 'today'; // Today is default

    const options = [
      ('today', 'Hari ini'),
      ('yesterday', 'Kemarin'),
      ('7days', '7 hari terakhir'),
      ('month', 'Bulan ini'),
    ];

    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 6,
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
        ),
      ),
      child: PopupMenuButton<String>(
        tooltip: 'Pilih Tanggal',
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
                    key == optKey ? LucideIcons.check : LucideIcons.circle,
                    size: 15,
                    color: key == optKey
                        ? AppColors.emerald500
                        : (isDark ? AppColors.slate600 : AppColors.slate300),
                  ),
                  const SizedBox(width: 10),
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
            value: 'custom',
            height: 40,
            child: Row(
              children: [
                Icon(
                  LucideIcons.calendarRange,
                  size: 15,
                  color: key == 'custom'
                      ? AppColors.emerald500
                      : (isDark ? AppColors.slate400 : AppColors.slate500),
                ),
                const SizedBox(width: 10),
                Text(
                  'Pilih Rentang Tanggal...',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: key == 'custom' ? FontWeight.w700 : FontWeight.w500,
                    color: key == 'custom'
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
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isActive
                ? (isDark
                    ? AppColors.emerald600.withValues(alpha: 0.22)
                    : const Color(0xFFECFDF5))
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isActive
                  ? (isDark ? AppColors.emerald500 : AppColors.emerald500.withValues(alpha: 0.6))
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              width: isActive ? 1.2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.calendar,
                size: 14,
                color: isActive
                    ? (isDark ? AppColors.emerald400 : AppColors.emerald600)
                    : (isDark ? AppColors.slate400 : AppColors.slate500),
              ),
              const SizedBox(width: 6),
              Text(
                _label(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive
                      ? (isDark ? const Color(0xFF6EE7B7) : AppColors.emerald700)
                      : (isDark ? AppColors.slate300 : AppColors.slate700),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                LucideIcons.chevronDown,
                size: 13,
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

