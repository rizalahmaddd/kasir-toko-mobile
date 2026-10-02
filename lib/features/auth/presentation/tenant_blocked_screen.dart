import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../auth_controller.dart';

/// Shown while the shop is suspended or its trial/subscription has ended. Data stays on the
/// server; the owner renews with the service admin and taps "Periksa lagi".
class TenantBlockedScreen extends ConsumerStatefulWidget {
  const TenantBlockedScreen({super.key});

  @override
  ConsumerState<TenantBlockedScreen> createState() => _TenantBlockedScreenState();
}

class _TenantBlockedScreenState extends ConsumerState<TenantBlockedScreen> {
  bool _checking = false;

  static const _messages = {
    'tenant_suspended': 'Toko ini sedang dinonaktifkan. Hubungi admin layanan.',
    'trial_expired': 'Masa uji coba toko ini sudah berakhir. Hubungi admin layanan untuk berlangganan.',
    'subscription_expired': 'Langganan toko ini sudah berakhir. Hubungi admin layanan untuk memperpanjang.',
  };

  Future<void> _check() async {
    setState(() => _checking = true);
    await ref.read(authControllerProvider.notifier).refreshProfile();
    if (mounted) {
      setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenant = ref.watch(currentUserProvider)?.tenant;
    final theme = Theme.of(context);
    final warning = StatusColors.of(context).warning;
    final endsAt = tenant?.accessEndsAt;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(LucideIcons.clockAlert, size: 48, color: warning),
                  const SizedBox(height: 16),
                  Text(
                    '${tenant?.name ?? 'Toko'} belum bisa dipakai',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tenant?.blockedMessage ?? _messages[tenant?.blockedReason] ?? 'Toko ini tidak aktif.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  if (endsAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Masa aktif berakhir ${DateFormat('d MMMM y', 'id_ID').format(endsAt.toLocal())}. Data toko tetap tersimpan.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: _checking ? null : _check,
                    icon: _checking
                        ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(LucideIcons.refreshCw, size: 16),
                    label: const Text('Periksa lagi'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    onPressed: () => ref.read(authControllerProvider.notifier).logout(),
                    child: const Text('Keluar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
