import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_routes.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/access.dart';
import '../../auth/auth_controller.dart';
import '../../onboarding/onboarding.dart';
import '../data/outlet_models.dart';
import '../data/outlet_repository.dart';
import '../outlet_controller.dart';
import 'outlet_business_sheet.dart';

class OutletsScreen extends ConsumerWidget {
  const OutletsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final canManage = user?.canManageOutlets ?? false;
    final tenant = user?.tenant;
    final canAdd = tenant?.canAddOutlet ?? false;
    final outlets = ref.watch(managedOutletsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(OutletStrings.screenTitle)),
      floatingActionButton: canManage && canAdd
          ? AppFloatingActionButton.extended(
              onPressed: () => FormSheet.show<void>(context, OutletFormSheet(outlets: outlets.value ?? const [])),
              icon: const Icon(AppIcons.plus),
              label: const Text(OutletStrings.addOutlet),
            )
          : null,
      body: AsyncView(
        value: outlets,
        onRetry: () => ref.invalidate(managedOutletsProvider),
        data: (list) => RefreshIndicator(
          onRefresh: () async {
            await ref.read(authControllerProvider.notifier).refreshProfile();
            ref.invalidate(managedOutletsProvider);
            await ref.read(managedOutletsProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s16, AppSpacing.s96),
            children: [
              _QuotaCard(used: tenant?.outletsUsed ?? list.where((o) => o.isActive).length, max: tenant?.outletsMax ?? 1, plan: tenant?.planLabel ?? '', canAdd: canAdd, canManage: canManage),
              const SizedBox(height: AppSizes.s12),
              if (list.isEmpty) const SizedBox(height: 240, child: EmptyState(icon: AppIcons.store, title: OutletStrings.emptyTitle)),
              for (final outlet in list)
                _OutletCard(
                  outlet: outlet,
                  onTap: canManage ? () => FormSheet.show<void>(context, _OutletActions(outlet: outlet, outlets: list)) : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuotaCard extends StatelessWidget {
  const _QuotaCard({required this.used, required this.max, required this.plan, required this.canAdd, required this.canManage});

  final int used;
  final int max;
  final String plan;
  final bool canAdd;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.r16),
        gradient: LinearGradient(colors: isDark ? const [AppColors.slate900, AppColors.slate800] : const [AppColors.slate800, AppColors.slate700]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plan.isNotEmpty) Text(plan, style: const TextStyle(color: AppColors.slate300, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSizes.s4),
          Text(OutletStrings.quotaTitle(used, max), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSizes.s6),
          Text(
            canManage && !canAdd ? OutletStrings.limitReached : OutletStrings.quotaHint,
            style: const TextStyle(color: AppColors.slate300, fontSize: 12.5, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _OutletCard extends StatelessWidget {
  const _OutletCard({required this.outlet, required this.onTap});

  final OutletInfo outlet;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('outlet-card-${outlet.id}'),
          borderRadius: BorderRadius.circular(AppRadius.r12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.teal700.withValues(alpha: 0.3) : AppColors.teal100,
                    borderRadius: BorderRadius.circular(AppRadius.r10),
                  ),
                  child: const Icon(AppIcons.store, size: AppSizes.s18, color: AppColors.teal600),
                ),
                const SizedBox(width: AppSizes.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(child: Text(outlet.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                          const SizedBox(width: AppSizes.s6),
                          Text(outlet.code, style: TextStyle(fontSize: 11.5, color: muted, fontFamily: 'monospace')),
                        ],
                      ),
                      if (outlet.effectiveStoreTypeLabel != null) Text(outlet.effectiveStoreTypeLabel!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: muted)),
                      if ((outlet.address ?? '').isNotEmpty) Text(outlet.address!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: muted)),
                      const SizedBox(height: AppSizes.s6),
                      Wrap(
                        spacing: AppSizes.s6,
                        runSpacing: AppSizes.s4,
                        children: [
                          if (outlet.isPrimary) const StatusBadge(label: OutletStrings.badgePrimary, tone: BadgeTone.info),
                          if (!outlet.isActive)
                            const StatusBadge(label: OutletStrings.badgeInactive)
                          else if (outlet.isLocked)
                            const StatusBadge(label: OutletStrings.badgeLocked, tone: BadgeTone.warning)
                          else
                            const StatusBadge(label: OutletStrings.badgeActive, tone: BadgeTone.success),
                          if (outlet.usersCount != null) Text(OutletStrings.usersCount(outlet.usersCount!), style: TextStyle(fontSize: 11.5, color: muted)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (onTap != null) Icon(AppIcons.ellipsisVertical, size: AppSizes.s18, color: muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Everything the owner can do with one outlet, as a list of rows that each close this sheet first.
class _OutletActions extends ConsumerWidget {
  const _OutletActions({required this.outlet, required this.outlets});

  final OutletInfo outlet;
  final List<OutletInfo> outlets;

  Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() action, {String? success}) async {
    try {
      await action();
      await ref.read(authControllerProvider.notifier).refreshProfile();
      ref.invalidate(managedOutletsProvider);
      if (context.mounted && success != null) {
        showMessage(context, success);
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        showError(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(outletRepositoryProvider);
    // The sheet closes itself first, so the navigator and messenger are taken from the screen below.
    final root = Navigator.of(context, rootNavigator: true).context;

    void act(Future<void> Function(BuildContext) body) {
      Navigator.pop(context);
      body(root);
    }

    return FormSheet(
      title: outlet.name,
      subtitle: outlet.code,
      children: [
        _ActionTile(icon: AppIcons.pencil, label: OutletStrings.actionEdit, onTap: () => act((c) => FormSheet.show<void>(c, OutletFormSheet(outlet: outlet, outlets: outlets)))),
        _ActionTile(icon: AppIcons.slidersHorizontal, label: OutletStrings.actionSettings, onTap: () => act((c) async => c.push(AppRoutes.outletSettings(outlet.id)))),
        _ActionTile(icon: AppIcons.users, label: OutletStrings.actionAccess, onTap: () => act((c) => FormSheet.show<void>(c, OutletAccessSheet(outlet: outlet)))),
        if (outlet.capabilities != null)
          _ActionTile(icon: AppIcons.briefcaseBusiness, label: OutletStrings.actionBusiness, onTap: () => act((c) => FormSheet.show<void>(c, OutletBusinessSheet(outlet: outlet)))),
        if (outlets.length > 1) _ActionTile(icon: AppIcons.copy, label: OutletStrings.actionCopy, onTap: () => act((c) => FormSheet.show<void>(c, OutletCopySheet(outlet: outlet, outlets: outlets)))),
        if (!outlet.isPrimary && outlet.isActive)
          _ActionTile(
            icon: AppIcons.star,
            label: OutletStrings.actionMakePrimary,
            onTap: () => act((c) async {
              final ok = await confirmAction(c, title: OutletStrings.makePrimaryTitle, message: OutletStrings.makePrimaryMessage(outlet.name), confirmLabel: OutletStrings.actionMakePrimary);
              if (ok && c.mounted) {
                await _run(c, ref, () => repo.setPrimary(outlet.id));
              }
            }),
          ),
        if (!outlet.isPrimary)
          _ActionTile(
            icon: outlet.isActive ? AppIcons.ban : AppIcons.circleCheck,
            label: outlet.isActive ? OutletStrings.actionDeactivate : OutletStrings.actionActivate,
            onTap: () => act((c) async {
              if (outlet.isActive) {
                final ok = await confirmAction(c, title: OutletStrings.deactivateTitle, message: OutletStrings.deactivateMessage(outlet.name), confirmLabel: OutletStrings.deactivateConfirm, danger: true);
                if (!ok || !c.mounted) {
                  return;
                }
              }
              await _run(c, ref, () => repo.setActive(outlet.id, active: !outlet.isActive));
            }),
          ),
        if (!outlet.isPrimary)
          _ActionTile(
            icon: AppIcons.trash2,
            label: OutletStrings.actionDelete,
            danger: true,
            onTap: () => act((c) async {
              final ok = await confirmAction(c, title: OutletStrings.deleteTitle, message: OutletStrings.deleteMessage(outlet.name), confirmLabel: OutletStrings.deleteConfirm, danger: true);
              if (ok && c.mounted) {
                await _run(c, ref, () => repo.delete(outlet.id));
              }
            }),
          ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onTap, this.danger = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? StatusColors.of(context).danger : null;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }
}

class OutletFormSheet extends ConsumerStatefulWidget {
  const OutletFormSheet({super.key, this.outlet, this.outlets = const []});

  final OutletInfo? outlet;
  final List<OutletInfo> outlets;

  @override
  ConsumerState<OutletFormSheet> createState() => _OutletFormSheetState();
}

class _OutletFormSheetState extends ConsumerState<OutletFormSheet> {
  late final _name = TextEditingController(text: widget.outlet?.name);
  late final _code = TextEditingController(text: widget.outlet?.code);
  late final _address = TextEditingController(text: widget.outlet?.address);
  late final _phone = TextEditingController(text: widget.outlet?.phone);
  int? _copyFrom;
  String? _storeType;
  bool _includeSamples = true;
  final Set<String> _capabilities = {};
  bool _busy = false;
  ApiException? _error;

  void _pickStoreType(String? value, List<StorePreset> presets) {
    setState(() {
      _storeType = value;
      _includeSamples = true;
      _capabilities
        ..clear()
        ..addAll([for (final capability in capabilityOptionsFor(presets, value)) if (capability.defaultOn) capability.key]);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(outletRepositoryProvider).save(
            id: widget.outlet?.id,
            name: _name.text.trim(),
            code: _code.text.trim().toUpperCase(),
            address: _address.text.trim().isEmpty ? null : _address.text.trim(),
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            copyFromOutletId: _copyFrom,
            storeType: _storeType,
            includeSampleProducts: _includeSamples,
            capabilities: _storeType == null ? null : _capabilities.toList(),
          );
      await ref.read(authControllerProvider.notifier).refreshProfile();
      ref.invalidate(managedOutletsProvider);
      if (mounted) {
        Navigator.pop(context);
        showMessage(context, OutletStrings.savedMessage);
      }
    } on ApiException catch (error) {
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  /// One question for the owner; the preset fills in categories, features, and cashier rules.
  List<Widget> _storeTypeFields(BuildContext context) {
    final presets = ref.watch(storePresetsProvider).value;
    if (presets == null) {
      return const [];
    }

    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final baseType = widget.outlets.where((outlet) => outlet.isPrimary).firstOrNull?.effectiveStoreType;
    final preset = presets.where((preset) => preset.key == _storeType).firstOrNull;

    return [
      const SizedBox(height: AppSizes.s12),
      DropdownButtonFormField<String?>(
        key: const ValueKey('outlet-store-type'),
        initialValue: _storeType,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: OutletStrings.storeTypeLabel,
          helperText: preset == null ? OutletStrings.storeTypeSameHelp : OutletStrings.storeTypePresetHelp(preset.label),
          helperMaxLines: 3,
        ),
        items: [
          DropdownMenuItem<String?>(child: Text(OutletStrings.storeTypeSame(presets.where((option) => option.key == baseType).firstOrNull?.label))),
          for (final option in presets)
            if (option.key != baseType) DropdownMenuItem<String?>(value: option.key, child: Text(option.label)),
        ],
        onChanged: _busy ? null : (value) => _pickStoreType(value, presets),
      ),
      if (preset != null) ...[
        if (preset.sampleProductCount > 0)
          AppSwitchListTile(
            value: _includeSamples,
            onChanged: _busy ? null : (value) => setState(() => _includeSamples = value),
            title: const Text(OutletStrings.includeSamples, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
            subtitle: Text(OutletStrings.includeSamplesHelp(preset.sampleProductCount), style: const TextStyle(fontSize: 11.5)),
          ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: Text(OutletStrings.capabilitiesSummary(_capabilities.length), style: TextStyle(fontSize: 13, color: muted)),
          children: [
            OutletCapabilityList(
              options: preset.capabilities,
              selected: _capabilities,
              enabled: !_busy,
              onToggle: (key) => setState(() => _capabilities.contains(key) ? _capabilities.remove(key) : _capabilities.add(key)),
            ),
          ],
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final generalError = _error != null && _error!.fieldErrors.isEmpty ? _error!.message : null;
    final isNew = widget.outlet == null;

    return FormSheet(
      title: isNew ? OutletStrings.formAddTitle : OutletStrings.formEditTitle,
      children: [
        TextField(
          controller: _name,
          autofocus: isNew,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: OutletStrings.nameLabel, hintText: OutletStrings.nameHint, errorText: _error?.fieldError('name')),
        ),
        const SizedBox(height: AppSizes.s12),
        TextField(
          controller: _code,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')), LengthLimitingTextInputFormatter(10)],
          decoration: InputDecoration(labelText: OutletStrings.codeLabel, hintText: OutletStrings.codeHint, helperText: OutletStrings.codeHelp, helperMaxLines: 3, errorText: _error?.fieldError('code')),
        ),
        const SizedBox(height: AppSizes.s12),
        TextField(
          controller: _address,
          maxLines: 2,
          decoration: InputDecoration(labelText: OutletStrings.addressLabel, errorText: _error?.fieldError('address')),
        ),
        const SizedBox(height: AppSizes.s12),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(labelText: OutletStrings.phoneLabel, errorText: _error?.fieldError('phone')),
        ),
        if (isNew && widget.outlets.isNotEmpty) ...[
          const SizedBox(height: AppSizes.s12),
          DropdownButtonFormField<int?>(
            initialValue: _copyFrom,
            isExpanded: true,
            decoration: const InputDecoration(labelText: OutletStrings.copyFromLabel, helperText: OutletStrings.copyFromHelp, helperMaxLines: 3),
            items: [
              const DropdownMenuItem<int?>(child: Text(OutletStrings.copyFromNone)),
              for (final outlet in widget.outlets) DropdownMenuItem<int?>(value: outlet.id, child: Text(outlet.name)),
            ],
            onChanged: (value) => setState(() => _copyFrom = value),
          ),
        ],
        if (isNew && widget.outlets.isNotEmpty && widget.outlets.first.capabilities != null) ..._storeTypeFields(context),
        if (generalError != null) ...[
          const SizedBox(height: AppSizes.s8),
          Text(generalError, style: TextStyle(color: StatusColors.of(context).danger)),
        ],
        const SizedBox(height: AppSizes.s16),
        FilledButton(onPressed: _busy ? null : _save, child: const Text(OutletStrings.save)),
      ],
    );
  }
}

class OutletAccessSheet extends ConsumerStatefulWidget {
  const OutletAccessSheet({super.key, required this.outlet});

  final OutletInfo outlet;

  @override
  ConsumerState<OutletAccessSheet> createState() => _OutletAccessSheetState();
}

class _OutletAccessSheetState extends ConsumerState<OutletAccessSheet> {
  Set<int>? _selected;
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(outletRepositoryProvider).saveAccess(widget.outlet.id, (_selected ?? {}).toList());
      ref.invalidate(managedOutletsProvider);
      if (mounted) {
        Navigator.pop(context);
        showMessage(context, OutletStrings.accessSaved);
      }
    } on ApiException catch (error) {
      setState(() => _error = error.fieldError('user_ids') ?? error.message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(outletAccessProvider(widget.outlet.id));

    return FormSheet(
      title: OutletStrings.accessTitle,
      subtitle: OutletStrings.accessSubtitle(widget.outlet.name),
      children: [
        const Text(OutletStrings.accessHelp, style: TextStyle(fontSize: 12.5)),
        const SizedBox(height: AppSizes.s8),
        switch (users) {
          AsyncData(:final value) => Column(
              children: [
                for (final user in value)
                  CheckboxListTile(
                    key: ValueKey('access-${user.id}'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(user.name),
                    subtitle: Text(user.hasAllOutlets ? OutletStrings.accessAllOutlets : user.username),
                    value: user.hasAllOutlets || (_selected ??= {for (final u in value) if (u.assigned) u.id}).contains(user.id),
                    onChanged: user.hasAllOutlets
                        ? null
                        : (checked) => setState(() {
                              final current = _selected ??= {for (final u in value) if (u.assigned) u.id};
                              checked == true ? current.add(user.id) : current.remove(user.id);
                            }),
                  ),
              ],
            ),
          AsyncError(:final error) => Padding(padding: const EdgeInsets.all(AppSpacing.s16), child: Text(errorMessage(error))),
          _ => const Padding(padding: EdgeInsets.all(AppSpacing.s24), child: Center(child: CircularProgressIndicator())),
        },
        if (_error != null) ...[
          const SizedBox(height: AppSizes.s8),
          Text(_error!, style: TextStyle(color: StatusColors.of(context).danger)),
        ],
        const SizedBox(height: AppSizes.s12),
        FilledButton(onPressed: _busy || users.value == null ? null : _save, child: const Text(OutletStrings.save)),
      ],
    );
  }
}

class OutletCopySheet extends ConsumerStatefulWidget {
  const OutletCopySheet({super.key, required this.outlet, required this.outlets});

  final OutletInfo outlet;
  final List<OutletInfo> outlets;

  @override
  ConsumerState<OutletCopySheet> createState() => _OutletCopySheetState();
}

class _OutletCopySheetState extends ConsumerState<OutletCopySheet> {
  int? _source;
  bool _includeBusiness = false;
  bool _busy = false;
  String? _error;

  Future<void> _copy() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(outletRepositoryProvider).copyFrom(widget.outlet.id, _source!, includeBusiness: _includeBusiness);
      ref.invalidate(outletSettingsProvider(widget.outlet.id));
      if (_includeBusiness) {
        await ref.read(authControllerProvider.notifier).refreshProfile();
        ref.invalidate(managedOutletsProvider);
      }
      if (mounted) {
        Navigator.pop(context);
        showMessage(context, OutletStrings.copyDone);
      }
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: OutletStrings.copyTitle,
      subtitle: widget.outlet.name,
      children: [
        const Text(OutletStrings.copyHelp, style: TextStyle(fontSize: 12.5)),
        const SizedBox(height: AppSizes.s12),
        DropdownButtonFormField<int>(
          initialValue: _source,
          isExpanded: true,
          decoration: const InputDecoration(labelText: OutletStrings.copySource),
          items: [for (final outlet in widget.outlets.where((o) => o.id != widget.outlet.id)) DropdownMenuItem(value: outlet.id, child: Text(outlet.name))],
          onChanged: (value) => setState(() => _source = value),
        ),
        if (widget.outlet.capabilities != null)
          AppSwitchListTile(
            value: _includeBusiness,
            onChanged: _busy ? null : (value) => setState(() => _includeBusiness = value),
            title: const Text(OutletStrings.copyBusiness, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
            subtitle: const Text(OutletStrings.copyBusinessHelp, style: TextStyle(fontSize: 11.5)),
          ),
        if (_error != null) ...[
          const SizedBox(height: AppSizes.s8),
          Text(_error!, style: TextStyle(color: StatusColors.of(context).danger)),
        ],
        const SizedBox(height: AppSizes.s16),
        FilledButton(onPressed: _busy || _source == null ? null : _copy, child: const Text(OutletStrings.copyConfirm)),
      ],
    );
  }
}
