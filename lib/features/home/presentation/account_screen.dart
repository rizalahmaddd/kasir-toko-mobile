import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/config/server_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/auth_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/current_user.dart';
import '../../shift/shift_controller.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref, {bool everywhere = false}) async {
    final hasShift = ref.read(currentShiftProvider).value != null;
    final confirmed = await confirmAction(
      context,
      title: everywhere ? 'Keluar dari semua perangkat?' : 'Keluar dari aplikasi?',
      message: [
        if (everywhere) 'Semua HP, tablet, dan aplikasi lain yang login dengan akun ini harus login ulang.',
        if (hasShift) 'Shift Anda masih terbuka dan tidak ikut ditutup.' else 'Anda perlu login lagi untuk memakai kasir di perangkat ini.',
      ].join(' '),
      confirmLabel: 'Keluar',
      danger: everywhere,
    );

    if (confirmed) {
      final auth = ref.read(authControllerProvider.notifier);
      await (everywhere ? auth.logoutAll() : auth.logout());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final danger = StatusColors.of(context).danger;

    if (user == null) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Akun')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          MaxWidth(
            width: 640,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                        style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w700),
                      ),
                    ),
                    title: Text(user.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    subtitle: Text('@${user.username} · ${user.roleLabel}${user.phone == null ? '' : '\n${user.phone}'}'),
                    trailing: IconButton(
                      tooltip: 'Ubah profil',
                      icon: const Icon(LucideIcons.pencil, size: 18),
                      onPressed: () => FormSheet.show<void>(context, _ProfileSheet(user: user)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(LucideIcons.keyRound, size: 20),
                        title: const Text('Ganti password'),
                        trailing: const Icon(LucideIcons.chevronRight, size: 18),
                        onTap: () => FormSheet.show<void>(context, const _PasswordSheet()),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(LucideIcons.printer, size: 20),
                        title: const Text('Printer struk'),
                        trailing: const Icon(LucideIcons.chevronRight, size: 18),
                        onTap: () => context.push('/printer'),
                      ),
                      const Divider(),
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
                  icon: Icon(LucideIcons.logOut, size: 18, color: danger),
                  label: Text('Keluar', style: TextStyle(color: danger)),
                ),
                TextButton(
                  onPressed: () => _logout(context, ref, everywhere: true),
                  style: TextButton.styleFrom(foregroundColor: theme.colorScheme.onSurfaceVariant),
                  child: const Text('Keluar dari semua perangkat'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSheet extends ConsumerStatefulWidget {
  const _ProfileSheet({required this.user});

  final CurrentUser user;

  @override
  ConsumerState<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends ConsumerState<_ProfileSheet> {
  late final _name = TextEditingController(text: widget.user.name);
  late final _username = TextEditingController(text: widget.user.username);
  late final _email = TextEditingController(text: widget.user.email);
  late final _phone = TextEditingController(text: widget.user.phone);
  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    for (final controller in [_name, _username, _email, _phone]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).updateProfile(
            name: _name.text.trim(),
            username: _username.text.trim(),
            email: _email.text.trim(),
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          );
      if (mounted) {
        Navigator.pop(context);
        showMessage(context, 'Profil disimpan.');
      }
    } on ApiException catch (error) {
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final generalError = _error != null && _error!.fieldErrors.isEmpty ? _error!.message : null;

    return FormSheet(
      title: 'Ubah profil',
      children: [
        TextField(controller: _name, decoration: InputDecoration(labelText: 'Nama', errorText: _error?.fieldError('name'))),
        const SizedBox(height: 12),
        TextField(controller: _username, autocorrect: false, decoration: InputDecoration(labelText: 'Username', errorText: _error?.fieldError('username'))),
        const SizedBox(height: 12),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(labelText: 'Email', errorText: _error?.fieldError('email')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(labelText: 'Nomor HP (untuk OTP WhatsApp)', errorText: _error?.fieldError('phone')),
        ),
        if (generalError != null) ...[const SizedBox(height: 8), Text(generalError, style: TextStyle(color: StatusColors.of(context).danger))],
        const SizedBox(height: 16),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Simpan')),
      ],
    );
  }
}

class _PasswordSheet extends ConsumerStatefulWidget {
  const _PasswordSheet();

  @override
  ConsumerState<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends ConsumerState<_PasswordSheet> {
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _revokeOthers = true;
  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_password.text != _confirm.text) {
      setState(() => _error = ApiException(message: 'Konfirmasi password baru tidak sama.'));
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(authRepositoryProvider).updatePassword(current: _current.text, password: _password.text, revokeOthers: _revokeOthers);
      if (mounted) {
        Navigator.pop(context);
        showMessage(context, 'Password diganti.');
      }
    } on ApiException catch (error) {
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final generalError = _error != null && _error!.fieldErrors.isEmpty ? _error!.message : null;

    return FormSheet(
      title: 'Ganti password',
      children: [
        TextField(
          controller: _current,
          obscureText: true,
          decoration: InputDecoration(labelText: 'Password sekarang', errorText: _error?.fieldError('current_password')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: InputDecoration(labelText: 'Password baru', errorText: _error?.fieldError('password')),
        ),
        const SizedBox(height: 12),
        TextField(controller: _confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Ulangi password baru')),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _revokeOthers,
          onChanged: (value) => setState(() => _revokeOthers = value ?? true),
          title: const Text('Keluarkan perangkat lain'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        if (generalError != null) Text(generalError, style: TextStyle(color: StatusColors.of(context).danger)),
        const SizedBox(height: 8),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Ganti Password')),
      ],
    );
  }
}
