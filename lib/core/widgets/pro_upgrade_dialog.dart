import 'package:flutter/material.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';
import 'package:web_pos_mobile/core/theme/app_colors.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';

Future<void> showProUpgradeDialog(
  BuildContext context, {
  String? title,
  String? featureName,
  String? description,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => ProUpgradeDialog(
      title: title,
      featureName: featureName,
      description: description,
    ),
  );
}

class ProUpgradeDialog extends StatelessWidget {
  const ProUpgradeDialog({
    super.key,
    this.title,
    this.featureName,
    this.description,
  });

  final String? title;
  final String? featureName;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.r20),
      ),
      backgroundColor: isDark ? AppColors.slate900 : Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s24,
        vertical: AppSpacing.s24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Badge with Gold/Amber Glow
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.amber500.withValues(alpha: 0.2),
                      AppColors.amber600.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.r20),
                  border: Border.all(
                    color: AppColors.amber500.withValues(alpha: 0.35),
                  ),
                ),
                child: const Icon(
                  AppIcons.sparkles,
                  color: AppColors.amber500,
                  size: AppSizes.s28,
                ),
              ),
              const SizedBox(height: AppSizes.s16),

              // Pro Pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s10,
                  vertical: AppSpacing.s4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.amber500.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.r20),
                  border: Border.all(
                    color: AppColors.amber500.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      AppIcons.star,
                      color: AppColors.amber500,
                      size: AppSizes.s12,
                    ),
                    const SizedBox(width: AppSizes.s4),
                    Text(
                      featureName != null
                          ? '${ProStrings.exclusiveBadge} • $featureName'
                          : ProStrings.exclusiveBadge,
                      style: const TextStyle(
                        color: AppColors.amber500,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.s12),

              // Title
              Text(
                title ?? ProStrings.upgradeTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: isDark ? AppColors.slate100 : AppColors.slate900,
                ),
              ),
              const SizedBox(height: AppSizes.s8),

              // Description
              Text(
                description ?? ProStrings.upgradeDescription,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: isDark ? AppColors.slate400 : AppColors.slate600,
                ),
              ),
              const SizedBox(height: AppSizes.s16),

              // How to upgrade info card (compliant with app store guideline)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.s12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate800 : AppColors.slate100,
                  borderRadius: BorderRadius.circular(AppRadius.r12),
                  border: Border.all(
                    color: isDark ? AppColors.slate700 : AppColors.slate200,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      AppIcons.info,
                      size: AppSizes.s16,
                      color: isDark ? AppColors.slate400 : AppColors.slate500,
                    ),
                    const SizedBox(width: AppSizes.s8),
                    Expanded(
                      child: Text(
                        ProStrings.upgradeHowTo,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          color: isDark ? AppColors.slate300 : AppColors.slate700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.s20),

              // Action button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.amber500,
                    foregroundColor: AppColors.slate950,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.r12),
                    ),
                  ),
                  child: const Text(
                    ProStrings.actionUnderstood,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
