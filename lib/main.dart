import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/app_routes.dart';
import 'core/constants/app_strings.dart';
import 'core/constants/date_formats.dart';
import 'core/network/api_client.dart';
import 'core/offline/offline_cache.dart';
import 'core/storage/app_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/offline/presentation/offline_screen.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await initializeDateFormatting(AppDateFormat.locale);
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        unauthorizedHandlerProvider.overrideWith((ref) => () => ref.read(authControllerProvider.notifier).expire()),
        tenantBlockedHandlerProvider.overrideWith((ref) => (reason, message) => ref.read(authControllerProvider.notifier).markBlocked(reason, message)),
        offlineTenantProvider.overrideWith((ref) => ref.watch(currentUserProvider.select((user) => user?.tenant?.id))),
      ],
      child: const KasirApp(),
    ),
  );
}

class KasirApp extends ConsumerWidget {
  const KasirApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => OfflineBannerFrame(
        onTap: () {
          final router = ref.read(routerProvider);
          if (router.routerDelegate.currentConfiguration.uri.path != AppRoutes.offline) {
            router.push(AppRoutes.offline);
          }
        },
        child: child!,
      ),
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}
