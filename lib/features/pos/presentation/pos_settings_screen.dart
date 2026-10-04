import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../data/pos_models.dart';
import '../data/pos_repository.dart';
import '../pos_providers.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

class PosSettingsScreen extends ConsumerStatefulWidget {
  const PosSettingsScreen({super.key});

  @override
  ConsumerState<PosSettingsScreen> createState() => _PosSettingsScreenState();
}

class _PosSettingsScreenState extends ConsumerState<PosSettingsScreen> {
  bool _saving = false;

  Future<void> _update({bool? allowNegativeStock, bool? allowCredit, bool? autoPrint}) async {
    setState(() => _saving = true);
    try {
      await ref.read(posRepositoryProvider).updateSettings(
            allowNegativeStock: allowNegativeStock,
            allowCredit: allowCredit,
            autoPrint: autoPrint,
          );
      ref.invalidate(posConfigProvider);
      unawaited(HapticFeedback.lightImpact());
      if (mounted) {
        showMessage(context, PosStrings.settingsSavedMessage);
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final configAsync = ref.watch(posConfigProvider);
    final displaySettings = ref.watch(posDisplaySettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(PosStrings.settingsAppBarTitle),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.s16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: AsyncView<PosConfig>(
        value: configAsync,
        onRetry: () => ref.invalidate(posConfigProvider),
        data: (config) => RefreshIndicator(
          onRefresh: () async => ref.refresh(posConfigProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.s16),
            children: [
              Text(
                PosStrings.sectionTransactionStock,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppSizes.s8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
                  child: Column(
                    children: [
                      AppSwitchListTile(
                        value: config.allowNegativeStock,
                        onChanged: _saving ? null : (val) => _update(allowNegativeStock: val),
                        secondary: Icon(
                          AppIcons.packageMinus,
                          color: config.allowNegativeStock ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                        ),
                        title: const Text(
                          PosStrings.allowNegativeStockTitle,
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: const Padding(
                          padding: EdgeInsets.only(top: AppSpacing.s2),
                          child: Text(
                            PosStrings.allowNegativeStockSubtitle,
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const Divider(height: 16),
                      AppSwitchListTile(
                        value: config.allowCredit,
                        onChanged: _saving ? null : (val) => _update(allowCredit: val),
                        secondary: Icon(
                          AppIcons.handCoins,
                          color: config.allowCredit ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                        ),
                        title: const Text(
                          PosStrings.allowCreditTitle,
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: const Padding(
                          padding: EdgeInsets.only(top: AppSpacing.s2),
                          child: Text(
                            PosStrings.allowCreditSubtitle,
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.s20),
              Text(
                PosStrings.sectionReceiptPrint,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppSizes.s8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
                  child: Column(
                    children: [
                      AppSwitchListTile(
                        value: config.autoPrint,
                        onChanged: _saving ? null : (val) => _update(autoPrint: val),
                        secondary: Icon(
                          AppIcons.printer,
                          color: config.autoPrint ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                        ),
                        title: const Text(
                          PosStrings.autoPrintTitle,
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: const Padding(
                          padding: EdgeInsets.only(top: AppSpacing.s2),
                          child: Text(
                            PosStrings.autoPrintSubtitle,
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.s20),
              Text(
                PosStrings.sectionDisplayScreen,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppSizes.s8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
                  child: Column(
                    children: [
                      AppSwitchListTile(
                        value: displaySettings.keepScreenOn,
                        onChanged: (val) {
                          unawaited(HapticFeedback.lightImpact());
                          ref.read(posDisplaySettingsProvider.notifier).setKeepScreenOn(val);
                        },
                        secondary: Icon(
                          AppIcons.sun,
                          color: displaySettings.keepScreenOn ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                        ),
                        title: const Text(
                          PosStrings.keepScreenOnTitle,
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: const Padding(
                          padding: EdgeInsets.only(top: AppSpacing.s2),
                          child: Text(
                            PosStrings.keepScreenOnSubtitle,
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const Divider(height: 16),
                      AppSwitchListTile(
                        value: displaySettings.qrFullBrightness,
                        onChanged: (val) {
                          unawaited(HapticFeedback.lightImpact());
                          ref.read(posDisplaySettingsProvider.notifier).setQrFullBrightness(val);
                        },
                        secondary: Icon(
                          AppIcons.qrCode,
                          color: displaySettings.qrFullBrightness ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                        ),
                        title: const Text(
                          PosStrings.qrFullBrightnessTitle,
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: const Padding(
                          padding: EdgeInsets.only(top: AppSpacing.s2),
                          child: Text(
                            PosStrings.qrFullBrightnessSubtitle,
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.s20),
              Container(
                padding: const EdgeInsets.all(AppSpacing.s12),
                decoration: BoxDecoration(
                  color: StatusColors.of(context).info.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.r10),
                  border: Border.all(color: StatusColors.of(context).info.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(AppIcons.info, size: AppSizes.s18, color: StatusColors.of(context).info),
                    const SizedBox(width: AppSizes.s10),
                    Expanded(
                      child: Text(
                        '${PosStrings.settingsGlobalNote}\n\n${PosStrings.settingsLocalNote}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: StatusColors.of(context).info,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
