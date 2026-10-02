import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:web_pos_mobile/core/network/api_exception.dart';
import 'package:web_pos_mobile/core/theme/app_theme.dart';
import 'package:web_pos_mobile/features/auth/auth_controller.dart';
import 'package:web_pos_mobile/features/auth/data/current_user.dart';
import 'package:web_pos_mobile/features/offline/catalog_snapshot.dart';
import 'package:web_pos_mobile/features/onboarding/onboarding.dart';
import 'package:web_pos_mobile/features/onboarding/presentation/onboarding_screen.dart';
import 'package:web_pos_mobile/router.dart';

const _tenant = TenantInfo(id: 9, name: 'Toko Maju', plan: 'trial', planLabel: 'Uji Coba', onboarded: false);

CurrentUser _user({bool superadmin = true, TenantInfo? tenant = _tenant}) => CurrentUser(
      id: 1,
      name: 'Pemilik',
      username: 'pemilik',
      roles: [superadmin ? 'superadmin' : 'kasir'],
      permissions: const {'pos.sell'},
      isSuperadmin: superadmin,
      enabledFeatures: const {'pos.cashier'},
      tenant: tenant,
    );

Map<String, dynamic> _presetJson(String key, String label) => {
      'key': key,
      'label': label,
      'description': 'Deskripsi $label',
      'icon': 'coffee',
      'categories': ['Kopi', 'Non Kopi'],
      'sample_product_count': 12,
      'settings': {
        'tax_enabled': true,
        'tax_rate': 10,
        'tax_label': 'PB1',
        'allow_credit': false,
        'allow_negative_stock': true,
        'payment_methods': ['cash', 'qris'],
        'quick_cash': [20000, 50000],
        'receipt_footer': 'Sampai jumpa',
      },
      'disabled_features': ['pos.receivables'],
    };

class _FakeAuth extends AuthController {
  _FakeAuth(this._initial);

  final CurrentUser _initial;

  @override
  Future<CurrentUser?> build() async => _initial;

  @override
  Future<void> updateTenant(TenantInfo tenant) async => state = AsyncData(state.value!.withTenant(tenant));

  @override
  Future<void> logout() async => state = const AsyncData(null);
}

class _NoSnapshot extends CatalogSnapshotNotifier {
  @override
  Future<CatalogSnapshot?> build() async => null;
}

class _FakeRepository implements OnboardingRepository {
  final calls = <String>[];
  ApiException? applyError;

  @override
  Future<List<StorePreset>> presets() async => [StorePreset.fromJson(_presetJson('kafe', 'Kafe / Coffee Shop'))];

  @override
  Future<PresetResult> apply(String storeType, {required bool includeSampleProducts}) async {
    calls.add('apply $storeType samples=$includeSampleProducts');
    if (applyError != null) {
      throw applyError!;
    }
    return PresetResult.fromJson({
      'categories_created': 2,
      'products_created': includeSampleProducts ? 12 : 0,
      'products_skipped': 0,
      'tenant': {'id': 9, 'name': 'Toko Maju', 'onboarded': true, 'store_type': storeType},
    });
  }

  @override
  Future<TenantInfo> skip() async {
    calls.add('skip');
    return const TenantInfo(id: 9, name: 'Toko Maju', plan: 'trial', planLabel: 'Uji Coba');
  }
}

Future<(ProviderContainer, _FakeRepository)> _pump(WidgetTester tester) async {
  final repository = _FakeRepository();
  final container = ProviderContainer(overrides: [
    authControllerProvider.overrideWith(() => _FakeAuth(_user())),
    onboardingRepositoryProvider.overrideWithValue(repository),
    catalogSnapshotProvider.overrideWith(_NoSnapshot.new),
  ]);
  addTearDown(container.dispose);
  await container.read(authControllerProvider.future);

  final router = GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/pos', builder: (_, _) => const Text('POS')),
      GoRoute(path: '/login', builder: (_, _) => const Text('LOGIN')),
    ],
  );
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router)));
  await tester.pumpAndSettle();

  return (container, repository);
}

void main() {
  group('TenantInfo onboarding state', () {
    test('reads onboarded and store_type, and survives the cached-profile round trip', () {
      final tenant = TenantInfo.fromJson({'id': 9, 'name': 'Toko', 'onboarded': false, 'store_type': null});
      final restored = TenantInfo.fromJson(tenant.toJson());

      expect(restored.onboarded, isFalse);
      expect(restored.storeType, isNull);
      expect(TenantInfo.fromJson({'id': 9, 'onboarded': true, 'store_type': 'kafe'}).storeType, 'kafe');
    });

    test('servers without store presets count as onboarded', () {
      expect(TenantInfo.fromJson({'id': 9, 'name': 'Toko'}).onboarded, isTrue);
    });

    test('a preset parses its settings summary', () {
      final preset = StorePreset.fromJson(_presetJson('kafe', 'Kafe'));

      expect(preset.settings.taxRate, 10);
      expect(preset.settings.quickCash, [20000, 50000]);
      expect(preset.disabledFeatures, ['pos.receivables']);
    });
  });

  group('routeRedirect', () {
    test('sends an owner who has not onboarded to the setup screen', () {
      final owner = AsyncData<CurrentUser?>(_user());

      expect(routeRedirect(owner, '/splash'), '/onboarding');
      expect(routeRedirect(owner, '/pos'), '/onboarding');
      expect(routeRedirect(owner, '/onboarding'), isNull);
    });

    test('never sends a cashier to the setup screen', () {
      final cashier = AsyncData<CurrentUser?>(_user(superadmin: false));

      expect(routeRedirect(cashier, '/login'), '/pos');
      expect(routeRedirect(cashier, '/pos'), isNull);
      expect(routeRedirect(cashier, '/onboarding'), '/dashboard');
    });

    test('lets an onboarded owner in, and back to the presets from the menu', () {
      final owner = AsyncData<CurrentUser?>(_user(tenant: const TenantInfo(id: 9, name: 'Toko', plan: 'pro', planLabel: 'Pro')));

      expect(routeRedirect(owner, '/login'), '/pos');
      expect(routeRedirect(owner, '/onboarding'), isNull);
    });

    test('a blocked shop is shown before onboarding', () {
      final blocked = AsyncData<CurrentUser?>(_user(tenant: _tenant.blocked('trial_expired')));

      expect(routeRedirect(blocked, '/pos'), '/blocked');
    });
  });

  group('OnboardingScreen', () {
    testWidgets('applies the chosen preset without sample products', (tester) async {
      final (container, repository) = await _pump(tester);

      await tester.tap(find.text('Kafe / Coffee Shop'));
      await tester.pumpAndSettle();
      expect(find.text('PB1 10%'), findsOneWidget);
      expect(find.text('Piutang (kasbon)'), findsOneWidget);

      await tester.tap(find.text('Sertakan produk contoh'));
      await tester.tap(find.text('Terapkan'));
      await tester.pumpAndSettle();

      expect(repository.calls, ['apply kafe samples=false']);
      expect(container.read(currentUserProvider)?.tenant?.storeType, 'kafe');
      expect(container.read(currentUserProvider)?.needsOnboarding, isFalse);
      expect(find.text('POS'), findsOneWidget);
    });

    testWidgets('skips onboarding', (tester) async {
      final (container, repository) = await _pump(tester);

      await tester.tap(find.text('Lewati, mulai dari kosong'));
      await tester.pumpAndSettle();

      expect(repository.calls, ['skip']);
      expect(container.read(currentUserProvider)?.needsOnboarding, isFalse);
      expect(find.text('POS'), findsOneWidget);
    });

    testWidgets('stays on the preview and shows the reason when the server refuses', (tester) async {
      final (container, repository) = await _pump(tester);
      repository.applyError = ApiException(
        message: 'Preset tidak bisa diterapkan lagi karena toko ini sudah punya transaksi penjualan.',
        statusCode: 422,
      );

      await tester.tap(find.text('Kafe / Coffee Shop'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terapkan'));
      await tester.pumpAndSettle();

      expect(find.textContaining('sudah punya transaksi'), findsOneWidget);
      expect(find.text('Terapkan'), findsOneWidget);
      expect(container.read(currentUserProvider)?.needsOnboarding, isTrue);
    });
  });
}
