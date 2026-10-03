import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/launch.dart';
import '../auth_controller.dart';
import '../data/current_user.dart';

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

  @override
  void initState() {
    super.initState();
    // A 402 only marks the cached profile as blocked; /auth/me also carries how to renew.
    if (ref.read(currentUserProvider)?.tenant?.renewal == null) {
      Future.microtask(() => ref.read(authControllerProvider.notifier).refreshProfile());
    }
  }

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
                  if (tenant?.renewal case final renewal? when !renewal.isEmpty) ...[
                    const SizedBox(height: 20),
                    _RenewalCard(renewal: renewal, shopName: tenant?.name ?? ''),
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

class _RenewalCard extends StatelessWidget {
  const _RenewalCard({required this.renewal, required this.shopName});

  final RenewalInfo renewal;
  final String shopName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final contact = renewal.contact ?? '';
    final wa = whatsappNumber(contact);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Cara memperpanjang', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            for (final plan in renewal.plans)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Expanded(child: Text(plan.label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                    Text('${rupiah(plan.price)}/bulan', style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            if ((renewal.paymentInstructions ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              SelectableText(renewal.paymentInstructions!, style: theme.textTheme.bodyMedium),
            ],
            if (contact.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Admin layanan', style: muted),
              SelectableText(contact, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              if (wa != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                  onPressed: () => openExternal(
                    context,
                    Uri.https('wa.me', '/$wa', {'text': 'Halo, saya ingin memperpanjang langganan toko $shopName.'}),
                    failure: 'WhatsApp tidak bisa dibuka.',
                  ),
                  icon: const Icon(LucideIcons.messageCircle, size: 16),
                  label: const Text('Hubungi lewat WhatsApp'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
