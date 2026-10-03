import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../network/api_exception.dart';
import '../theme/app_theme.dart';
import 'app_skeleton.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.description, this.action});

  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            if (description != null) ...[
              const SizedBox(height: 4),
              Text(
                description!,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: LucideIcons.circleAlert,
      title: 'Gagal memuat data',
      description: errorMessage(error),
      action: onRetry == null
          ? null
          : OutlinedButton.icon(onPressed: onRetry, icon: const Icon(LucideIcons.refreshCw, size: 18), label: const Text('Coba Lagi')),
    );
  }
}

/// Loading / error / data switch with a consistent look for every list and detail screen.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.loading,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    return switch (value) {
      AsyncData(:final value) => data(value),
      AsyncError(:final error) => ErrorState(error: error, onRetry: onRetry),
      _ => loading ?? const DefaultListSkeleton(),
    };
  }
}

String errorMessage(Object error) => error is ApiException ? error.message : 'Terjadi kesalahan. Coba lagi.';

void showMessage(BuildContext context, String message, {bool isError = false}) {
  final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? StatusColors.of(context).danger : null,
    ),
  );
}

void showError(BuildContext context, Object error) => showMessage(context, errorMessage(error), isError: true);

enum BadgeTone { success, warning, danger, info, muted }

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, this.tone = BadgeTone.muted});

  final String label;
  final BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = StatusColors.of(context);
    final color = switch (tone) {
      BadgeTone.success => colors.success,
      BadgeTone.warning => colors.warning,
      BadgeTone.danger => colors.danger,
      BadgeTone.info => colors.info,
      BadgeTone.muted => colors.muted,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3),
      ),
    );
  }
}
