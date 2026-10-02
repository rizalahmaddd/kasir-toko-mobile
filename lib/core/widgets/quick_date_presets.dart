import 'package:flutter/material.dart';

enum DatePreset { today, yesterday, last7Days, thisMonth, custom }

class QuickDateFilterBar extends StatelessWidget {
  const QuickDateFilterBar({
    super.key,
    required this.selectedRange,
    required this.onRangeChanged,
  });

  final DateTimeRange selectedRange;
  final ValueChanged<DateTimeRange> onRangeChanged;

  DatePreset _detectPreset() {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final start = DateUtils.dateOnly(selectedRange.start);
    final end = DateUtils.dateOnly(selectedRange.end);

    if (start == today && end == today) return DatePreset.today;
    final yest = today.subtract(const Duration(days: 1));
    if (start == yest && end == yest) return DatePreset.yesterday;
    final d7 = today.subtract(const Duration(days: 6));
    if (start == d7 && end == today) return DatePreset.last7Days;
    final mStart = DateTime(today.year, today.month, 1);
    if (start == mStart && end == today) return DatePreset.thisMonth;

    return DatePreset.custom;
  }

  void _applyPreset(BuildContext context, DatePreset preset) async {
    final today = DateUtils.dateOnly(DateTime.now());
    switch (preset) {
      case DatePreset.today:
        onRangeChanged(DateTimeRange(start: today, end: today));
      case DatePreset.yesterday:
        final yest = today.subtract(const Duration(days: 1));
        onRangeChanged(DateTimeRange(start: yest, end: yest));
      case DatePreset.last7Days:
        final d7 = today.subtract(const Duration(days: 6));
        onRangeChanged(DateTimeRange(start: d7, end: today));
      case DatePreset.thisMonth:
        final mStart = DateTime(today.year, today.month, 1);
        onRangeChanged(DateTimeRange(start: mStart, end: today));
      case DatePreset.custom:
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
    final active = _detectPreset();
    const options = [
      (DatePreset.today, 'Hari ini'),
      (DatePreset.yesterday, 'Kemarin'),
      (DatePreset.last7Days, '7 hari'),
      (DatePreset.thisMonth, 'Bulan ini'),
      (DatePreset.custom, 'Kustom'),
    ];

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final (preset, label) in options)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(label),
                selected: active == preset,
                showCheckmark: false,
                onSelected: (_) => _applyPreset(context, preset),
              ),
            ),
        ],
      ),
    );
  }
}
