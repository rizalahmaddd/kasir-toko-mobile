import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/state_views.dart';
import '../auth_controller.dart';

/// Signs a new shop up on the hosted service; the account becomes the shop's owner.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopName = TextEditingController();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  ApiException? _error;

  static const _fields = ['shop_name', 'name', 'username', 'email', 'phone', 'password'];

  @override
  void dispose() {
    for (final controller in [_shopName, _name, _username, _email, _phone, _password]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).register(
            shopName: _shopName.text.trim(),
            name: _name.text.trim(),
            username: _username.text.trim().toLowerCase(),
            email: _email.text.trim().toLowerCase(),
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            password: _password.text,
          );
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    } catch (error) {
      if (mounted) {
        showError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String? _required(String? value, String message) => (value ?? '').trim().isEmpty ? message : null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final danger = StatusColors.of(context).danger;
    final generalError = _error != null && _fields.every((field) => _error!.fieldError(field) == null) ? _error!.message : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Toko Baru')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Coba gratis selama masa uji coba. Akun ini jadi pemilik toko dan bisa menambah kasir sendiri.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _shopName,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Nama toko',
                        hintText: 'Contoh: Toko Sumber Rejeki',
                        prefixIcon: const Icon(LucideIcons.store, size: 18),
                        errorText: _error?.fieldError('shop_name'),
                      ),
                      validator: (value) => _required(value, 'Isi nama toko.'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _name,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Nama pemilik',
                        prefixIcon: const Icon(LucideIcons.user, size: 18),
                        errorText: _error?.fieldError('name'),
                      ),
                      validator: (value) => _required(value, 'Isi nama pemilik.'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _username,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        prefixIcon: const Icon(LucideIcons.atSign, size: 18),
                        errorText: _error?.fieldError('username'),
                      ),
                      validator: (value) => _required(value, 'Isi username.'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _email,
                      autocorrect: false,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(LucideIcons.mail, size: 18),
                        errorText: _error?.fieldError('email'),
                      ),
                      validator: (value) => _required(value, 'Isi email.'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Nomor HP (opsional)',
                        hintText: '081234567890',
                        prefixIcon: const Icon(LucideIcons.phone, size: 18),
                        errorText: _error?.fieldError('phone'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(LucideIcons.lockKeyhole, size: 18),
                        errorText: _error?.fieldError('password'),
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Tampilkan password' : 'Sembunyikan password',
                          icon: Icon(_obscure ? LucideIcons.eye : LucideIcons.eyeOff, size: 18),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (value) => (value ?? '').length < 8 ? 'Password minimal 8 karakter.' : null,
                    ),
                    if (generalError != null) ...[
                      const SizedBox(height: 14),
                      Text(generalError, style: TextStyle(color: danger, fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Daftar & Mulai', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy ? null : () => context.go('/login'),
                      child: const Text('Sudah punya akun? Masuk'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
