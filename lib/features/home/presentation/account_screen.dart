import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_routes.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';
import 'package:web_pos_mobile/core/constants/date_formats.dart';

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
import 'about_sheet.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key, this.scrollToDelete = false});

  final bool scrollToDelete;

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _scrollController = ScrollController();
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    if (widget.scrollToDelete) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToDeleteAccount();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToDeleteAccount() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openAboutSheet(BuildContext context) async {
    final result = await AboutSheet.show<String>(context);
    if (result == 'delete_account') {
      await Future.delayed(const Duration(milliseconds: 180));
      if (mounted) {
        _scrollToDeleteAccount();
      }
    }
  }

  Future<void> _logout(BuildContext context, {bool everywhere = false}) async {
    if (_isLoggingOut) return;

    final hasShift = ref.read(currentShiftProvider).value != null;
    final waiting = ref.read(myQueueProvider).length;
    final confirmed = await confirmAction(
      context,
      title: everywhere ? HomeStrings.logoutAllDialogTitle : HomeStrings.logoutDialogTitle,
      message: [
        if (everywhere) HomeStrings.logoutAllWarning,
        if (waiting > 0) HomeStrings.logoutOfflineWarning(waiting),
        if (hasShift) HomeStrings.logoutShiftOpenWarning else HomeStrings.logoutReloginWarning,
      ].join(' '),
      confirmLabel: HomeStrings.logoutConfirmLabel,
      danger: everywhere,
    );

    if (confirmed && context.mounted) {
      setState(() => _isLoggingOut = true);
      final isDark = Theme.of(context).brightness == Brightness.dark;

      unawaited(
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => PopScope(
            canPop: false,
            child: Dialog(
              backgroundColor: isDark ? AppColors.slate800 : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24, vertical: AppSpacing.s20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox.square(
                      dimension: AppSizes.s22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    const SizedBox(width: AppSizes.s16),
                    Flexible(
                      child: Text(
                        everywhere ? HomeStrings.logoutAllLoading : HomeStrings.logoutLoading,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      try {
        final auth = ref.read(authControllerProvider.notifier);
        await (everywhere ? auth.logoutAll() : auth.logout());
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal keluar: $e'),
              backgroundColor: StatusColors.of(context).danger,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoggingOut = false);
        }
      }
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const _ConfirmDeleteAccountDialog(),
    );

    if (confirmed == true && context.mounted) {
      unawaited(
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const PopScope(
            canPop: false,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );

      try {
        await ref.read(authControllerProvider.notifier).deleteAccount();
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(HomeStrings.deleteAccountFailed(e)),
              backgroundColor: StatusColors.of(context).danger,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final danger = StatusColors.of(context).danger;

    if (user == null) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(title: const Text(HomeStrings.accountTitle)),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s8, AppSpacing.s16, AppSpacing.s32),
        children: [
          MaxWidth(
            width: 640,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Hero Card
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s18),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate800 : Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.r16),
                    border: Border.all(
                      color: isDark ? AppColors.slate700 : AppColors.slate200,
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
                          color: isDark ? AppColors.blue900.withValues(alpha: 0.4) : AppColors.blue100,
                          borderRadius: BorderRadius.circular(AppRadius.r14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          user.name.isEmpty ? HomeStrings.accountNameInitialFallback : user.name[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.blue600,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSizes.s14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                            const SizedBox(height: AppSizes.s4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  HomeStrings.accountUsernameHandle(user.username),
                                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: AppSpacing.s1_5),
                                  decoration: BoxDecoration(
                                    color: AppColors.emerald500.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(AppRadius.r5),
                                  ),
                                  child: Text(
                                    user.roleLabel,
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.emerald600),
                                  ),
                                ),
                              ],
                            ),
                            if (user.phone != null && user.phone!.isNotEmpty) ...[
                              const SizedBox(height: AppSizes.s3),
                              Text(
                                user.phone!,
                                style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: HomeStrings.accountEditProfileTooltip,
                        icon: const Icon(AppIcons.pencil, size: AppSizes.s16),
                        onPressed: () => FormSheet.show<void>(context, _ProfileSheet(user: user)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSizes.s18),

                // Settings Card
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate800 : Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.r16),
                    border: Border.all(
                      color: isDark ? AppColors.slate700 : AppColors.slate200,
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
                  child: Material(
                    color: Colors.transparent,
                    child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.amber500.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.r10),
                          ),
                          child: const Icon(AppIcons.keyRound, size: AppSizes.s18, color: AppColors.amber600),
                        ),
                        title: const Text(HomeStrings.accountChangePasswordTitle, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text(HomeStrings.accountChangePasswordSubtitle, style: TextStyle(fontSize: 12)),
                        trailing: const Icon(AppIcons.chevronRight, size: AppSizes.s16, color: AppColors.slate400),
                        onTap: () => FormSheet.show<void>(context, const _PasswordSheet()),
                      ),
                      Divider(height: 1, indent: 64, color: isDark ? AppColors.slate700 : AppColors.slate100),
                      ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.blue500.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.r10),
                          ),
                          child: const Icon(AppIcons.printer, size: AppSizes.s18, color: AppColors.blue600),
                        ),
                        title: const Text(HomeStrings.accountReceiptPrinterTitle, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text(HomeStrings.accountReceiptPrinterSubtitle, style: TextStyle(fontSize: 12)),
                        trailing: const Icon(AppIcons.chevronRight, size: AppSizes.s16, color: AppColors.slate400),
                        onTap: () => context.push(AppRoutes.printer),
                      ),
                      Divider(height: 1, indent: 64, color: isDark ? AppColors.slate700 : AppColors.slate100),
                      if (user.tenant case final tenant?) ...[
                        ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.emerald500.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppRadius.r10),
                            ),
                            child: const Icon(AppIcons.store, size: AppSizes.s18, color: AppColors.emerald600),
                          ),
                          title: Text(tenant.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(
                            HomeStrings.tenantPlanSubtitle(
                              tenant.planLabel,
                              tenant.accessEndsAt == null ? null : DateFormat(AppDateFormat.dateShort, AppDateFormat.locale).format(tenant.accessEndsAt!.toLocal()),
                            ),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Divider(height: 1, indent: 64, color: isDark ? AppColors.slate700 : AppColors.slate100),
                      ],
                      if (!isHosted) ...[
                        ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.emerald500.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppRadius.r10),
                            ),
                            child: const Icon(AppIcons.server, size: AppSizes.s18, color: AppColors.emerald600),
                          ),
                          title: const Text(HomeStrings.accountServerBackendTitle, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(ref.watch(serverUrlProvider), style: const TextStyle(fontSize: 12)),
                        ),
                        Divider(height: 1, indent: 64, color: isDark ? AppColors.slate700 : AppColors.slate100),
                      ],
                      AppSwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s4),
                        secondary: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.indigo500.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.r10),
                          ),
                          child: Icon(isDark ? AppIcons.moon : AppIcons.sun, size: AppSizes.s18, color: AppColors.indigo500),
                        ),
                        title: const Text(HomeStrings.accountThemeTitle, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(isDark ? HomeStrings.accountThemeDarkActive : HomeStrings.accountThemeLightActive, style: const TextStyle(fontSize: 12)),
                        value: isDark,
                        onChanged: (_) {
                          HapticFeedback.selectionClick();
                          ref.read(themeModeProvider.notifier).toggle();
                        },
                      ),
                      Divider(height: 1, indent: 64, color: isDark ? AppColors.slate700 : AppColors.slate100),
                      ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.sky500.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.r10),
                          ),
                          child: const Icon(AppIcons.info, size: AppSizes.s18, color: AppColors.sky600),
                        ),
                        title: const Text(HomeStrings.accountAboutTitle, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text(HomeStrings.accountAboutSubtitle, style: TextStyle(fontSize: 12)),
                        trailing: const Icon(AppIcons.chevronRight, size: AppSizes.s16, color: AppColors.slate400),
                        onTap: () => _openAboutSheet(context),
                      ),
                    ],
                  ),
                ),
                ),

                const SizedBox(height: AppSizes.s20),

                // Logout Actions
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
                    side: BorderSide(color: danger.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r12)),
                  ),
                  onPressed: _isLoggingOut ? null : () => _logout(context),
                  icon: _isLoggingOut
                      ? SizedBox.square(
                          dimension: AppSizes.s18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: danger),
                        )
                      : Icon(AppIcons.logOut, size: AppSizes.s18, color: danger),
                  label: Text(
                    _isLoggingOut ? HomeStrings.logoutLoading : HomeStrings.accountLogoutButton,
                    style: TextStyle(color: danger, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: AppSizes.s6),
                TextButton(
                  onPressed: _isLoggingOut ? null : () => _logout(context, everywhere: true),
                  style: TextButton.styleFrom(foregroundColor: theme.colorScheme.onSurfaceVariant),
                  child: const Text(HomeStrings.accountLogoutAllButton),
                ),
                const SizedBox(height: AppSizes.s24),

                // Danger Zone Section (Apple App Store Guideline 5.1.1(v))
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  decoration: BoxDecoration(
                    color: danger.withValues(alpha: isDark ? 0.12 : 0.06),
                    borderRadius: BorderRadius.circular(AppRadius.r16),
                    border: Border.all(
                      color: danger.withValues(alpha: isDark ? 0.35 : 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(AppIcons.alertTriangle, size: AppSizes.s18, color: danger),
                          const SizedBox(width: AppSizes.s8),
                          Text(
                            HomeStrings.dangerZoneTitle,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: danger,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.s6),
                      Text(
                        HomeStrings.dangerZoneDescription,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.slate300 : AppColors.slate600,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: AppSizes.s14),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: danger,
                          side: BorderSide(color: danger, width: 1.2),
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r10)),
                        ),
                        onPressed: () => _deleteAccount(context),
                        icon: Icon(AppIcons.trash2, size: AppSizes.s16, color: danger),
                        label: const Text(
                          HomeStrings.deleteAccountConfirmLabel,
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmDeleteAccountDialog extends StatefulWidget {
  const _ConfirmDeleteAccountDialog();

  @override
  State<_ConfirmDeleteAccountDialog> createState() => _ConfirmDeleteAccountDialogState();
}

class _ConfirmDeleteAccountDialogState extends State<_ConfirmDeleteAccountDialog> {
  final _controller = TextEditingController();
  bool _canDelete = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final matches = value.trim().toUpperCase() == HomeStrings.deleteAccountKeyword;
    if (_canDelete != matches) {
      setState(() => _canDelete = matches);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final danger = StatusColors.of(context).danger;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s8),
            decoration: BoxDecoration(
              color: danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.r10),
            ),
            child: Icon(AppIcons.trash2, size: AppSizes.s20, color: danger),
          ),
          const SizedBox(width: AppSizes.s10),
          const Expanded(
            child: Text(
              HomeStrings.deleteAccountDialogTitle,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              HomeStrings.deleteAccountDialogMessage,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.slate300 : AppColors.slate600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSizes.s16),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s10),
              decoration: BoxDecoration(
                color: danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.r10),
                border: Border.all(color: danger.withValues(alpha: 0.2)),
              ),
              child: Text(
                HomeStrings.deleteAccountPrompt,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: danger,
                ),
              ),
            ),
            const SizedBox(height: AppSizes.s12),
            TextField(
              controller: _controller,
              autofocus: true,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              onChanged: _onChanged,
              decoration: const InputDecoration(
                hintText: HomeStrings.deleteAccountHint,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(CoreStrings.actionCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: danger,
            foregroundColor: Colors.white,
            disabledBackgroundColor: danger.withValues(alpha: 0.3),
            disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
          ),
          onPressed: _canDelete ? () => Navigator.of(context).pop(true) : null,
          child: const Text(
            HomeStrings.deleteAccountConfirmLabel,
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
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
        showMessage(context, HomeStrings.profileSavedMessage);
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
      title: HomeStrings.profileSheetTitle,
      children: [
        TextField(controller: _name, decoration: InputDecoration(labelText: HomeStrings.profileNameLabel, errorText: _error?.fieldError('name'))),
        const SizedBox(height: AppSizes.s12),
        TextField(controller: _username, autocorrect: false, decoration: InputDecoration(labelText: HomeStrings.profileUsernameLabel, errorText: _error?.fieldError('username'))),
        const SizedBox(height: AppSizes.s12),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(labelText: HomeStrings.profileEmailLabel, errorText: _error?.fieldError('email')),
        ),
        const SizedBox(height: AppSizes.s12),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(labelText: HomeStrings.profilePhoneLabel, errorText: _error?.fieldError('phone')),
        ),
        if (generalError != null) ...[const SizedBox(height: AppSizes.s8), Text(generalError, style: TextStyle(color: StatusColors.of(context).danger))],
        const SizedBox(height: AppSizes.s16),
        FilledButton(onPressed: _busy ? null : _save, child: const Text(HomeStrings.profileSaveButton)),
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
      setState(() => _error = ApiException(message: HomeStrings.passwordMismatchError));
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
        showMessage(context, HomeStrings.passwordChangedMessage);
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
      title: HomeStrings.accountChangePasswordTitle,
      children: [
        TextField(
          controller: _current,
          obscureText: true,
          decoration: InputDecoration(labelText: HomeStrings.passwordCurrentLabel, errorText: _error?.fieldError('current_password')),
        ),
        const SizedBox(height: AppSizes.s12),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: InputDecoration(labelText: HomeStrings.passwordNewLabel, errorText: _error?.fieldError('password')),
        ),
        const SizedBox(height: AppSizes.s12),
        TextField(controller: _confirm, obscureText: true, decoration: const InputDecoration(labelText: HomeStrings.passwordConfirmLabel)),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _revokeOthers,
          onChanged: (value) => setState(() => _revokeOthers = value ?? true),
          title: const Text(HomeStrings.passwordRevokeOthers),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        if (generalError != null) Text(generalError, style: TextStyle(color: StatusColors.of(context).danger)),
        const SizedBox(height: AppSizes.s8),
        FilledButton(onPressed: _busy ? null : _save, child: const Text(HomeStrings.passwordSubmitButton)),
      ],
    );
  }
}
