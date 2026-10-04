import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../pos_providers.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';
import 'package:web_pos_mobile/core/theme/app_durations.dart';

class PosCategoryChips extends ConsumerWidget {
  const PosCategoryChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(posCategoriesProvider).value ?? const [];
    final selected = ref.watch(catalogQueryProvider).categoryId;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    final options = <(int?, String, IconData?)>[
      (null, PosStrings.categoryAll, AppIcons.layoutGrid),
      ...categories.map((c) => (c.id, c.name, null)),
    ];

    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: AppSpacing.s6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSizes.s8),
        itemBuilder: (context, index) {
          final (id, name, icon) = options[index];
          final isSelected = selected == id;

          return AnimatedContainer(
            duration: AppDurations.milliseconds200,
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary
                  : (isDark ? AppColors.slate900 : Colors.white),
              borderRadius: BorderRadius.circular(AppRadius.r12),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : (isDark ? AppColors.slate800 : AppColors.slate200),
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.r12),
                onTap: () {
                  unawaited(HapticFeedback.selectionClick());
                  ref.read(catalogQueryProvider.notifier).category(id);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(
                          icon,
                          size: AppSizes.s15,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? AppColors.slate400 : AppColors.slate500),
                        ),
                        const SizedBox(width: AppSizes.s6),
                      ],
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? AppColors.slate300 : AppColors.slate700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
