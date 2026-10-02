import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/config/server_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/auth_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/current_user.dart';
import '../../offline/offline_queue.dart';
import '../../shift/shift_controller.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref, {bool everywhere = false}) async {
    final hasShift = ref.read(currentShiftProvider).value != null;
    final waiting = ref.read(myQueueProvider).length;
    final confirmed = await confirmAction(
      context,
      title: everywhere ? 'Keluar dari semua perangkat?' : 'Keluar dari aplikasi?',
      message: [
        if (everywhere) 'Semua HP, tablet, dan aplikasi lain yang login dengan akun ini harus login ulang.',
        if (waiting > 0) '$waiting transaksi offline belum terkirim dan baru akan dikirim setelah Anda login lagi dengan akun ini.',
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          MaxWidth(
            width: 640,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Hero Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      if (!isDark)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  '@${user.username}',
                                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    user.roleLabel,
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                                  ),
                                ),
                              ],
                            ),
                            if (user.phone != null && user.phone!.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                user.phone!,
                                style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Ubah profil',
                        icon: const Icon(LucideIcons.pencil, size: 16),
                        onPressed: () => FormSheet.show<void>(context, _ProfileSheet(user: user)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Settings Card
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      if (!isDark)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(LucideIcons.keyRound, size: 18, color: Color(0xFFD97706)),
                        ),
                        title: const Text('Ganti password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('Ubah kata sandi login akun', style: TextStyle(fontSize: 12)),
                        trailing: const Icon(LucideIcons.chevronRight, size: 16, color: Color(0xFF94A3B8)),
                        onTap: () => FormSheet.show<void>(context, const _PasswordSheet()),
                      ),
                      Divider(height: 1, indent: 64, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                      ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(LucideIcons.printer, size: 18, color: Color(0xFF2563EB)),
                        ),
                        title: const Text('Printer struk', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('Bluetooth thermal & tes cetak', style: TextStyle(fontSize: 12)),
                        trailing: const Icon(LucideIcons.chevronRight, size: 16, color: Color(0xFF94A3B8)),
                        onTap: () => context.push('/printer'),
                      ),
                      Divider(height: 1, indent: 64, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                      if (user.tenant case final tenant?) ...[
                        ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(LucideIcons.store, size: 18, color: Color(0xFF059669)),
                          ),
                          title: Text(tenant.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(
                            'Paket ${tenant.planLabel} · ${tenant.accessEndsAt == null ? 'tanpa batas waktu' : 'aktif s/d ${DateFormat('d MMM y', 'id_ID').format(tenant.accessEndsAt!.toLocal())}'}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Divider(height: 1, indent: 64, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                      ],
                      if (!isHosted) ...[
                        ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(LucideIcons.server, size: 18, color: Color(0xFF059669)),
                          ),
                          title: const Text('Server Backend', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(ref.watch(serverUrlProvider), style: const TextStyle(fontSize: 12)),
                        ),
                        Divider(height: 1, indent: 64, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                      ],
                      SwitchListTile(
                        secondary: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(isDark ? LucideIcons.moon : LucideIcons.sun, size: 18, color: const Color(0xFF6366F1)),
                        ),
                        title: const Text('Tema Tampilan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(isDark ? 'Mode gelap aktif' : 'Mode terang aktif', style: const TextStyle(fontSize: 12)),
                        value: isDark,
                        onChanged: (_) {
                          HapticFeedback.selectionClick();
                          ref.read(themeModeProvider.notifier).toggle();
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Logout Actions
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: danger.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _logout(context, ref),
                  icon: Icon(LucideIcons.logOut, size: 18, color: danger),
                  label: Text('Keluar dari Aplikasi', style: TextStyle(color: danger, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 6),
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
