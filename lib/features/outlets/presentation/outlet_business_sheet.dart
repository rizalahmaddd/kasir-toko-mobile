import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/auth_controller.dart';
import '../../onboarding/onboarding.dart';
import '../data/outlet_models.dart';
import '../data/outlet_repository.dart';
import '../outlet_controller.dart';

/// Business capabilities as checkboxes, with the ones the chosen store type recommends marked.
class OutletCapabilityList extends StatelessWidget {
  const OutletCapabilityList({super.key, required this.options, required this.selected, required this.onToggle, this.enabled = true});

  final List<PresetCapability> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final capability in options)
          CheckboxListTile(
            key: ValueKey('outlet-capability-${capability.key}'),
            contentPadding: EdgeInsets.zero,
            value: selected.contains(capability.key),
            onChanged: enabled ? (_) => onToggle(capability.key) : null,
            title: Row(
              children: [
                Flexible(
                  child: Text(capability.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                ),
                if (capability.defaultOn) ...[const SizedBox(width: AppSizes.s6), const StatusBadge(label: BusinessStrings.recommended, tone: BadgeTone.success)],
              ],
            ),
            subtitle: Text(capability.description, style: const TextStyle(fontSize: 11.5)),
          ),
      ],
    );
  }
}

/// Capability options for a store type; with no store type every option is listed unmarked.
List<PresetCapability> capabilityOptionsFor(List<StorePreset> presets, String? storeType) {
  final preset = presets.where((preset) => preset.key == storeType).firstOrNull;
  if (preset != null) {
    return preset.capabilities;
  }

  return [
    for (final capability in presets.firstOrNull?.capabilities ?? const <PresetCapability>[])
      PresetCapability(key: capability.key, label: capability.label, description: capability.description, defaultOn: false),
  ];
}

/// Store type and business features of one existing outlet. Changing the store type only adds the
/// preset's categories and recommended features; nothing the outlet already uses is removed.
class OutletBusinessSheet extends ConsumerStatefulWidget {
  const OutletBusinessSheet({super.key, required this.outlet});

  final OutletInfo outlet;

  @override
  ConsumerState<OutletBusinessSheet> createState() => _OutletBusinessSheetState();
}

class _OutletBusinessSheetState extends ConsumerState<OutletBusinessSheet> {
  late String? _storeType = widget.outlet.storeType;
  late final Set<String> _capabilities = {...?widget.outlet.capabilities};
  bool _busy = false;
  ApiException? _error;

  void _pickStoreType(String? value, List<StorePreset> presets) {
    setState(() {
      _storeType = value;
      for (final capability in capabilityOptionsFor(presets, value)) {
        if (capability.defaultOn) {
          _capabilities.add(capability.key);
        }
      }
    });
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final repo = ref.read(outletRepositoryProvider);
    final outlet = widget.outlet;

    try {
      if (_storeType != null && _storeType != outlet.storeType) {
        await repo.save(id: outlet.id, name: outlet.name, code: outlet.code, address: outlet.address, phone: outlet.phone, storeType: _storeType);
      }
      await repo.saveCapabilities(outlet.id, _capabilities.toList());
      await ref.read(authControllerProvider.notifier).refreshProfile();
      ref.invalidate(managedOutletsProvider);
      if (mounted) {
        Navigator.pop(context);
        showMessage(context, OutletStrings.businessSaved);
      }
    } on ApiException catch (error) {
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final presets = ref.watch(storePresetsProvider);
    final shopType = ref.watch(currentUserProvider)?.tenant?.storeType;

    return FormSheet(
      title: OutletStrings.actionBusiness,
      subtitle: '${widget.outlet.name} · ${OutletStrings.businessSubtitle}',
      children: [
        ...presets.when(
          loading: () => const [
            Center(
              child: Padding(padding: EdgeInsets.all(AppSizes.s16), child: CircularProgressIndicator()),
            ),
          ],
          error: (_, _) => [Text(OutletStrings.presetsFailed, style: TextStyle(color: StatusColors.of(context).danger))],
          data: (list) => [
            DropdownButtonFormField<String?>(
              initialValue: _storeType,
              isExpanded: true,
              decoration: const InputDecoration(labelText: OutletStrings.storeTypeLabel, helperText: OutletStrings.storeTypeChangeHelp, helperMaxLines: 3),
              items: [
                DropdownMenuItem<String?>(child: Text(OutletStrings.storeTypeFollowShop(list.where((preset) => preset.key == shopType).firstOrNull?.label))),
                for (final preset in list) DropdownMenuItem<String?>(value: preset.key, child: Text(preset.label)),
              ],
              onChanged: _busy ? null : (value) => _pickStoreType(value, list),
            ),
            const SizedBox(height: AppSizes.s12),
            const Text(BusinessStrings.capabilitiesTitle, style: TextStyle(fontWeight: FontWeight.w700)),
            OutletCapabilityList(
              options: capabilityOptionsFor(list, _storeType),
              selected: _capabilities,
              enabled: !_busy,
              onToggle: (key) => setState(() => _capabilities.contains(key) ? _capabilities.remove(key) : _capabilities.add(key)),
            ),
          ],
        ),
        if (_error != null) ...[const SizedBox(height: AppSizes.s8), Text(_error!.message, style: TextStyle(color: StatusColors.of(context).danger))],
        const SizedBox(height: AppSizes.s16),
        FilledButton(onPressed: _busy || !presets.hasValue ? null : _save, child: const Text(OutletStrings.save)),
      ],
    );
  }
}
