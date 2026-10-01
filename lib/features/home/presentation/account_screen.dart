import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/config/server_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/auth_controller.dart';
import '../../shift/shift_controller.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final hasShift = ref.read(currentShiftProvider).value != null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari aplikasi?'),
        content: Text(
          hasShift
              ? 'Shift Anda masih terbuka dan tidak ikut ditutup. Tutup shift dulu di menu Shift kalau sudah selesai berjualan.'
              : 'Anda perlu login lagi untuk memakai kasir di perangkat ini.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Keluar')),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    if (user == null) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Akun')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.16),
                        child: Text(
                          user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                          style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                            Text(
                              '@${user.username} · ${user.roleLabel}',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(LucideIcons.server, size: 20),
                      title: const Text('Server'),
                      subtitle: Text(ref.watch(serverUrlProvider)),
                    ),
                    const Divider(),
                    SwitchListTile(
                      secondary: Icon(isDark ? LucideIcons.moon : LucideIcons.sun, size: 20),
                      title: const Text('Tema gelap'),
                      value: isDark,
                      onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _logout(context, ref),
                icon: Icon(LucideIcons.logOut, size: 18, color: StatusColors.of(context).danger),
                label: Text('Keluar', style: TextStyle(color: StatusColors.of(context).danger)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
