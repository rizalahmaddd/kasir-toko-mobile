import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../utils/formatters.dart';

class PeriodPicker extends StatelessWidget {
  const PeriodPicker({super.key, required this.range, required this.onChanged});

  final DateTimeRange range;
  final ValueChanged<DateTimeRange> onChanged;

  static Map<String, DateTimeRange> presets() {
    final today = DateUtils.dateOnly(DateTime.now());
    final monthStart = DateTime(today.year, today.month);
    final lastMonthEnd = monthStart.subtract(const Duration(days: 1));

    return {
      'Hari ini': DateTimeRange(start: today, end: today),
      '7 hari': DateTimeRange(start: today.subtract(const Duration(days: 6)), end: today),
      'Bulan ini': DateTimeRange(start: monthStart, end: today),
      'Bulan lalu': DateTimeRange(start: DateTime(lastMonthEnd.year, lastMonthEnd.month), end: lastMonthEnd),
      '30 hari': DateTimeRange(start: today.subtract(const Duration(days: 29)), end: today),
    };
  }

  Future<void> _pickCustom(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateUtils.dateOnly(DateTime.now()),
      initialDateRange: range,
    );
    if (picked != null) {
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = presets();
    final isPreset = options.values.contains(range);

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final entry in options.entries)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(label: Text(entry.key), selected: entry.value == range, showCheckmark: false, onSelected: (_) => onChanged(entry.value)),
            ),
          ChoiceChip(
            avatar: const Icon(LucideIcons.calendar, size: 16),
            label: Text(isPreset ? 'Pilih tanggal' : rangeLabel(range)),
            selected: !isPreset,
            showCheckmark: false,
            onSelected: (_) => _pickCustom(context),
          ),
        ],
      ),
    );
  }
}

String rangeLabel(DateTimeRange range) => range.start == range.end ? dateOnly(range.start) : '${dateOnly(range.start)} – ${dateOnly(range.end)}';
