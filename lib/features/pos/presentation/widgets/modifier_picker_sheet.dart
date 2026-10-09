import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/common.dart';
import '../../data/pos_models.dart';

/// Pilihan tambahan sebuah menu. Mengembalikan pilihan yang dipilih, atau null bila dibatalkan.
class ModifierPickerSheet extends StatefulWidget {
  const ModifierPickerSheet({super.key, required this.title, required this.groups, this.selected = const [], this.confirmLabel});

  final String title;
  final List<ModifierGroupOption> groups;
  final List<SelectedModifier> selected;
  final String? confirmLabel;

  static Future<List<SelectedModifier>?> show(
    BuildContext context, {
    required String title,
    required List<ModifierGroupOption> groups,
    List<SelectedModifier> selected = const [],
    String? confirmLabel,
  }) => showModalBottomSheet<List<SelectedModifier>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ModifierPickerSheet(title: title, groups: groups, selected: selected, confirmLabel: confirmLabel),
  );

  @override
  State<ModifierPickerSheet> createState() => _ModifierPickerSheetState();
}

class _ModifierPickerSheetState extends State<ModifierPickerSheet> {
  late final Map<int, List<int>> _picked = {
    for (final group in widget.groups)
      group.id: widget.selected.isEmpty
          ? (group.min >= 1 && group.max == 1 && group.modifiers.isNotEmpty ? [group.modifiers.first.id] : [])
          : [
              for (final m in widget.selected)
                if (group.modifiers.any((o) => o.id == m.id)) m.id,
            ],
  };
  String? _error;

  int get _extra => widget.groups.fold(0, (sum, g) => sum + g.modifiers.where((m) => _picked[g.id]!.contains(m.id)).fold(0, (s, m) => s + m.price));

  void _toggle(ModifierGroupOption group, ModifierOption option) {
    final list = _picked[group.id]!;
    setState(() {
      _error = null;
      if (list.contains(option.id)) {
        list.remove(option.id);
      } else if (group.max == 1) {
        _picked[group.id] = [option.id];
      } else if (group.max == null || list.length < group.max!) {
        list.add(option.id);
      } else {
        _error = PosStrings.modifierRule(group.name, group.rule);
      }
    });
  }

  void _confirm() {
    for (final group in widget.groups) {
      final count = _picked[group.id]!.length;
      if (count < group.min || (group.max != null && count > group.max!)) {
        setState(() => _error = PosStrings.modifierRule(group.name, group.rule));
        return;
      }
    }

    Navigator.pop(context, [
      for (final group in widget.groups)
        for (final option in group.modifiers)
          if (_picked[group.id]!.contains(option.id)) SelectedModifier(id: option.id, name: option.name, price: option.price, group: group.name),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BottomSheetHeader(title: widget.title, subtitle: PosStrings.modifierSheetSubtitle),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(AppSpacing.s20, AppSpacing.s0, AppSpacing.s20, AppSpacing.s12),
              children: [
                for (final group in widget.groups) ...[
                  Row(
                    children: [
                      Expanded(child: Text(group.name, style: theme.textTheme.titleSmall)),
                      Text(
                        group.rule,
                        style: theme.textTheme.labelSmall?.copyWith(color: group.min > 0 ? theme.colorScheme.tertiary : theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.s6),
                  Wrap(
                    spacing: AppSpacing.s8,
                    runSpacing: AppSpacing.s8,
                    children: [
                      for (final option in group.modifiers)
                        FilterChip(
                          label: Text(option.price > 0 ? '${option.name} +${rupiah(option.price)}' : option.name),
                          selected: _picked[group.id]!.contains(option.id),
                          onSelected: (_) => _toggle(group, option),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.s16),
                ],
                if (_error != null) Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s20, AppSpacing.s0, AppSpacing.s20, AppSpacing.s20),
            child: FilledButton(
              onPressed: _confirm,
              child: Text(widget.confirmLabel ?? (_extra > 0 ? PosStrings.modifierAddWithPrice(rupiah(_extra)) : PosStrings.modifierAdd)),
            ),
          ),
        ],
      ),
    );
  }
}
