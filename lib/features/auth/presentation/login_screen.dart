import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _otp = TextEditingController();
  late bool _editingServer = _server.text.isEmpty;
  bool _obscure = true;
  bool _busy = false;
  bool _otpMode = false;
  String? _otpToken;
  String? _maskedPhone;
  int _cooldown = 0;
  Timer? _cooldownTimer;
  ApiException? _error;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _server.dispose();
    _login.dispose();
    _password.dispose();
    _otp.dispose();
    super.dispose();
  }

  void _switchMode() => setState(() {
        _otpMode = !_otpMode;
        _otpToken = null;
        _otp.clear();
        _error = null;
      });

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _cooldown <= 1) {
        timer.cancel();
      }
      if (mounted) {
        setState(() => _cooldown = _cooldown > 0 ? _cooldown - 1 : 0);
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(serverUrlProvider.notifier).save(_server.text);
      await action();
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final auth = ref.read(authControllerProvider.notifier);

    if (!_otpMode) {
      return _run(() => auth.login(login: _login.text.trim(), password: _password.text));
    }
    if (_otpToken == null) {
      return _sendOtp();
    }

    return _run(() => auth.verifyOtp(otpToken: _otpToken!, otp: _otp.text.trim()));
  }

  Future<void> _sendOtp() => _run(() async {
        final challenge = await ref.read(authControllerProvider.notifier).sendOtp(_login.text.trim());
        setState(() {
          _otpToken = challenge.otpToken;
          _maskedPhone = challenge.maskedPhone;
        });
        _startCooldown(challenge.cooldown);
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fieldKeys = ['login', 'password', 'otp', 'otp_token'];
    final generalError = _error != null && fieldKeys.every((key) => _error!.fieldError(key) == null) ? _error!.message : null;
    final waitingCode = _otpMode && _otpToken != null;

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
                      _otpMode ? 'Kode masuk dikirim ke WhatsApp yang terdaftar di akun Anda.' : 'Pakai akun yang sama dengan aplikasi web toko.',
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
                      enabled: !waitingCode,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Username, email, atau nomor HP',
                        prefixIcon: const Icon(LucideIcons.user, size: 18),
                        errorText: _error?.fieldError('login'),
                      ),
                      validator: (value) => (value ?? '').trim().isEmpty ? 'Isi username, email, atau nomor HP.' : null,
                    ),
                    const SizedBox(height: 12),
                    if (!_otpMode)
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
                      )
                    else if (waitingCode) ...[
                      Text('Kode dikirim ke WhatsApp $_maskedPhone.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _otp,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        style: const TextStyle(fontSize: 20, letterSpacing: 6, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          labelText: 'Kode OTP',
                          prefixIcon: const Icon(LucideIcons.messageSquareCode, size: 18),
                          errorText: _error?.fieldError('otp') ?? _error?.fieldError('otp_token'),
                        ),
                        validator: (value) => (value ?? '').trim().length < 4 ? 'Isi kode dari WhatsApp.' : null,
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => setState(() {
                              _otpToken = null;
                              _otp.clear();
                            }),
                            child: const Text('Ganti akun'),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _busy || _cooldown > 0 ? null : _sendOtp,
                            child: Text(_cooldown > 0 ? 'Kirim ulang ($_cooldown)' : 'Kirim ulang kode'),
                          ),
                        ],
                      ),
                    ],
                    if (generalError != null) ...[
                      const SizedBox(height: 12),
                      Text(generalError, style: TextStyle(color: StatusColors.of(context).danger)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(!_otpMode ? 'Masuk' : (waitingCode ? 'Verifikasi & Masuk' : 'Kirim Kode WhatsApp')),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _busy ? null : _switchMode,
                      icon: Icon(_otpMode ? LucideIcons.keyRound : LucideIcons.messageCircle, size: 18),
                      label: Text(_otpMode ? 'Masuk dengan password' : 'Masuk dengan OTP WhatsApp'),
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
