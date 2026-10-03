import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/image_url_resolver.dart';
import 'app_skeleton.dart';

/// Reusable optimized image widget using CachedNetworkImage.
///
/// Features:
/// - Auto-resolves local/remote backend URLs via [ref.resolveImage]
/// - Hardware-accelerated memory cache sizing ([memCacheWidth], [memCacheHeight])
///   to prevent RAM exhaustion and eliminate the "reloading/flicker" loop
/// - Ultra-fast fade transitions (100ms) with zero fade-out delay
/// - Elegant shimmer skeleton placeholder while loading
/// - Fallback widget on failure or null/empty URL
class AppCachedImage extends ConsumerWidget {
  const AppCachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 8,
    this.memCacheWidth = 300,
    this.memCacheHeight,
    this.fallback,
    this.placeholder,
  });

  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final Widget? fallback;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolvedUrl = ref.resolveImage(imageUrl);

    // Fallback if URL is missing or empty
    if (resolvedUrl == null || resolvedUrl.trim().isEmpty) {
      return fallback ??
          SkeletonBox(
            width: width,
            height: height,
            borderRadius: borderRadius,
          );
    }

    final defaultPlaceholder = placeholder ??
        AppShimmer(
          child: SkeletonBox(
            width: width,
            height: height,
            borderRadius: borderRadius,
          ),
        );

    final imageWidget = CachedNetworkImage(
      imageUrl: resolvedUrl,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 100),
      fadeOutDuration: Duration.zero,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      placeholder: (_, _) => defaultPlaceholder,
      errorWidget: (_, _, _) =>
          fallback ??
          SkeletonBox(
            width: width,
            height: height,
            borderRadius: borderRadius,
          ),
    );

    if (borderRadius > 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}
