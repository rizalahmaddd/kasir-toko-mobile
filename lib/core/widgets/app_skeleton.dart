import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';
import 'package:web_pos_mobile/core/theme/app_durations.dart';

/// Highly optimized shimmer effect for skeleton loading widgets.
///
/// Features:
/// - Smooth linear gradient sweep animation
/// - Zero external dependencies
/// - Calibrated contrast for both Light Mode and Dark Mode
class AppShimmer extends StatefulWidget {
  const AppShimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.duration = AppDurations.milliseconds1400,
  });

  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration duration;

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final base = widget.baseColor ?? (isDark ? AppColors.slate800 : AppColors.slate200);
    final highlight = widget.highlightColor ??
        (isDark ? AppColors.slate700.withValues(alpha: 0.8) : AppColors.slate100);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final width = bounds.width;
            final progress = _controller.value;
            // Slide gradient from -width to 2*width
            final dx = -width + (progress * 3 * width);

            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                base,
                highlight,
                base,
              ],
              stops: const [0.1, 0.5, 0.9],
              transform: _SlidingGradientTransform(slidePercent: dx / (width == 0 ? 1 : width)),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({required this.slidePercent});

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}

/// Primitive box skeleton with customizable width, height, and border radius.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.color,
  });

  final double? width;
  final double? height;
  final double borderRadius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = color ?? (isDark ? AppColors.slate800 : AppColors.slate200);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: defaultColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Primitive circular skeleton widget (e.g. avatars, icons).
class SkeletonCircle extends StatelessWidget {
  const SkeletonCircle({
    super.key,
    required this.size,
    this.color,
  });

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = color ?? (isDark ? AppColors.slate800 : AppColors.slate200);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: defaultColor,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Multi-line text skeleton block.
class SkeletonText extends StatelessWidget {
  const SkeletonText({
    super.key,
    this.lines = 2,
    this.lineHeight = 12,
    this.spacing = 6,
    this.lastLineWidthFactor = 0.65,
  });

  final int lines;
  final double lineHeight;
  final double spacing;
  final double lastLineWidthFactor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(lines, (index) {
        final isLast = index == lines - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? AppSpacing.s0 : spacing),
          child: FractionallySizedBox(
            widthFactor: isLast ? lastLineWidthFactor : 1.0,
            alignment: Alignment.centerLeft,
            child: SkeletonBox(
              height: lineHeight,
              borderRadius: 4,
            ),
          ),
        );
      }),
    );
  }
}

/// Default list skeleton fallback used when no specific skeleton is provided.
class DefaultListSkeleton extends StatelessWidget {
  const DefaultListSkeleton({
    super.key,
    this.itemCount = 6,
    this.padding = const EdgeInsets.all(AppSpacing.s16),
    this.shrinkWrap = false,
  });

  final int itemCount;
  final EdgeInsetsGeometry padding;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppShimmer(
      child: ListView.separated(
        padding: padding,
        shrinkWrap: shrinkWrap,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: AppSizes.s10),
        itemBuilder: (_, _) => Container(
          padding: const EdgeInsets.all(AppSpacing.s14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate900 : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.r14),
            border: Border.all(
              color: isDark ? AppColors.slate800 : AppColors.slate200,
            ),
          ),
          child: const Row(
            children: [
              SkeletonBox(width: 48, height: 48, borderRadius: 10),
              SizedBox(width: AppSizes.s14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 140, height: 14, borderRadius: 4),
                    SizedBox(height: AppSizes.s8),
                    SkeletonBox(width: 90, height: 11, borderRadius: 4),
                  ],
                ),
              ),
              SkeletonBox(width: 60, height: 16, borderRadius: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton for POS Catalog panel (matches PosCategoryChips + PosProductCard Grid / PosProductListTile).
class PosCatalogSkeleton extends StatelessWidget {
  const PosCatalogSkeleton({
    super.key,
    this.isList = false,
    this.gridDelegate,
    this.cardHeight = 226,
    this.photoHeight = 114,
    this.itemCount = 6,
  });

  final bool isList;
  final SliverGridDelegate? gridDelegate;
  final double cardHeight;
  final double photoHeight;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final delegate = gridDelegate ??
        const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          mainAxisExtent: 226,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        );

    return AppShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category chips skeleton
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
              itemCount: 5,
              separatorBuilder: (_, _) => const SizedBox(width: AppSizes.s8),
              itemBuilder: (_, index) => SkeletonBox(
                width: index == 0 ? 80 : 96,
                height: 38,
                borderRadius: 12,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.s8),
          // Product Cards / List Tiles Grid skeleton
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppSpacing.s12, AppSpacing.s4, AppSpacing.s12, AppSpacing.s16),
              gridDelegate: delegate,
              itemCount: itemCount,
              itemBuilder: (context, _) {
                if (isList) {
                  return Container(
                    height: 68,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.slate900 : Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.r12),
                      border: Border.all(
                        color: isDark ? AppColors.slate800 : AppColors.slate200,
                      ),
                    ),
                    child: const Row(
                      children: [
                        SkeletonBox(width: 44, height: 44, borderRadius: 8),
                        SizedBox(width: AppSizes.s10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SkeletonBox(width: 130, height: 13, borderRadius: 4),
                              SizedBox(height: AppSizes.s6),
                              SkeletonBox(width: 70, height: 10, borderRadius: 3),
                            ],
                          ),
                        ),
                        SizedBox(width: AppSizes.s8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SkeletonBox(width: 65, height: 14, borderRadius: 4),
                            SizedBox(height: AppSizes.s6),
                            SkeletonBox(width: 24, height: 24, borderRadius: 12),
                          ],
                        ),
                      ],
                    ),
                  );
                }

                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate900 : Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.r14),
                    border: Border.all(
                      color: isDark ? AppColors.slate800 : AppColors.slate200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Photo container matching real card photo height
                      SkeletonBox(
                        height: photoHeight,
                        width: double.infinity,
                        borderRadius: 13,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.s10, AppSpacing.s8, AppSpacing.s10, AppSpacing.s8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SkeletonBox(width: 110, height: 13, borderRadius: 4),
                            const SizedBox(height: AppSizes.s6),
                            const SkeletonBox(width: 65, height: 10, borderRadius: 3),
                            const SizedBox(height: AppSizes.s10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const SkeletonBox(width: 60, height: 14, borderRadius: 4),
                                SkeletonBox(
                                  width: photoHeight > 140 ? 30 : 24,
                                  height: photoHeight > 140 ? 30 : 24,
                                  borderRadius: 12,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for Master Data Products list (matches ProductTile).
class ProductListSkeleton extends StatelessWidget {
  const ProductListSkeleton({
    super.key,
    this.itemCount = 7,
  });

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: AppSpacing.s96),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: AppSizes.s2),
        itemBuilder: (_, _) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s4),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate800 : Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.r14),
                border: Border.all(
                  color: isDark ? AppColors.slate700 : AppColors.slate200,
                ),
              ),
              child: const Row(
                children: [
                  SkeletonBox(width: 48, height: 48, borderRadius: 8),
                  SizedBox(width: AppSizes.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 140, height: 14, borderRadius: 4),
                        SizedBox(height: AppSizes.s6),
                        Row(
                          children: [
                            SkeletonBox(width: 60, height: 10, borderRadius: 3),
                            SizedBox(width: AppSizes.s8),
                            SkeletonBox(width: 45, height: 14, borderRadius: 4),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SkeletonBox(width: 65, height: 14, borderRadius: 4),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Skeleton for Shifts History list (matches _ShiftCard in shifts_screen.dart).
class ShiftsListSkeleton extends StatelessWidget {
  const ShiftsListSkeleton({
    super.key,
    this.itemCount = 5,
  });

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s4, AppSpacing.s16, AppSpacing.s24),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: AppSizes.s10),
        itemBuilder: (_, _) {
          return Container(
            padding: const EdgeInsets.all(AppSpacing.s14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate800 : Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.r14),
              border: Border.all(
                color: isDark ? AppColors.slate700 : AppColors.slate200,
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top header: user & status badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SkeletonCircle(size: 20),
                        SizedBox(width: AppSizes.s8),
                        SkeletonBox(width: 90, height: 13, borderRadius: 4),
                      ],
                    ),
                    SkeletonBox(width: 75, height: 20, borderRadius: 10),
                  ],
                ),
                SizedBox(height: AppSizes.s12),
                // Middle row: amounts
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 55, height: 10, borderRadius: 3),
                          SizedBox(height: AppSizes.s5),
                          SkeletonBox(width: 95, height: 15, borderRadius: 4),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 55, height: 10, borderRadius: 3),
                          SizedBox(height: AppSizes.s5),
                          SkeletonBox(width: 95, height: 15, borderRadius: 4),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSizes.s12),
                // Bottom row: time and duration
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonBox(width: 120, height: 11, borderRadius: 3),
                    SkeletonBox(width: 65, height: 11, borderRadius: 3),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Skeleton for Sales screen (matches _Summary and SaleTile).
class SalesListSkeleton extends StatelessWidget {
  const SalesListSkeleton({
    super.key,
    this.itemCount = 5,
    this.showSummary = true,
    this.shrinkWrap = false,
    this.physics,
    this.padding,
  });

  final int itemCount;
  final bool showSummary;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppShimmer(
      child: ListView(
        shrinkWrap: shrinkWrap,
        physics: physics ?? (shrinkWrap ? const NeverScrollableScrollPhysics() : const NeverScrollableScrollPhysics()),
        padding: padding ?? const EdgeInsets.only(bottom: AppSpacing.s24),
        children: [
          // Summary card skeleton
          if (showSummary)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s6, AppSpacing.s16, AppSpacing.s8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate800 : Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.r12),
                  border: Border.all(
                    color: isDark ? AppColors.slate700 : AppColors.slate200,
                  ),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 85, height: 11, borderRadius: 3),
                          SizedBox(height: AppSizes.s6),
                          SkeletonBox(width: 140, height: 18, borderRadius: 4),
                        ],
                      ),
                    ),
                    SizedBox(width: AppSizes.s16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SkeletonBox(width: 70, height: 13, borderRadius: 4),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          // Sale tiles skeleton
          ...List.generate(itemCount, (_) {
            return Container(
              margin: EdgeInsets.symmetric(
                horizontal: showSummary ? AppSpacing.s16 : AppSpacing.s0,
                vertical: AppSpacing.s4,
              ),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate800 : Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.r14),
                border: Border.all(
                  color: isDark ? AppColors.slate700 : AppColors.slate200,
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SkeletonBox(width: 100, height: 12, borderRadius: 3),
                      SkeletonBox(width: 60, height: 11, borderRadius: 3),
                    ],
                  ),
                  SizedBox(height: AppSizes.s10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 120, height: 16, borderRadius: 4),
                          SizedBox(height: AppSizes.s4),
                          SkeletonBox(width: 75, height: 11, borderRadius: 3),
                        ],
                      ),
                      SkeletonBox(width: 70, height: 22, borderRadius: 11),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Skeleton for Dashboard screen (matches banner, hero, quick actions, stats grid, and chart).
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppShimmer(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Shift & Sync banner skeleton
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate800 : Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.r12),
              border: Border.all(
                color: isDark ? AppColors.slate700 : AppColors.slate200,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.s12),
          // Today Sales Hero skeleton
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate800 : Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.r16),
              border: Border.all(
                color: isDark ? AppColors.slate700 : AppColors.slate200,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.s14),
          // Quick actions bar skeleton
          Row(
            children: List.generate(4, (_) {
              return Expanded(
                child: Container(
                  height: 46,
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate800 : Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.r10),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: AppSizes.s14),
          // Stats 2x2 grid skeleton
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: List.generate(4, (_) {
              return Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate800 : Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.r12),
                  border: Border.all(
                    color: isDark ? AppColors.slate700 : AppColors.slate200,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for Product Detail screen (matches header with 88x88 photo, specs, and stock section).
class ProductDetailSkeleton extends StatelessWidget {
  const ProductDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppShimmer(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.s16),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Header with 88px photo
          const Row(
            children: [
              SkeletonBox(width: 88, height: 88, borderRadius: 12),
              SizedBox(width: AppSizes.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 160, height: 18, borderRadius: 4),
                    SizedBox(height: AppSizes.s8),
                    SkeletonBox(width: 90, height: 12, borderRadius: 3),
                    SizedBox(height: AppSizes.s12),
                    Row(
                      children: [
                        SkeletonBox(width: 60, height: 20, borderRadius: 10),
                        SizedBox(width: AppSizes.s8),
                        SkeletonBox(width: 70, height: 20, borderRadius: 10),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.s16),
          // Specs Card
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate800 : Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.r16),
              border: Border.all(
                color: isDark ? AppColors.slate700 : AppColors.slate200,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.s16),
          // Stock Card
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate800 : Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.r16),
              border: Border.all(
                color: isDark ? AppColors.slate700 : AppColors.slate200,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
