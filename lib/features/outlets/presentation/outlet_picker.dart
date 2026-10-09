import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/auth_controller.dart';
import '../../pos/cart_controller.dart';
import '../../shift/shift_controller.dart';
import '../data/outlet_models.dart';
import '../outlet_controller.dart';

/// Compact pill with the active outlet that opens the outlet picker. Hidden for single-outlet shops
/// and for accounts that can use only one outlet.
class OutletChip extends ConsumerWidget {
  const OutletChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final outlet = ref.watch(currentOutletProvider);
    if (user == null || outlet == null || user.outlets.length < 2) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: OutletStrings.chipTooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.r20),
        onTap: () => showOutletPicker(context, ref),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 160),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s5),
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate900 : AppColors.slate100,
            borderRadius: BorderRadius.circular(AppRadius.r20),
            border: Border.all(color: isDark ? AppColors.slate800 : AppColors.slate200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.store, size: AppSizes.s14, color: outlet.isLocked ? AppColors.amber500 : AppColors.emerald500),
              const SizedBox(width: AppSizes.s6),
              Flexible(
                child: Text(outlet.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: AppSizes.s2),
              const Icon(AppIcons.chevronDown, size: AppSizes.s14),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lets the cashier switch outlet. A cart that has items is dropped on switching, so that is confirmed first.
Future<void> showOutletPicker(BuildContext context, WidgetRef ref) async {
  final user = ref.read(currentUserProvider);
  if (user == null || user.outlets.isEmpty) {
    return;
  }

  final chosen = await FormSheet.show<OutletInfo>(context, _OutletPickerSheet(outlets: user.outlets, currentId: ref.read(currentOutletIdProvider)));
  if (chosen == null || chosen.id == ref.read(currentOutletIdProvider) || !context.mounted) {
    return;
  }

  if (!ref.read(cartProvider).isEmpty) {
    final ok = await confirmAction(
      context,
      title: OutletStrings.switchTitle,
      message: OutletStrings.switchCartMessage(chosen.name),
      confirmLabel: OutletStrings.switchConfirm,
    );
    if (!ok) {
      return;
    }
  }

  await ref.read(currentOutletIdProvider.notifier).select(chosen.id);
  if (context.mounted) {
    showMessage(context, OutletStrings.switched(chosen.name));
  }
}

class _OutletPickerSheet extends StatelessWidget {
  const _OutletPickerSheet({required this.outlets, required this.currentId});

  final List<OutletInfo> outlets;
  final int? currentId;

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: OutletStrings.pickerTitle,
      subtitle: OutletStrings.pickerSubtitle,
      children: [
        for (final outlet in outlets)
          ListTile(
            key: ValueKey('outlet-option-${outlet.id}'),
            contentPadding: EdgeInsets.zero,
            leading: Icon(AppIcons.store, color: outlet.isLocked ? AppColors.amber500 : null),
            title: Text(outlet.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(outlet.isLocked ? '${outlet.code} · ${OutletStrings.lockedOption}' : outlet.code),
            trailing: outlet.id == currentId ? const Icon(AppIcons.check, color: AppColors.emerald500) : null,
            onTap: () => Navigator.pop(context, outlet),
          ),
      ],
    );
  }
}

/// Warning above the cashier when the selected outlet cannot sell, or the open shift belongs to another outlet.
class OutletStatusBanner extends ConsumerWidget {
  const OutletStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final outlet = ref.watch(currentOutletProvider);
    final shift = ref.watch(currentShiftProvider).value;
    if (user == null || outlet == null) {
      return const SizedBox.shrink();
    }

    final shiftOutlet = shift?.outletId != null && shift!.outletId != outlet.id ? user.outletById(shift.outletId) : null;
    final String message;
    final String action;
    final OutletInfo? target;

    if (outlet.isLocked) {
      message = OutletStrings.lockedBanner(outlet.name);
      action = OutletStrings.lockedAction;
      target = null;
    } else if (shiftOutlet != null) {
      message = OutletStrings.shiftElsewhereBanner(shiftOutlet.name);
      action = OutletStrings.shiftElsewhereAction(shiftOutlet.name);
      target = shiftOutlet;
    } else {
      return const SizedBox.shrink();
    }

    final colors = StatusColors.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.s12, AppSpacing.s4, AppSpacing.s12, AppSpacing.s4),
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: colors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(outlet.isLocked ? AppIcons.lockKeyhole : AppIcons.alertTriangle, size: AppSizes.s18, color: colors.warning),
          const SizedBox(width: AppSizes.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: const TextStyle(fontSize: 12.5)),
                const SizedBox(height: AppSizes.s6),
                TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  onPressed: () => target == null ? showOutletPicker(context, ref) : ref.read(currentOutletIdProvider.notifier).select(target.id),
                  child: Text(action),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Menu card with the active outlet and a button to change it.
class OutletSwitchCard extends ConsumerWidget {
  const OutletSwitchCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outlet = ref.watch(currentOutletProvider);
    if (outlet == null) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        border: Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
      ),
      child: Row(
        children: [
          Icon(AppIcons.store, size: AppSizes.s20, color: outlet.isLocked ? AppColors.amber500 : AppColors.emerald500),
          const SizedBox(width: AppSizes.s12),
          Expanded(
            child: Text(OutletStrings.currentOutletCaption(outlet.name), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          TextButton(onPressed: () => showOutletPicker(context, ref), child: const Text(OutletStrings.switchCardAction)),
        ],
      ),
    );
  }
}
