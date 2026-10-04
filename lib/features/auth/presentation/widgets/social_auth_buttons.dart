import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_fonts.dart';
import 'package:web_pos_mobile/core/constants/status_values.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../auth_controller.dart';
import '../../data/auth_config.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

class SocialAuthButtons extends ConsumerStatefulWidget {
  const SocialAuthButtons({
    super.key,
    this.isRegister = false,
    this.shopName,
    this.onError,
  });

  final bool isRegister;
  final String? shopName;
  final ValueChanged<ApiException>? onError;

  @override
  ConsumerState<SocialAuthButtons> createState() => _SocialAuthButtonsState();
}

class _SocialAuthButtonsState extends ConsumerState<SocialAuthButtons> {
  bool _busy = false;
  String? _loadingProvider;

  Future<void> _handleGoogle() async {
    if (_busy) return;
    unawaited(HapticFeedback.lightImpact());
    setState(() {
      _busy = true;
      _loadingProvider = AuthProviders.google;
    });

    try {
      await ref.read(authControllerProvider.notifier).signInWithGoogle(
            shopName: widget.shopName,
          );
    } on ApiException catch (e) {
      widget.onError?.call(e);
    } catch (e) {
      widget.onError?.call(ApiException(message: AuthStrings.socialGoogleError(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _loadingProvider = null;
        });
      }
    }
  }

  Future<void> _handleApple() async {
    if (_busy) return;
    unawaited(HapticFeedback.lightImpact());
    setState(() {
      _busy = true;
      _loadingProvider = AuthProviders.apple;
    });

    try {
      await ref.read(authControllerProvider.notifier).signInWithApple(
            shopName: widget.shopName,
          );
    } on ApiException catch (e) {
      widget.onError?.call(e);
    } catch (e) {
      widget.onError?.call(ApiException(message: AuthStrings.socialAppleError(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _loadingProvider = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(authConfigProvider);
    final config = configAsync.value ?? AuthConfig.empty;

    final isIOS = defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS;
    final showGoogle = config.googleEnabled;
    final showApple = config.appleEnabled && isIOS;

    if (!showGoogle && !showApple) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final actionLabel = widget.isRegister ? AuthStrings.socialActionRegister : AuthStrings.socialActionLogin;
    final dividerText = widget.isRegister ? AuthStrings.socialDividerRegister : AuthStrings.socialDividerLogin;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSizes.s20),
        Row(
          children: [
            Expanded(child: Divider(color: isDark ? AppColors.slate800 : AppColors.slate200)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
              child: Text(
                dividerText,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.slate400 : AppColors.slate500,
                ),
              ),
            ),
            Expanded(child: Divider(color: isDark ? AppColors.slate800 : AppColors.slate200)),
          ],
        ),
        const SizedBox(height: AppSizes.s16),
        if (showApple) ...[
          _AppleButton(
            isDark: isDark,
            busy: _busy && _loadingProvider == AuthProviders.apple,
            label: AuthStrings.continueWithApple(actionLabel),
            onPressed: _busy ? null : _handleApple,
          ),
          if (showGoogle) const SizedBox(height: AppSizes.s10),
        ],
        if (showGoogle)
          _GoogleButton(
            isDark: isDark,
            busy: _busy && _loadingProvider == AuthProviders.google,
            label: AuthStrings.continueWithGoogle(actionLabel),
            onPressed: _busy ? null : _handleGoogle,
          ),
      ],
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({
    required this.isDark,
    required this.busy,
    required this.label,
    required this.onPressed,
  });

  final bool isDark;
  final bool busy;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r12)),
        side: BorderSide(
          color: isDark ? AppColors.slate700 : AppColors.slate300,
        ),
        backgroundColor: isDark ? AppColors.slate900 : Colors.white,
      ),
      onPressed: onPressed,
      child: busy
          ? SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: isDark ? Colors.white : AppColors.slate800,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _GoogleLogo(),
                const SizedBox(width: AppSizes.s10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.slate800,
                  ),
                ),
              ],
            ),
    );
  }
}

class _AppleButton extends StatelessWidget {
  const _AppleButton({
    required this.isDark,
    required this.busy,
    required this.label,
    required this.onPressed,
  });

  final bool isDark;
  final bool busy;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // Apple Human Interface Guidelines: Black on light mode, White on dark mode
    final bgColor = isDark ? Colors.white : Colors.black;
    final fgColor = isDark ? Colors.black : Colors.white;

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r12)),
        backgroundColor: bgColor,
        foregroundColor: fgColor,
        elevation: 0,
      ),
      onPressed: onPressed,
      child: busy
          ? SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: fgColor,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(AppIcons.apple, size: AppSizes.s20, color: fgColor),
                const SizedBox(width: AppSizes.s8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: fgColor,
                  ),
                ),
              ],
            ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Text(
        AuthStrings.googleLogoLetter,
        style: TextStyle(
          color: AppColors.googleBlue,
          fontWeight: FontWeight.w900,
          fontSize: 13,
          fontFamily: AppFonts.sansSerif,
        ),
      ),
    );
  }
}
