import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_routes.dart';

import '../../../core/config/server_config.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_durations.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/launch.dart';
import '../../../core/widgets/state_views.dart';
import '../auth_controller.dart';
import 'widgets/social_auth_buttons.dart';

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
  late bool _editingServer = _server.text.trim().isEmpty;
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

  void _switchMode(bool otpMode) {
    if (_otpMode == otpMode) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _otpMode = otpMode;
      _otpToken = null;
      _otp.clear();
      _error = null;
    });
  }

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = seconds);
    _cooldownTimer = Timer.periodic(AppDurations.seconds1, (timer) {
      if (!mounted || _cooldown <= 1) {
        timer.cancel();
      }
      if (mounted) {
        setState(() => _cooldown = _cooldown > 0 ? _cooldown - 1 : 0);
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    unawaited(HapticFeedback.lightImpact());
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
      unawaited(HapticFeedback.mediumImpact());
      return;
    }

    final auth = ref.read(authControllerProvider.notifier);
    final authConfig = ref.read(authConfigProvider).value;
    final otpAvailable = authConfig?.otpEnabled ?? false;
    final activeOtpMode = _otpMode && otpAvailable;

    if (!activeOtpMode) {
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
    final authConfig = ref.watch(authConfigProvider).value;
    final otpAvailable = authConfig?.otpEnabled ?? false;
    final activeOtpMode = _otpMode && otpAvailable;
    final waitingCode = activeOtpMode && _otpToken != null;

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate950 : AppColors.slate50,
      body: Stack(
        children: [
          // Ambient decorative glow for top atmospheric feel
          Positioned(
            top: -140,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  width: 500,
                  height: 380,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.emerald500.withValues(alpha: isDark ? 0.08 : 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s20,
                  vertical: AppSpacing.s24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Form(
                    key: _formKey,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.slate900 : Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.r20),
                        border: Border.all(
                          color: isDark ? AppColors.slate800 : AppColors.slate200.withValues(alpha: 0.8),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
                            blurRadius: 28,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: AppColors.emerald500.withValues(alpha: isDark ? 0.04 : 0.02),
                            blurRadius: 40,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s24,
                        vertical: AppSpacing.s28,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Brand Header & Server Status
                          _BrandHeader(
                            showServerConfig: !isHosted,
                            serverUrl: _server.text,
                            isEditingServer: _editingServer,
                            onToggleEditServer: () => setState(() => _editingServer = !_editingServer),
                          ),

                          const SizedBox(height: AppSizes.s20),

                          // Server connection editor if self-hosted and active
                          if (!isHosted && _editingServer) ...[
                            _ServerEditCard(
                              controller: _server,
                              isDark: isDark,
                              onSaved: () => setState(() => _editingServer = false),
                            ),
                            const SizedBox(height: AppSizes.s16),
                          ],

                          // Title and Subtitle with crisp typography
                          Text(
                            activeOtpMode ? AuthStrings.loginTitleOtp : AuthStrings.loginTitlePassword,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: isDark ? Colors.white : AppColors.slate900,
                            ),
                          ),
                          const SizedBox(height: AppSizes.s4),
                          Text(
                            activeOtpMode ? AuthStrings.loginSubtitleOtp : AuthStrings.loginSubtitlePassword,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? AppColors.slate400 : AppColors.slate500,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),

                          if (otpAvailable) ...[
                            const SizedBox(height: AppSizes.s18),

                            // Clean Segmented Method Switcher (Password | WhatsApp OTP)
                            _AuthModeSelector(
                              otpMode: _otpMode,
                              isDark: isDark,
                              disabled: waitingCode || _busy,
                              onChanged: _switchMode,
                            ),
                          ],

                          const SizedBox(height: AppSizes.s20),

                          // Identifier Field (Username / Email / WhatsApp Phone)
                          TextFormField(
                            controller: _login,
                            autocorrect: false,
                            enabled: !waitingCode && !_busy,
                            textInputAction: activeOtpMode ? TextInputAction.done : TextInputAction.next,
                            onFieldSubmitted: activeOtpMode && !waitingCode ? (_) => _submit() : null,
                            decoration: InputDecoration(
                              labelText: AuthStrings.loginIdentifierLabel,
                              hintText: activeOtpMode ? 'Contoh: 08123456789' : null,
                              prefixIcon: Icon(
                                activeOtpMode ? AppIcons.phone : AppIcons.user,
                                size: AppSizes.s18,
                              ),
                              errorText: _error?.fieldError('login'),
                            ),
                            validator: (value) => (value ?? '').trim().isEmpty ? AuthStrings.loginIdentifierRequired : null,
                          ),

                          // Password Field (Password Mode)
                          if (!activeOtpMode) ...[
                            const SizedBox(height: AppSizes.s14),
                            TextFormField(
                              controller: _password,
                              obscureText: _obscure,
                              enabled: !_busy,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                labelText: AuthStrings.passwordLabel,
                                prefixIcon: const Icon(AppIcons.lockKeyhole, size: AppSizes.s18),
                                errorText: _error?.fieldError('password'),
                                suffixIcon: IconButton(
                                  tooltip: _obscure ? AuthStrings.showPasswordTooltip : AuthStrings.hidePasswordTooltip,
                                  icon: Icon(
                                    _obscure ? AppIcons.eye : AppIcons.eyeOff,
                                    size: AppSizes.s18,
                                  ),
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                ),
                              ),
                              validator: (value) => (value ?? '').isEmpty ? AuthStrings.passwordRequired : null,
                            ),
                          ] else if (waitingCode) ...[
                            // OTP Verification Section
                            const SizedBox(height: AppSizes.s14),
                            _OtpNoticeBanner(
                              maskedPhone: _maskedPhone ?? '',
                              isDark: isDark,
                            ),
                            const SizedBox(height: AppSizes.s14),
                            TextFormField(
                              controller: _otp,
                              autofocus: true,
                              enabled: !_busy,
                              keyboardType: TextInputType.number,
                              autofillHints: const [AutofillHints.oneTimeCode],
                              textAlign: TextAlign.center,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(8),
                              ],
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              style: const TextStyle(
                                fontSize: 24,
                                letterSpacing: 8,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: InputDecoration(
                                labelText: AuthStrings.otpLabel,
                                prefixIcon: const Icon(AppIcons.messageSquareCode, size: AppSizes.s18),
                                errorText: _error?.fieldError('otp') ?? _error?.fieldError('otp_token'),
                              ),
                              validator: (value) => (value ?? '').trim().length < 4 ? AuthStrings.otpRequired : null,
                            ),
                            const SizedBox(height: AppSizes.s8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () => setState(() {
                                            _otpToken = null;
                                            _otp.clear();
                                          }),
                                  icon: const Icon(AppIcons.arrowLeft, size: AppSizes.s14),
                                  label: const Text(
                                    AuthStrings.changeAccount,
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _busy || _cooldown > 0 ? null : _sendOtp,
                                  child: Text(
                                    _cooldown > 0 ? AuthStrings.resendCodeCountdown(_cooldown) : AuthStrings.resendCode,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: _cooldown > 0 ? (isDark ? AppColors.slate400 : AppColors.slate500) : theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // General Error Banner
                          if (generalError != null) ...[
                            const SizedBox(height: AppSizes.s16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s14,
                                vertical: AppSpacing.s10,
                              ),
                              decoration: BoxDecoration(
                                color: colors.danger.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppRadius.r12),
                                border: Border.all(color: colors.danger.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 1),
                                    child: Icon(AppIcons.alertCircle, size: AppSizes.s18, color: colors.danger),
                                  ),
                                  const SizedBox(width: AppSizes.s10),
                                  Expanded(
                                    child: Text(
                                      generalError,
                                      style: TextStyle(
                                        color: colors.danger,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: AppSizes.s24),

                          // Primary Action Button with Emerald Gradient
                          _PrimarySubmitButton(
                            busy: _busy,
                            onPressed: _busy ? null : _submit,
                            label: !activeOtpMode
                                ? AuthStrings.submitLogin
                                : (waitingCode ? AuthStrings.submitVerify : AuthStrings.submitSendOtp),
                          ),

                          // Social Sign-in Options
                          SocialAuthButtons(
                            onError: (error) {
                              if (mounted) {
                                setState(() => _error = error);
                              }
                            },
                          ),

                          // Register Link (for SaaS / Hosted Edition)
                          if (isHosted) ...[
                            const SizedBox(height: AppSizes.s14),
                            Center(
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: _busy ? null : () => context.go(AppRoutes.register),
                                child: Text.rich(
                                  TextSpan(
                                    text: 'Belum punya toko? ',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? AppColors.slate400 : AppColors.slate600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'Daftar gratis',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: AppSizes.s20),

                          // Legal Footer Links
                          _LegalFooter(
                            isDark: isDark,
                            onOpenUrl: (path) {
                              final serverUrl = ref.read(serverUrlProvider);
                              final clean = serverUrl.endsWith('/') ? serverUrl.substring(0, serverUrl.length - 1) : serverUrl;
                              openExternal(context, Uri.parse('$clean$path'));
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({
    required this.showServerConfig,
    required this.serverUrl,
    required this.isEditingServer,
    required this.onToggleEditServer,
  });

  final bool showServerConfig;
  final String serverUrl;
  final bool isEditingServer;
  final VoidCallback onToggleEditServer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // App Logo Squircle with Gradient & Shadow
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.r14),
            gradient: const LinearGradient(
              colors: [AppColors.emerald600, AppColors.emerald500],
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.emerald600.withValues(alpha: 0.28),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Icon(AppIcons.store, color: Colors.white, size: AppSizes.s22),
          ),
        ),
        const SizedBox(width: AppSizes.s12),

        // Brand Title & Badge
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    AuthStrings.brandName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: isDark ? Colors.white : AppColors.slate900,
                    ),
                  ),
                  const SizedBox(width: AppSizes.s8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.emerald500.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.r6),
                    ),
                    child: const Text(
                      AuthStrings.brandBadge,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.emerald600,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                AuthStrings.brandTagline,
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? AppColors.slate400 : AppColors.slate500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // Self-Hosted Server Indicator Pill
        if (showServerConfig)
          _ServerPill(
            serverUrl: serverUrl,
            isEditing: isEditingServer,
            isDark: isDark,
            onTap: onToggleEditServer,
          ),
      ],
    );
  }
}

class _ServerPill extends StatelessWidget {
  const _ServerPill({
    required this.serverUrl,
    required this.isEditing,
    required this.isDark,
    required this.onTap,
  });

  final String serverUrl;
  final bool isEditing;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasUrl = serverUrl.trim().isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.r10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s6),
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate800 : AppColors.slate100,
            borderRadius: BorderRadius.circular(AppRadius.r10),
            border: Border.all(
              color: isEditing
                  ? AppColors.emerald500.withValues(alpha: 0.5)
                  : (isDark ? AppColors.slate700 : AppColors.slate200),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasUrl ? AppColors.emerald500 : AppColors.amber500,
                ),
              ),
              const SizedBox(width: AppSizes.s6),
              Icon(
                AppIcons.server,
                size: 13,
                color: isDark ? AppColors.slate300 : AppColors.slate600,
              ),
              const SizedBox(width: 4),
              Icon(
                isEditing ? AppIcons.chevronUp : AppIcons.pencil,
                size: 11,
                color: isDark ? AppColors.slate400 : AppColors.slate500,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServerEditCard extends StatelessWidget {
  const _ServerEditCard({
    required this.controller,
    required this.isDark,
    required this.onSaved,
  });

  final TextEditingController controller;
  final bool isDark;
  final VoidCallback onSaved;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800.withValues(alpha: 0.6) : AppColors.slate50,
        borderRadius: BorderRadius.circular(AppRadius.r14),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.slate200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(AppIcons.server, size: AppSizes.s14, color: AppColors.emerald500),
              const SizedBox(width: AppSizes.s6),
              Text(
                AuthStrings.serverCardLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.slate200 : AppColors.slate800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.s8),
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.url,
            autocorrect: false,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              labelText: AuthStrings.serverAddressLabel,
              hintText: AuthStrings.serverAddressHint,
              prefixIcon: const Icon(AppIcons.server, size: AppSizes.s16),
              suffixIcon: controller.text.trim().isNotEmpty
                  ? IconButton(
                      tooltip: AuthStrings.saveServerTooltip,
                      icon: const Icon(AppIcons.check, size: AppSizes.s18, color: AppColors.emerald500),
                      onPressed: onSaved,
                    )
                  : null,
            ),
            validator: (value) => (value ?? '').trim().isEmpty ? AuthStrings.serverAddressRequired : null,
          ),
        ],
      ),
    );
  }
}

class _AuthModeSelector extends StatelessWidget {
  const _AuthModeSelector({
    required this.otpMode,
    required this.isDark,
    required this.disabled,
    required this.onChanged,
  });

  final bool otpMode;
  final bool isDark;
  final bool disabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : AppColors.slate100,
        borderRadius: BorderRadius.circular(AppRadius.r12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeTabItem(
              label: 'Password',
              icon: AppIcons.lockKeyhole,
              isSelected: !otpMode,
              isDark: isDark,
              disabled: disabled,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _ModeTabItem(
              label: 'WhatsApp OTP',
              icon: AppIcons.messageSquare,
              isSelected: otpMode,
              isDark: isDark,
              disabled: disabled,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeTabItem extends StatelessWidget {
  const _ModeTabItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isDark,
    required this.disabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isDark;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeBg = isDark ? AppColors.slate700 : Colors.white;
    final activeFg = isDark ? Colors.white : AppColors.emerald600;
    final inactiveFg = isDark ? AppColors.slate400 : AppColors.slate500;

    return AnimatedContainer(
      duration: AppDurations.milliseconds200,
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isSelected ? activeBg : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.r10),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.r10),
          onTap: disabled ? null : onTap,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: AppSizes.s14,
                  color: isSelected ? activeFg : inactiveFg,
                ),
                const SizedBox(width: AppSizes.s6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? activeFg : inactiveFg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OtpNoticeBanner extends StatelessWidget {
  const _OtpNoticeBanner({
    required this.maskedPhone,
    required this.isDark,
  });

  final String maskedPhone;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s10,
      ),
      decoration: BoxDecoration(
        color: AppColors.whatsappGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: AppColors.whatsappGreen.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(AppIcons.messageSquare, size: AppSizes.s18, color: AppColors.whatsappGreen),
          const SizedBox(width: AppSizes.s10),
          Expanded(
            child: Text(
              AuthStrings.otpSentInfo(maskedPhone),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.slate200 : AppColors.slate800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimarySubmitButton extends StatelessWidget {
  const _PrimarySubmitButton({
    required this.busy,
    required this.onPressed,
    required this.label,
  });

  final bool busy;
  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.r14),
        gradient: isEnabled
            ? const LinearGradient(
                colors: [AppColors.emerald600, AppColors.emerald500],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: AppColors.emerald600.withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: isEnabled ? Colors.transparent : null,
          shadowColor: Colors.transparent,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r14)),
        ),
        onPressed: onPressed,
        child: busy
            ? const SizedBox.square(
                dimension: AppSizes.s20,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

class _LegalFooter extends StatelessWidget {
  const _LegalFooter({
    required this.isDark,
    required this.onOpenUrl,
  });

  final bool isDark;
  final ValueChanged<String> onOpenUrl;

  @override
  Widget build(BuildContext context) {
    final linkColor = isDark ? AppColors.slate400 : AppColors.slate500;

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.s8,
      children: [
        GestureDetector(
          onTap: () => onOpenUrl('/privacy-policy'),
          child: Text(
            LegalStrings.privacyPolicy,
            style: TextStyle(
              fontSize: 11.5,
              color: linkColor,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        Text(
          LegalStrings.bulletSeparator,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? AppColors.slate600 : AppColors.slate400,
          ),
        ),
        GestureDetector(
          onTap: () => onOpenUrl('/terms-of-service'),
          child: Text(
            LegalStrings.termsOfService,
            style: TextStyle(
              fontSize: 11.5,
              color: linkColor,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}

