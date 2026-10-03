import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_pos_mobile/core/storage/app_storage.dart';
import 'package:web_pos_mobile/core/utils/display_service.dart';
import 'package:web_pos_mobile/features/auth/auth_controller.dart';
import 'package:web_pos_mobile/features/auth/data/current_user.dart';
import 'package:web_pos_mobile/features/home/presentation/home_shell.dart';
import 'package:web_pos_mobile/features/offline/offline_queue.dart';

const _cashierUser = CurrentUser(
  id: 1,
  name: 'Kasir',
  username: 'kasir',
  roles: ['cashier'],
  permissions: {'pos.sell', 'pos.view_sales', 'pos.view_products'},
  isSuperadmin: false,
  enabledFeatures: {'pos.cashier'},
);

class FakeDisplayService extends DisplayService {
  int keepScreenOnCallCount = 0;
  int allowScreenSleepCallCount = 0;

  @override
  Future<void> keepScreenOn() async {
    keepScreenOnCallCount++;
    await super.keepScreenOn();
  }

  @override
  Future<void> allowScreenSleep() async {
    allowScreenSleepCallCount++;
    await super.allowScreenSleep();
  }
}

GoRouter createTestRouter({required String initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/dashboard', builder: (context, state) => const Text('DashboardPage'))]),
          StatefulShellBranch(routes: [GoRoute(path: '/pos', builder: (context, state) => const Text('PosPage'))]),
          StatefulShellBranch(routes: [GoRoute(path: '/sales', builder: (context, state) => const Text('SalesPage'))]),
          StatefulShellBranch(routes: [GoRoute(path: '/products', builder: (context, state) => const Text('ProductsPage'))]),
          StatefulShellBranch(routes: [GoRoute(path: '/menu', builder: (context, state) => const Text('MenuPage'))]),
        ],
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeDisplayService fakeDisplayService;

  setUp(() {
    fakeDisplayService = FakeDisplayService();
  });

  Widget buildApp({required GoRouter router, required SharedPreferences prefs}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currentUserProvider.overrideWith((ref) => _cashierUser),
        displayServiceProvider.overrideWithValue(fakeDisplayService),
        offlineSyncerProvider.overrideWith((ref) {}),
      ],
      child: MaterialApp.router(
        routerConfig: router,
      ),
    );
  }

  testWidgets('enables wakelock when Kasir tab (/pos) is initially active', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final router = createTestRouter(initialLocation: '/pos');

    await tester.pumpWidget(buildApp(router: router, prefs: prefs));
    await tester.pumpAndSettle();

    expect(find.text('PosPage'), findsOneWidget);
    expect(fakeDisplayService.isWakelockEnabled, isTrue);
    expect(fakeDisplayService.keepScreenOnCallCount, equals(1));
    expect(fakeDisplayService.allowScreenSleepCallCount, equals(0));
  });

  testWidgets('disables wakelock when non-Kasir tab (/dashboard) is active', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final router = createTestRouter(initialLocation: '/dashboard');

    await tester.pumpWidget(buildApp(router: router, prefs: prefs));
    await tester.pumpAndSettle();

    expect(find.text('DashboardPage'), findsOneWidget);
    expect(fakeDisplayService.isWakelockEnabled, isFalse);
    expect(fakeDisplayService.allowScreenSleepCallCount, equals(1));
    expect(fakeDisplayService.keepScreenOnCallCount, equals(0));
  });

  testWidgets('toggles wakelock when switching tabs', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final router = createTestRouter(initialLocation: '/dashboard');

    await tester.pumpWidget(buildApp(router: router, prefs: prefs));
    await tester.pumpAndSettle();
    expect(fakeDisplayService.isWakelockEnabled, isFalse);

    // Switch to Kasir
    router.go('/pos');
    await tester.pumpAndSettle();
    expect(find.text('PosPage'), findsOneWidget);
    expect(fakeDisplayService.isWakelockEnabled, isTrue);
    expect(fakeDisplayService.keepScreenOnCallCount, equals(1));

    // Switch to Transaksi (/sales)
    router.go('/sales');
    await tester.pumpAndSettle();
    expect(find.text('SalesPage'), findsOneWidget);
    expect(fakeDisplayService.isWakelockEnabled, isFalse);
    expect(fakeDisplayService.allowScreenSleepCallCount, equals(2));

    // Switch back to Kasir
    router.go('/pos');
    await tester.pumpAndSettle();
    expect(fakeDisplayService.isWakelockEnabled, isTrue);
    expect(fakeDisplayService.keepScreenOnCallCount, equals(2));
  });

  testWidgets('releases wakelock when HomeShell is disposed', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final router = createTestRouter(initialLocation: '/pos');

    await tester.pumpWidget(buildApp(router: router, prefs: prefs));
    await tester.pumpAndSettle();
    expect(fakeDisplayService.isWakelockEnabled, isTrue);

    // Unmount HomeShell
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(fakeDisplayService.isWakelockEnabled, isFalse);
  });

  testWidgets('does not enable wakelock on Kasir tab when keepScreenOn is disabled in settings', (tester) async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.posKeepScreenOn: false,
    });
    final prefs = await SharedPreferences.getInstance();
    final router = createTestRouter(initialLocation: '/pos');

    await tester.pumpWidget(buildApp(router: router, prefs: prefs));
    await tester.pumpAndSettle();

    expect(find.text('PosPage'), findsOneWidget);
    expect(fakeDisplayService.isWakelockEnabled, isFalse);
    expect(fakeDisplayService.keepScreenOnCallCount, equals(0));
  });
}
