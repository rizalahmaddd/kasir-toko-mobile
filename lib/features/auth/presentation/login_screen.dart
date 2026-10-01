import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/config/server_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/state_views.dart';
import '../auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _server = TextEditingController(text: ref.read(serverUrlProvider));
  final _login = TextEditingController();
  final _password = TextEditingController();
  late bool _editingServer = _server.text.isEmpty;
  bool _obscure = true;
  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    _server.dispose();
    _login.dispose();
    _password.dispose();
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
      await ref.read(serverUrlProvider.notifier).save(_server.text);
      await ref.read(authControllerProvider.notifier).login(login: _login.text.trim(), password: _password.text);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _editingServer = _editingServer || error.isNetworkError;
        });
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final generalError = _error != null && _error!.fieldError('login') == null && _error!.fieldError('password') == null
        ? _error!.message
        : null;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _BrandMark(),
                    const SizedBox(height: 24),
                    Text('Masuk ke kasir', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      'Pakai akun yang sama dengan aplikasi web toko.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),
                    if (_editingServer)
                      TextFormField(
                        controller: _server,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Alamat server',
                          hintText: '192.168.1.10:8000 atau kasir.tokoanda.com',
                          prefixIcon: Icon(LucideIcons.server, size: 18),
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty ? 'Isi alamat server toko.' : null,
                      )
                    else
                      _ServerSummary(url: _server.text, onEdit: () => setState(() => _editingServer = true)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _login,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Username, email, atau nomor HP',
                        prefixIcon: const Icon(LucideIcons.user, size: 18),
                        errorText: _error?.fieldError('login'),
                      ),
                      validator: (value) => (value ?? '').trim().isEmpty ? 'Isi username, email, atau nomor HP.' : null,
                    ),
                    const SizedBox(height: 12),
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
                      validator: (value) => (value ?? '').isEmpty ? 'Isi password.' : null,
                    ),
                    if (generalError != null) ...[
                      const SizedBox(height: 12),
                      Text(generalError, style: TextStyle(color: StatusColors.of(context).danger)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Masuk'),
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

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [AppColors.emerald600, AppColors.emerald400],
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
          ),
        ),
        child: const Icon(LucideIcons.store, color: Colors.white),
      ),
    );
  }
}

class _ServerSummary extends StatelessWidget {
  const _ServerSummary({required this.url, required this.onEdit});

  final String url;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(LucideIcons.server, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            url,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        TextButton(onPressed: onEdit, child: const Text('Ganti server')),
      ],
    );
  }
}
