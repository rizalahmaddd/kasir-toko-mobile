import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/common.dart';
import '../../data/pos_repository.dart';

/// Pilih nomor seri/IMEI unit yang diserahkan. Daftar diambil dari stok outlet; offline cukup ketik atau scan.
class SerialPickerSheet extends ConsumerStatefulWidget {
  const SerialPickerSheet({super.key, required this.productId, required this.title, this.selected = const [], this.exclude = const {}});

  final int productId;
  final String title;
  final List<String> selected;
  final Set<String> exclude;

  static Future<List<String>?> show(BuildContext context, {required int productId, required String title, List<String> selected = const [], Set<String> exclude = const {}}) =>
      showModalBottomSheet<List<String>>(
        context: context,
        isScrollControlled: true,
        builder: (_) => SerialPickerSheet(productId: productId, title: title, selected: selected, exclude: exclude),
      );

  @override
  ConsumerState<SerialPickerSheet> createState() => _SerialPickerSheetState();
}

class _SerialPickerSheetState extends ConsumerState<SerialPickerSheet> {
  late final List<String> _picked = [...widget.selected];
  final _manual = TextEditingController();
  List<String> _options = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    ref.read(posRepositoryProvider).availableSerials(widget.productId).then((options) {
      if (mounted) {
        setState(() {
          _options = options.where((s) => !widget.exclude.contains(s)).toList();
          _loading = false;
        });
      }
    }, onError: (Object _) {
      if (mounted) {
        setState(() => _loading = false);
      }
    });
  }

  @override
  void dispose() {
    _manual.dispose();
    super.dispose();
  }

  void _addManual() {
    final value = _manual.text.trim().toUpperCase();
    if (value.isNotEmpty && !_picked.contains(value)) {
      setState(() => _picked.add(value));
    }
    _manual.clear();
  }

  @override
  Widget build(BuildContext context) {
    final all = {..._picked, ..._options}.toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BottomSheetHeader(title: widget.title, subtitle: PosStrings.serialSheetSubtitle),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manual,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(hintText: PosStrings.serialManualHint, isDense: true),
                    onSubmitted: (_) => _addManual(),
                  ),
                ),
                const SizedBox(width: AppSizes.s8),
                OutlinedButton(onPressed: _addManual, child: const Text(PosStrings.serialAdd)),
              ],
            ),
          ),
          if (_loading) const Padding(padding: EdgeInsets.all(AppSpacing.s16), child: Center(child: CircularProgressIndicator())),
          if (!_loading && all.isEmpty)
            const Padding(padding: EdgeInsets.all(AppSpacing.s20), child: Text(PosStrings.serialNoneAvailable)),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final serial in all)
                  CheckboxListTile(
                    dense: true,
                    value: _picked.contains(serial),
                    title: Text(serial, style: const TextStyle(fontFamily: 'monospace')),
                    onChanged: (value) => setState(() => value == true ? _picked.add(serial) : _picked.remove(serial)),
                  ),
              ],
            ),
          ),
          if (_error != null)
            Padding(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s20),
            child: FilledButton(
              onPressed: () {
                if (_picked.isEmpty) {
                  setState(() => _error = PosStrings.serialPickOne);
                  return;
                }
                Navigator.pop(context, _picked);
              },
              child: Text(PosStrings.serialUse(_picked.length)),
            ),
          ),
        ],
      ),
    );
  }
}
