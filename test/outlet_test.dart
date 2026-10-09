import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';
import 'package:web_pos_mobile/core/network/api_client.dart';
import 'package:web_pos_mobile/core/offline/offline_cache.dart';
import 'package:web_pos_mobile/core/storage/app_storage.dart';
import 'package:web_pos_mobile/core/theme/app_theme.dart';
import 'package:web_pos_mobile/features/auth/access.dart';
import 'package:web_pos_mobile/features/auth/auth_controller.dart';
import 'package:web_pos_mobile/features/auth/data/current_user.dart';
import 'package:web_pos_mobile/features/outlets/data/outlet_models.dart';
import 'package:web_pos_mobile/features/outlets/data/outlet_repository.dart';
import 'package:web_pos_mobile/features/outlets/outlet_controller.dart';
import 'package:web_pos_mobile/features/outlets/presentation/outlet_picker.dart';
import 'package:web_pos_mobile/features/outlets/presentation/outlets_screen.dart';
import 'package:web_pos_mobile/features/pos/cart_controller.dart';
import 'package:web_pos_mobile/features/pos/data/pos_models.dart';
import 'package:web_pos_mobile/features/products/data/product_models.dart';
import 'package:web_pos_mobile/features/shift/data/shift_models.dart';
import 'package:web_pos_mobile/features/shift/shift_controller.dart';

class _MockOutlets extends Mock implements OutletRepository {}

Map<String, dynamic> _outlet(int id, String name, {bool primary = false, bool active = true, bool operational = true}) => {
      'id': id,
      'name': name,
      'code': name.substring(0, 3).toUpperCase(),
      'address': null,
      'phone': null,
      'is_primary': primary,
      'is_active': active,
      'is_operational': operational,
      'priority': id,
    };

Map<String, dynamic> _userJson({List<Map<String, dynamic>>? outlets, int? currentOutletId, Map<String, dynamic>? tenant, Set<String> permissions = const {}}) => {
      'id': 7,
      'name': 'Pemilik',
      'username': 'pemilik',
      'roles': ['superadmin'],
      'permissions': permissions.toList(),
      'is_superadmin': false,
      'all_outlets': true,
      'enabled_features': ['settings.outlets', 'pos.cashier'],
      'outlets': outlets ?? [_outlet(1, 'Pusat', primary: true), _outlet(2, 'Cabang Dago')],
      'current_outlet_id': currentOutletId,
      'app': {'min_supported_version': '1.1.0', 'update_required': false},
      'tenant': tenant ?? {'id': 9, 'name': 'Toko', 'plan': 'pro', 'plan_label': 'Pro', 'is_multi_outlet': true, 'limits': {'outlets': {'used': 2, 'max': 5}}},
    };

CurrentUser _user({List<Map<String, dynamic>>? outlets, int? currentOutletId, Map<String, dynamic>? tenant, Set<String> permissions = const {'outlets.view', 'outlets.manage'}}) =>
    CurrentUser.fromJson(_userJson(outlets: outlets, currentOutletId: currentOutletId, tenant: tenant, permissions: permissions));

/// Records the headers of every request instead of calling a server.
class _CaptureAdapter implements HttpClientAdapter {
  final headers = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    headers.add(Map.of(options.headers));

    return ResponseBody.fromString('{"data":[]}', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('outlet models', () {
    test('the profile carries the outlets, the limit and the update flag, and survives the cached round trip', () {
      final user = CurrentUser.fromJson(_userJson(currentOutletId: 2));
      final restored = CurrentUser.fromJson(user.toJson());

      expect(restored.outlets.map((o) => o.name), ['Pusat', 'Cabang Dago']);
      expect(restored.outlets.first.isPrimary, isTrue);
      expect(restored.currentOutletId, 2);
      expect(restored.allOutlets, isTrue);
      expect(restored.minSupportedVersion, '1.1.0');
      expect(restored.tenant?.isMultiOutlet, isTrue);
      expect((restored.tenant?.outletsUsed, restored.tenant?.outletsMax), (2, 5));
      expect(restored.tenant!.canAddOutlet, isTrue);
      expect(restored.hasMultipleOutlets, isTrue);
    });

    test('profiles from servers without outlets stay valid and single-outlet', () {
      final user = CurrentUser.fromJson({'id': 1, 'name': 'A', 'roles': <String>[], 'permissions': <String>[], 'is_superadmin': false, 'enabled_features': <String>[]});

      expect(user.outlets, isEmpty);
      expect(user.hasMultipleOutlets, isFalse);
      expect(user.updateRequired, isFalse);
      expect(user.tenant, isNull);
    });

    test('a locked outlet is active but not operational', () {
      final locked = OutletInfo.fromJson(_outlet(3, 'Cabang Lembang', operational: false));

      expect(locked.isLocked, isTrue);
      expect(OutletInfo.fromJson(_outlet(3, 'Cabang Lembang', active: false, operational: false)).isLocked, isFalse);
    });

    test('outlet settings sections read and write the same shape the API uses', () {
      const data = OutletSettingsData(taxInherit: false, taxEnabled: true, taxRate: '10', taxLabel: 'PB1', paymentsInherit: false, paymentMethods: ['cash', 'qris']);
      final restored = OutletSettingsData.fromJson(data.toJson());

      expect((restored.taxInherit, restored.taxEnabled, restored.taxRate, restored.taxLabel), (false, true, '10', 'PB1'));
      expect(restored.paymentMethods, ['cash', 'qris']);
      expect(restored.receiptInherit, isTrue);
      expect(data.toJson()['qris'], {'inherit': true, 'payload': ''});
    });

    test('outlet management follows the permission and the feature switch', () {
      expect(_user().canManageOutlets, isTrue);
      expect(_user(permissions: {'outlets.view'}).canManageOutlets, isFalse);
      expect(_user(permissions: {'outlets.view'}).canViewOutlets, isTrue);
      expect(_user(permissions: const {}).canViewOutlets, isFalse);
    });

    test('product records keep the outlet price apart from the base price', () {
      final product = ProductRecord.fromJson({
        'id': 1,
        'sku': 'A',
        'name': 'Teh',
        'price': 6000,
        'base_price': 5000,
        'has_outlet_price': true,
        'outlet_prices': [
          {'outlet_id': 2, 'price': 6000},
        ],
        'cost_price': 3000,
        'track_stock': true,
        'stock': '4.000',
        'min_stock': '1.000',
        'is_low_stock': false,
        'is_active': true,
      });

      expect((product.price, product.basePrice, product.hasOutletPrice), (6000, 5000, true));
      expect(product.outletPrices, {2: 6000});
      expect(ProductRecord.fromJson({'id': 2, 'name': 'X', 'price': 100, 'cost_price': 0, 'track_stock': false, 'stock': 0, 'min_stock': 0, 'is_active': true}).basePrice, 100);
      expect(const ProductInput(name: 'Teh', unit: 'btl', price: 5000, trackStock: true, isActive: true, outletPrices: {2: 6000, 3: null}).toJson()['outlet_prices'], [
        {'outlet_id': 2, 'price': 6000},
        {'outlet_id': 3, 'price': null},
      ]);
      expect(const ProductInput(name: 'Teh', unit: 'btl', price: 5000, trackStock: true, isActive: true).toJson().containsKey('outlet_prices'), isFalse);
    });

    test('a shift and a sale know their outlet', () {
      final shift = Shift.fromJson({
        'id': 1,
        'number': 'SFT-DGO-1',
        'is_open': true,
        'outlet': {'id': 2, 'name': 'Cabang Dago', 'code': 'DGO'},
        'opened_at': '2026-10-05T08:00:00+07:00',
        'opening_cash': 0,
      });

      expect((shift.outletId, shift.outletName), (2, 'Cabang Dago'));
    });
  });

  group('current outlet', () {
    test('resolve keeps the saved outlet while it can sell, then follows the server and then any outlet that can sell', () {
      final user = _user(outlets: [_outlet(1, 'Pusat', primary: true), _outlet(2, 'Cabang Dago'), _outlet(3, 'Cabang Lembang', operational: false)], currentOutletId: 2);

      expect(CurrentOutletId.resolve(user, 1), 1);
      expect(CurrentOutletId.resolve(user, null), 2);
      expect(CurrentOutletId.resolve(user, 3), 2, reason: 'a locked outlet is never picked on its own');
      expect(CurrentOutletId.resolve(user, 99), 2);
      expect(CurrentOutletId.resolve(_user(outlets: [_outlet(1, 'Pusat', primary: true)]), null), 1);
      expect(CurrentOutletId.resolve(_user(outlets: [_outlet(3, 'Cabang Lembang', operational: false)]), null), 3);
      expect(CurrentOutletId.resolve(_user(outlets: const []), null), isNull);
    });

    Future<ProviderContainer> container({int? stored, CurrentUser? user, OutletRepository? repository}) async {
      SharedPreferences.setMockInitialValues({'current_outlet_7': ?stored});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currentUserProvider.overrideWithValue(user ?? _user(currentOutletId: 1)),
        outletRepositoryProvider.overrideWithValue(repository ?? _MockOutlets()),
      ]);
      addTearDown(container.dispose);

      return container;
    }

    test('starts on the saved outlet of that account', () async {
      expect((await container(stored: 2)).read(currentOutletIdProvider), 2);
      expect((await container()).read(currentOutletIdProvider), 1);
    });

    test('switching saves the choice for the account, empties the cart and tells the server', () async {
      final repository = _MockOutlets();
      when(() => repository.rememberCurrent(any())).thenAnswer((_) async {});
      final c = await container(repository: repository);
      c.read(cartProvider.notifier).add(const Product(id: 1, name: 'Teh', unit: 'btl', price: 5000, trackStock: false, stock: 0));
      expect(c.read(cartProvider).items, hasLength(1));

      await c.read(currentOutletIdProvider.notifier).select(2);

      expect(c.read(currentOutletIdProvider), 2);
      expect(c.read(currentOutletProvider)?.name, 'Cabang Dago');
      expect(c.read(sharedPreferencesProvider).getInt('current_outlet_7'), 2);
      expect(c.read(cartProvider).items, isEmpty);
      verify(() => repository.rememberCurrent(2)).called(1);
    });

    test('an outlet the account does not have cannot be selected', () async {
      final c = await container();

      await c.read(currentOutletIdProvider.notifier).select(99);

      expect(c.read(currentOutletIdProvider), 1);
    });

    test('the outlet label shows only in shops with several outlets', () async {
      expect((await container()).read(outletLabelProvider), 'Pusat');

      final single = await container(user: _user(outlets: [_outlet(1, 'Pusat', primary: true)], tenant: {'id': 9, 'name': 'Toko', 'plan': 'free', 'plan_label': 'Gratis'}));
      expect(single.read(outletLabelProvider), isNull);
    });
  });

  group('requests', () {
    Future<(ProviderContainer, _CaptureAdapter)> client({int? outletId, String version = '1.1.0', String? token = 'abc'}) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        offlineOutletProvider.overrideWithValue(outletId),
        appVersionProvider.overrideWithValue(version),
      ]);
      addTearDown(container.dispose);
      container.read(authTokenProvider.notifier).set(token);
      final adapter = _CaptureAdapter();
      container.read(dioProvider).httpClientAdapter = adapter;

      return (container, adapter);
    }

    test('every authenticated request names the outlet in use and the app version', () async {
      final (container, adapter) = await client(outletId: 4);

      await container.read(apiClientProvider).get('pos/config');

      expect(adapter.headers.single[outletHeader], '4');
      expect(adapter.headers.single['X-App-Version'], '1.1.0');
      expect(adapter.headers.single['Authorization'], 'Bearer abc');
    });

    test('a request can name its own outlet, like a queued sale', () async {
      final (container, adapter) = await client(outletId: 4);

      await container.read(apiClientProvider).post('pos/checkout', data: const {}, headers: {outletHeader: '2'});

      expect(adapter.headers.single[outletHeader], '2');
    });

    test('nothing outlet related is sent before login or when no outlet is known', () async {
      final (anonymous, adapterA) = await client(outletId: 4, token: null);
      await anonymous.read(apiClientProvider).get('auth/config');
      expect(adapterA.headers.single.containsKey(outletHeader), isFalse);

      final (noOutlet, adapterB) = await client(version: '');
      await noOutlet.read(apiClientProvider).get('auth/me');
      expect(adapterB.headers.single.containsKey(outletHeader), isFalse);
      expect(adapterB.headers.single.containsKey('X-App-Version'), isFalse);
    });

    test('an outlet refusal from the server triggers the reload of the allowed outlets', () async {
      SharedPreferences.setMockInitialValues({});
      final reasons = <String>[];
      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
        outletRejectedHandlerProvider.overrideWithValue(reasons.add),
      ]);
      addTearDown(container.dispose);
      container.read(authTokenProvider.notifier).set('abc');
      container.read(dioProvider).httpClientAdapter = _RefusingAdapter(403, 'outlet_forbidden');

      await expectLater(container.read(apiClientProvider).get('pos/config'), throwsA(anything));
      container.read(dioProvider).httpClientAdapter = _RefusingAdapter(423, 'outlet_locked');
      await expectLater(container.read(apiClientProvider).post('pos/checkout', data: const {}), throwsA(anything));
      container.read(dioProvider).httpClientAdapter = _RefusingAdapter(403, 'something_else');
      await expectLater(container.read(apiClientProvider).get('pos/config'), throwsA(anything));

      expect(reasons, ['outlet_forbidden', 'outlet_locked']);
    });
  });

  group('offline copies per outlet', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      final dir = Directory.systemTemp.createTempSync('outlet_cache_test');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => dir.path,
      );
    });

    Future<ProviderContainer> cache(int? outletId) async => ProviderContainer(overrides: [
          sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
          offlineTenantProvider.overrideWithValue(1),
          offlineOutletProvider.overrideWithValue(outletId),
        ]);

    test('prices, stock and the open shift of one outlet never show up in another', () async {
      final dago = await cache(2);
      await dago.read(offlineCacheProvider).put('pos_config', {'tax': 10});
      await dago.read(offlineCacheProvider).writeFile(StorageKeys.catalogFor(2), {'products': [1]});

      final pusat = await cache(1);

      expect(dago.read(offlineCacheProvider).get('pos_config'), {'tax': 10});
      expect(pusat.read(offlineCacheProvider).get('pos_config'), isNull);
      expect(await pusat.read(offlineCacheProvider).readFile(StorageKeys.catalogFor(1)), isNull);
      expect(await dago.read(offlineCacheProvider).readFile(StorageKeys.catalogFor(2)), {'products': [1]});
    });

    test('every outlet keeps its own catalog file and clearing removes them all', () async {
      expect(StorageKeys.catalogFor(2), 'catalog_2');
      expect(StorageKeys.catalogFor(null), 'catalog');

      final c = await cache(2);
      await c.read(offlineCacheProvider).writeFile(StorageKeys.catalogFor(2), {'products': []});
      await c.read(offlineCacheProvider).writeFile(StorageKeys.catalogFor(3), {'products': []});
      await OfflineCache.clearStorage(await SharedPreferences.getInstance());

      expect(await c.read(offlineCacheProvider).readFile(StorageKeys.catalogFor(2)), isNull);
      expect(await c.read(offlineCacheProvider).readFile(StorageKeys.catalogFor(3)), isNull);
    });
  });

  group('screens', () {
    Future<void> pump(WidgetTester tester, Widget child, {CurrentUser? user, List<OutletInfo>? managed, Shift? shift, OutletRepository? repository}) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currentUserProvider.overrideWithValue(user ?? _user(currentOutletId: 1)),
            managedOutletsProvider.overrideWith((ref) async => managed ?? const []),
            currentShiftProvider.overrideWith(() => _FixedShift(shift)),
            outletRepositoryProvider.overrideWithValue(repository ?? _MockOutlets()),
          ],
          child: MaterialApp(theme: AppTheme.light(), home: Scaffold(body: child)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the outlet chip shows the active outlet and is hidden for a single outlet', (tester) async {
      await pump(tester, const Center(child: OutletChip()));
      expect(find.text('Pusat'), findsOneWidget);

      await pump(tester, const Center(child: OutletChip()), user: _user(outlets: [_outlet(1, 'Pusat', primary: true)]));
      expect(find.text('Pusat'), findsNothing);
    });

    testWidgets('the picker lists every outlet, marks locked ones and switches on tap', (tester) async {
      final repository = _MockOutlets();
      when(() => repository.rememberCurrent(any())).thenAnswer((_) async {});
      final user = _user(outlets: [_outlet(1, 'Pusat', primary: true), _outlet(2, 'Cabang Dago'), _outlet(3, 'Cabang Lembang', operational: false)], currentOutletId: 1);
      await pump(tester, const Center(child: OutletChip()), user: user, repository: repository);

      await tester.tap(find.byType(OutletChip));
      await tester.pumpAndSettle();

      expect(find.text(OutletStrings.pickerTitle), findsOneWidget);
      expect(find.text('CAB · ${OutletStrings.lockedOption}'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('outlet-option-2')));
      await tester.pumpAndSettle();

      verify(() => repository.rememberCurrent(2)).called(1);
      expect(find.text(OutletStrings.switched('Cabang Dago')), findsOneWidget);
    });

    testWidgets('the cashier is warned when the selected outlet is locked', (tester) async {
      final user = _user(outlets: [_outlet(1, 'Pusat', primary: true, operational: false)], currentOutletId: 1);
      await pump(tester, const OutletStatusBanner(), user: user);

      expect(find.text(OutletStrings.lockedBanner('Pusat')), findsOneWidget);
    });

    testWidgets('the cashier is warned about a shift that is open in another outlet and can jump there', (tester) async {
      final repository = _MockOutlets();
      when(() => repository.rememberCurrent(any())).thenAnswer((_) async {});
      final shift = Shift.fromJson({'id': 1, 'number': 'SFT-DGO-1', 'is_open': true, 'outlet': {'id': 2, 'name': 'Cabang Dago'}, 'opened_at': '2026-10-05T08:00:00+07:00', 'opening_cash': 0});
      await pump(tester, const OutletStatusBanner(), user: _user(currentOutletId: 1), shift: shift, repository: repository);

      expect(find.text(OutletStrings.shiftElsewhereBanner('Cabang Dago')), findsOneWidget);

      await tester.tap(find.text(OutletStrings.shiftElsewhereAction('Cabang Dago')));
      await tester.pumpAndSettle();

      verify(() => repository.rememberCurrent(2)).called(1);
    });

    testWidgets('no banner while the outlet can sell and the shift is in the same outlet', (tester) async {
      final shift = Shift.fromJson({'id': 1, 'number': 'SFT-1', 'is_open': true, 'outlet': {'id': 1, 'name': 'Pusat'}, 'opened_at': '2026-10-05T08:00:00+07:00', 'opening_cash': 0});
      await pump(tester, const OutletStatusBanner(), shift: shift);

      expect(find.byType(Container), findsNothing);
    });

    testWidgets('the management list shows the quota, statuses, and the add button within the limit', (tester) async {
      final managed = [OutletInfo.fromJson({..._outlet(1, 'Pusat', primary: true), 'users_count': 3}), OutletInfo.fromJson(_outlet(2, 'Cabang Dago', operational: false))];
      await pump(tester, const OutletsScreen(), managed: managed);

      expect(find.text(OutletStrings.quotaTitle(2, 5)), findsOneWidget);
      expect(find.text(OutletStrings.badgePrimary.toUpperCase()), findsOneWidget);
      expect(find.text(OutletStrings.badgeLocked.toUpperCase()), findsOneWidget);
      expect(find.text(OutletStrings.usersCount(3)), findsOneWidget);
      expect(find.text(OutletStrings.addOutlet), findsOneWidget);
    });

    testWidgets('at the plan limit the add button is replaced by a note that links nowhere', (tester) async {
      final user = _user(tenant: {'id': 9, 'name': 'Toko', 'plan': 'free', 'plan_label': 'Gratis', 'is_multi_outlet': false, 'limits': {'outlets': {'used': 1, 'max': 1}}}, outlets: [_outlet(1, 'Pusat', primary: true)]);
      await pump(tester, const OutletsScreen(), user: user, managed: [OutletInfo.fromJson(_outlet(1, 'Pusat', primary: true))]);

      expect(find.text(OutletStrings.addOutlet), findsNothing);
      expect(find.text(OutletStrings.limitReached), findsOneWidget);
      expect(find.byIcon(Icons.open_in_new), findsNothing);
    });

    testWidgets('a limited viewer sees the list but cannot open the actions', (tester) async {
      final managed = [OutletInfo.fromJson(_outlet(1, 'Pusat', primary: true))];
      await pump(tester, const OutletsScreen(), user: _user(permissions: {'outlets.view'}), managed: managed);

      expect(find.text(OutletStrings.addOutlet), findsNothing);
      await tester.tap(find.byKey(const ValueKey('outlet-card-1')));
      await tester.pumpAndSettle();
      expect(find.text(OutletStrings.actionEdit), findsNothing);
    });

    testWidgets('the owner creates an outlet with copied settings and the profile and list reload', (tester) async {
      final repository = _MockOutlets();
      when(() => repository.save(
            id: any(named: 'id'),
            name: any(named: 'name'),
            code: any(named: 'code'),
            address: any(named: 'address'),
            phone: any(named: 'phone'),
            copyFromOutletId: any(named: 'copyFromOutletId'),
          )).thenAnswer((_) async => OutletInfo.fromJson(_outlet(3, 'Cabang Baru')));
      final managed = [OutletInfo.fromJson(_outlet(1, 'Pusat', primary: true))];
      await pump(tester, const OutletsScreen(), managed: managed, repository: repository);

      await tester.tap(find.text(OutletStrings.addOutlet));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, OutletStrings.nameLabel), 'Cabang Baru');
      await tester.enterText(find.widgetWithText(TextField, OutletStrings.codeLabel), 'cbb');
      await tester.tap(find.text(OutletStrings.save));
      await tester.pumpAndSettle();

      verify(() => repository.save(id: null, name: 'Cabang Baru', code: 'CBB', address: null, phone: null, copyFromOutletId: null)).called(1);
    });
  });
}

class _RefusingAdapter implements HttpClientAdapter {
  _RefusingAdapter(this.status, this.reason);

  final int status;
  final String reason;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody.fromString('{"message":"Ditolak","reason":"$reason"}', status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });

  @override
  void close({bool force = false}) {}
}

class _FixedShift extends CurrentShiftController {
  _FixedShift(this._shift);

  final Shift? _shift;

  @override
  Future<Shift?> build() async => _shift;
}
