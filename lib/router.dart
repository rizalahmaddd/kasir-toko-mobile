import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/auth_controller.dart';
import 'features/auth/data/current_user.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/home/presentation/account_screen.dart';
import 'features/home/presentation/home_shell.dart';
import 'features/home/presentation/splash_screen.dart';
import 'features/pos/presentation/pos_screen.dart';
import 'features/sales/presentation/sale_detail_screen.dart';
import 'features/sales/presentation/sales_screen.dart';
import 'features/shift/presentation/shift_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ValueNotifier<AsyncValue<CurrentUser?>>(ref.read(authControllerProvider));
  ref.listen(authControllerProvider, (_, next) => auth.value = next);
  ref.onDispose(auth.dispose);

  return GoRouter(
    initialLocation: '/pos',
    refreshListenable: auth,
    redirect: (context, state) {
      final location = state.matchedLocation;

      if (auth.value.isLoading && !auth.value.hasValue) {
        return location == '/splash' ? null : '/splash';
      }

      final loggedIn = auth.value.value != null;
      if (!loggedIn) {
        return location == '/login' ? null : '/login';
      }

      return location == '/login' || location == '/splash' ? '/pos' : null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/pos', builder: (context, state) => const PosScreen())]),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/sales',
                builder: (context, state) => const SalesScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => SaleDetailScreen(saleId: int.parse(state.pathParameters['id']!)),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(routes: [GoRoute(path: '/shift', builder: (context, state) => const ShiftScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/account', builder: (context, state) => const AccountScreen())]),
        ],
      ),
    ],
  );
});
