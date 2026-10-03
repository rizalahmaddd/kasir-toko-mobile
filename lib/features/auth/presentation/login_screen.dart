import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
    final isDark = theme.brightness == Brightness.dark;
    final colors = StatusColors.of(context);
    final fieldKeys = ['login', 'password', 'otp', 'otp_token'];
    final generalError = _error != null && fieldKeys.every((key) => _error!.fieldError(key) == null) ? _error!.message : null;
    final waitingCode = _otpMode && _otpToken != null;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      if (!isDark)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Brand Header
                      const _BrandHeader(),
                      const SizedBox(height: 20),

                      Text(
                        _otpMode ? 'Masuk via WhatsApp' : 'Masuk ke Kasir',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _otpMode
                            ? 'Kode verifikasi sekali pakai akan dikirim ke WhatsApp Anda.'
                            : 'Gunakan akun kasir atau manajer yang terdaftar pada sistem.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Server Connection Summary / Edit (hosted builds share one fixed server)
                      if (!isHosted) ...[
                        if (_editingServer)
                          TextFormField(
                            controller: _server,
                            keyboardType: TextInputType.url,
                            autocorrect: false,
                            decoration: InputDecoration(
                              labelText: 'Alamat Server',
                              hintText: '192.168.1.10:8000 atau pos.toko.com',
                              prefixIcon: const Icon(LucideIcons.server, size: 18),
                              suffixIcon: _server.text.trim().isNotEmpty
                                  ? IconButton(
                                      tooltip: 'Simpan Alamat',
                                      icon: const Icon(LucideIcons.check, size: 18),
                                      onPressed: () => setState(() => _editingServer = false),
                                    )
                                  : null,
                            ),
                            validator: (value) => (value ?? '').trim().isEmpty ? 'Isi alamat server toko.' : null,
                          )
                        else
                          _ServerSummary(
                            url: _server.text,
                            onEdit: () => setState(() => _editingServer = true),
                          ),

                        const SizedBox(height: 14),
                      ],

                      // Login Field (Username / Email / Phone)
                      TextFormField(
                        controller: _login,
                        autocorrect: false,
                        enabled: !waitingCode,
                        textInputAction: _otpMode ? TextInputAction.done : TextInputAction.next,
                        onFieldSubmitted: _otpMode && !waitingCode ? (_) => _submit() : null,
                        decoration: InputDecoration(
                          labelText: 'Username, email, atau no. HP',
                          prefixIcon: const Icon(LucideIcons.user, size: 18),
                          errorText: _error?.fieldError('login'),
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty ? 'Isi username, email, atau nomor HP.' : null,
                      ),

                      // Password Field
                      if (!_otpMode) ...[
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
                          validator: (value) => (value ?? '').isEmpty ? 'Isi password.' : null,
                        ),
                      ] else if (waitingCode) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF25D366).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.messageSquare, size: 18, color: Color(0xFF25D366)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Kalau akun terdaftar, kode verifikasi dikirim ke $_maskedPhone.',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _otp,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(8),
                          ],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          style: const TextStyle(fontSize: 22, letterSpacing: 6, fontWeight: FontWeight.w700),
                          decoration: InputDecoration(
                            labelText: 'Kode OTP WhatsApp',
                            prefixIcon: const Icon(LucideIcons.messageSquareCode, size: 18),
                            errorText: _error?.fieldError('otp') ?? _error?.fieldError('otp_token'),
                          ),
                          validator: (value) => (value ?? '').trim().length < 4 ? 'Isi kode verifikasi dari WhatsApp.' : null,
                        ),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () => setState(() {
                                _otpToken = null;
                                _otp.clear();
                              }),
                              icon: const Icon(LucideIcons.arrowLeft, size: 14),
                              label: const Text('Ganti akun', style: TextStyle(fontSize: 13)),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: _busy || _cooldown > 0 ? null : _sendOtp,
                              child: Text(
                                _cooldown > 0 ? 'Kirim ulang ($_cooldown)' : 'Kirim ulang kode',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ],

                      // General Error Banner
                      if (generalError != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: colors.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colors.danger.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(LucideIcons.alertCircle, size: 18, color: colors.danger),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  generalError,
                                  style: TextStyle(color: colors.danger, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 22),

                      // Submit Button
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(
                                !_otpMode ? 'Masuk' : (waitingCode ? 'Verifikasi & Masuk' : 'Kirim Kode WhatsApp'),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                      ),
                      const SizedBox(height: 12),

                      // Mode Switch Button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _busy ? null : _switchMode,
                        icon: Icon(_otpMode ? LucideIcons.keyRound : LucideIcons.messageCircle, size: 16),
                        label: Text(
                          _otpMode ? 'Masuk dengan Password' : 'Masuk via OTP WhatsApp',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (isHosted) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _busy ? null : () => context.go('/register'),
                          child: const Text('Belum punya toko? Daftar gratis', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [AppColors.emerald600, AppColors.emerald500],
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.emerald600.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(LucideIcons.store, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'POS Kasir',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AppColors.emerald500.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'MOBILE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppColors.emerald600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 1),
            const Text(
              'Sistem Kasir & Point of Sale',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.slate500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
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
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Server Toko',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.slate400 : AppColors.slate500,
                  ),
                ),
                Text(
                  url.isEmpty ? 'Belum diatur' : url,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.slate200 : AppColors.slate800,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            onPressed: onEdit,
            child: const Text('Ganti', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

