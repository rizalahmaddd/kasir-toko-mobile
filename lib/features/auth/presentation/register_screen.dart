import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';

import 'package:web_pos_mobile/core/constants/app_routes.dart';

import '../../../core/config/server_config.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/launch.dart';
import '../../../core/widgets/state_views.dart';
import '../auth_controller.dart';
import 'widgets/social_auth_buttons.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

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
    final isDark = theme.brightness == Brightness.dark;
    final danger = StatusColors.of(context).danger;
    final generalError = _error != null && _fields.every((field) => _error!.fieldError(field) == null) ? _error!.message : null;

    return Scaffold(
      appBar: AppBar(title: const Text(AuthStrings.registerTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s20, AppSpacing.s8, AppSpacing.s20, AppSpacing.s24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AuthStrings.registerIntro,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                    ),
                    const SizedBox(height: AppSizes.s20),
                    TextFormField(
                      controller: _shopName,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: AuthStrings.shopNameLabel,
                        hintText: AuthStrings.shopNameHint,
                        prefixIcon: const Icon(AppIcons.store, size: AppSizes.s18),
                        errorText: _error?.fieldError('shop_name'),
                      ),
                      validator: (value) => _required(value, AuthStrings.shopNameRequired),
                    ),
                    const SizedBox(height: AppSizes.s14),
                    TextFormField(
                      controller: _name,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: AuthStrings.ownerNameLabel,
                        prefixIcon: const Icon(AppIcons.user, size: AppSizes.s18),
                        errorText: _error?.fieldError('name'),
                      ),
                      validator: (value) => _required(value, AuthStrings.ownerNameRequired),
                    ),
                    const SizedBox(height: AppSizes.s14),
                    TextFormField(
                      controller: _username,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: AuthStrings.usernameLabel,
                        prefixIcon: const Icon(AppIcons.atSign, size: AppSizes.s18),
                        errorText: _error?.fieldError('username'),
                      ),
                      validator: (value) => _required(value, AuthStrings.usernameRequired),
                    ),
                    const SizedBox(height: AppSizes.s14),
                    TextFormField(
                      controller: _email,
                      autocorrect: false,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: AuthStrings.emailLabel,
                        prefixIcon: const Icon(AppIcons.mail, size: AppSizes.s18),
                        errorText: _error?.fieldError('email'),
                      ),
                      validator: (value) => _required(value, AuthStrings.emailRequired),
                    ),
                    const SizedBox(height: AppSizes.s14),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: AuthStrings.phoneLabel,
                        hintText: AuthStrings.phoneHint,
                        prefixIcon: const Icon(AppIcons.phone, size: AppSizes.s18),
                        errorText: _error?.fieldError('phone'),
                      ),
                    ),
                    const SizedBox(height: AppSizes.s14),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: AuthStrings.passwordLabel,
                        prefixIcon: const Icon(AppIcons.lockKeyhole, size: AppSizes.s18),
                        errorText: _error?.fieldError('password'),
                        suffixIcon: IconButton(
                          tooltip: _obscure ? AuthStrings.showPasswordTooltip : AuthStrings.hidePasswordTooltip,
                          icon: Icon(_obscure ? AppIcons.eye : AppIcons.eyeOff, size: AppSizes.s18),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (value) => (value ?? '').length < 8 ? AuthStrings.passwordMinLength : null,
                    ),
                    if (generalError != null) ...[
                      const SizedBox(height: AppSizes.s14),
                      Text(generalError, style: TextStyle(color: danger, fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                    const SizedBox(height: AppSizes.s22),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r12)),
                      ),
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox.square(dimension: AppSizes.s20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text(AuthStrings.registerSubmit, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                    SocialAuthButtons(
                      isRegister: true,
                      shopName: _shopName.text.trim().isNotEmpty ? _shopName.text.trim() : null,
                      onError: (error) {
                        if (mounted) {
                          setState(() => _error = error);
                        }
                      },
                    ),
                    const SizedBox(height: AppSizes.s8),
                    TextButton(
                      onPressed: _busy ? null : () => context.go(AppRoutes.login),
                      child: const Text(AuthStrings.alreadyHaveAccount),
                    ),
                    const SizedBox(height: AppSizes.s12),
                    Text.rich(
                      TextSpan(
                        text: LegalStrings.registerAgreement,
                        style: TextStyle(fontSize: 11, color: isDark ? AppColors.slate400 : AppColors.slate500),
                        children: [
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: GestureDetector(
                              onTap: () {
                                final serverUrl = ref.read(serverUrlProvider);
                                final clean = serverUrl.endsWith('/') ? serverUrl.substring(0, serverUrl.length - 1) : serverUrl;
                                openExternal(context, Uri.parse('$clean/terms-of-service'));
                              },
                              child: Text(
                                LegalStrings.termsOfService,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                          const TextSpan(text: LegalStrings.andSeparator),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: GestureDetector(
                              onTap: () {
                                final serverUrl = ref.read(serverUrlProvider);
                                final clean = serverUrl.endsWith('/') ? serverUrl.substring(0, serverUrl.length - 1) : serverUrl;
                                openExternal(context, Uri.parse('$clean/privacy-policy'));
                              },
                              child: Text(
                                LegalStrings.privacyPolicy,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
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
