import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';

import '../../../core/config/server_config.dart';
import '../../../core/services/in_app_update_service.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/launch.dart';
import '../../auth/auth_controller.dart';

final _packageInfoProvider = FutureProvider<PackageInfo>((ref) => PackageInfo.fromPlatform());

class AboutSheet extends ConsumerWidget {
  const AboutSheet({super.key});

  static Future<T?> show<T>(BuildContext context) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AboutSheet(),
    );
  }

  void _openUrl(BuildContext context, String serverUrl, String path) {
    final cleanServer = serverUrl.endsWith('/') ? serverUrl.substring(0, serverUrl.length - 1) : serverUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$cleanServer$cleanPath');
    openExternal(context, uri);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final serverUrl = ref.watch(serverUrlProvider);
    final packageInfo = ref.watch(_packageInfoProvider).value;
    final updateState = ref.watch(inAppUpdateServiceProvider);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate700 : AppColors.slate300,
                borderRadius: BorderRadius.circular(AppRadius.r2),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.s18),

          // App Branding Header
          Row(
            children: [
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
                      color: AppColors.emerald600.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    AboutStrings.logoText,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.s14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      AboutStrings.appName,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSizes.s2),
                    Row(
                      children: [
                        if (packageInfo != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: AppSpacing.s2),
                            decoration: BoxDecoration(
                              color: AppColors.emerald500.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppRadius.r6),
                            ),
                            child: Text(
                              AboutStrings.versionBadge(packageInfo.version, packageInfo.buildNumber),
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.emerald600,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSizes.s6),
                        ],
                        Text(
                          AboutStrings.tagline,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.slate400 : AppColors.slate500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.s20),

          // Legal Links List
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.slate900 : AppColors.slate50,
              borderRadius: BorderRadius.circular(AppRadius.r16),
              border: Border.all(color: isDark ? AppColors.slate800 : AppColors.slate200),
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
                        color: AppColors.violet500.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.r10),
                      ),
                      child: updateState.isChecking
                          ? const Padding(
                              padding: EdgeInsets.all(AppSpacing.s8),
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.violet600),
                            )
                          : Icon(
                              updateState.isDownloaded ? AppIcons.download : AppIcons.refreshCw,
                              size: AppSizes.s18,
                              color: AppColors.violet600,
                            ),
                    ),
                    title: const Text(
                      AboutStrings.checkUpdateTitle,
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                    subtitle: Text(
                      updateState.isDownloading
                          ? '${AboutStrings.updateDownloading} (${(updateState.downloadProgress * 100).toStringAsFixed(0)}%)'
                          : (updateState.isDownloaded
                              ? AboutStrings.updateDownloaded
                              : AboutStrings.checkUpdateSubtitle),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: updateState.isDownloaded ? AppColors.emerald600 : null,
                        fontWeight: updateState.isDownloaded ? FontWeight.w600 : null,
                      ),
                    ),
                    trailing: updateState.isDownloaded
                        ? FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.emerald600,
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s4),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () => ref.read(inAppUpdateServiceProvider.notifier).completeFlexibleUpdate(),
                            child: const Text(AboutStrings.restartToUpdate, style: TextStyle(fontSize: 11)),
                          )
                        : const Icon(AppIcons.chevronRight, size: AppSizes.s15, color: AppColors.slate400),
                    onTap: updateState.isChecking || updateState.isDownloading
                        ? null
                        : () {
                            if (updateState.isDownloaded) {
                              ref.read(inAppUpdateServiceProvider.notifier).completeFlexibleUpdate();
                            } else {
                              ref.read(inAppUpdateServiceProvider.notifier).checkForUpdate(silent: false, context: context);
                            }
                          },
                  ),
                  Divider(height: 1, indent: 64, color: isDark ? AppColors.slate800 : AppColors.slate200),
                  ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.blue500.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.r10),
                    ),
                    child: const Icon(AppIcons.shieldCheck, size: AppSizes.s18, color: AppColors.blue600),
                  ),
                  title: const Text(AboutStrings.privacyTitle, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  subtitle: const Text(AboutStrings.privacySubtitle, style: TextStyle(fontSize: 11.5)),
                  trailing: const Icon(AppIcons.externalLink, size: AppSizes.s15, color: AppColors.slate400),
                  onTap: () => _openUrl(context, serverUrl, '/privacy-policy'),
                ),
                Divider(height: 1, indent: 64, color: isDark ? AppColors.slate800 : AppColors.slate200),
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.emerald500.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.r10),
                    ),
                    child: const Icon(AppIcons.fileText, size: AppSizes.s18, color: AppColors.emerald600),
                  ),
                  title: const Text(AboutStrings.termsTitle, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  subtitle: const Text(AboutStrings.termsSubtitle, style: TextStyle(fontSize: 11.5)),
                  trailing: const Icon(AppIcons.externalLink, size: AppSizes.s15, color: AppColors.slate400),
                  onTap: () => _openUrl(context, serverUrl, '/terms-of-service'),
                ),
                Divider(height: 1, indent: 64, color: isDark ? AppColors.slate800 : AppColors.slate200),
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.rose500.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.r10),
                    ),
                    child: const Icon(AppIcons.userX, size: AppSizes.s18, color: AppColors.rose600),
                  ),
                  title: const Text(AboutStrings.deleteAccountTitle, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  subtitle: const Text(AboutStrings.deleteAccountSubtitle, style: TextStyle(fontSize: 11.5)),
                  trailing: const Icon(AppIcons.chevronRight, size: AppSizes.s15, color: AppColors.slate400),
                  onTap: () {
                    final user = ref.read(currentUserProvider);
                    if (user != null) {
                      showModalBottomSheet<void>(
                        context: context,
                        backgroundColor: isDark ? AppColors.slate900 : Colors.white,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                        builder: (ctx) => SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.s20, AppSpacing.s20, AppSpacing.s20, AppSpacing.s16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  AboutStrings.deleteAccountTitle,
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: AppSizes.s8),
                                Text(
                                  'Anda dapat menghapus akun langsung dari aplikasi atau membaca penjelasan kebijakan di web.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? AppColors.slate300 : AppColors.slate600,
                                  ),
                                ),
                                const SizedBox(height: AppSizes.s18),
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: StatusColors.of(context).danger,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r10)),
                                  ),
                                  onPressed: () {
                                    Navigator.of(ctx).pop();
                                    Navigator.of(context).pop('delete_account');
                                  },
                                  icon: const Icon(AppIcons.trash2, size: AppSizes.s16),
                                  label: const Text('Buka Menu Hapus Akun (Dalam Aplikasi)', style: TextStyle(fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(height: AppSizes.s10),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r10)),
                                  ),
                                  onPressed: () {
                                    Navigator.of(ctx).pop();
                                    _openUrl(context, serverUrl, '/delete-account');
                                  },
                                  icon: const Icon(AppIcons.externalLink, size: AppSizes.s16),
                                  label: const Text('Buka Kebijakan & Ketentuan (Web)'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    } else {
                      _openUrl(context, serverUrl, '/delete-account');
                    }
                  },
                ),
              ],
            ),
          ),
        ),
          const SizedBox(height: AppSizes.s16),

          // Copyright Note
          Center(
            child: Text(
              AboutStrings.copyright(DateTime.now().year),
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.slate500 : AppColors.slate400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
