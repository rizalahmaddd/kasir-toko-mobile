import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';
import 'package:web_pos_mobile/core/storage/app_storage.dart';
import 'package:web_pos_mobile/core/theme/app_theme.dart';
import 'package:web_pos_mobile/features/auth/access.dart';
import 'package:web_pos_mobile/features/auth/auth_controller.dart';
import 'package:web_pos_mobile/features/auth/data/current_user.dart';
import 'package:web_pos_mobile/features/onboarding/onboarding.dart';
import 'package:web_pos_mobile/features/outlets/data/outlet_models.dart';
import 'package:web_pos_mobile/features/outlets/data/outlet_repository.dart';
import 'package:web_pos_mobile/features/outlets/presentation/outlets_screen.dart';
import 'package:web_pos_mobile/features/products/data/product_models.dart';
import 'package:web_pos_mobile/features/sales/data/sale_models.dart';

class _MockOutlets extends Mock implements OutletRepository {}

Map<String, dynamic> _outlet(int id, String name, {bool primary = false, List<String>? capabilities, List<String> disabled = const [], String? type}) => {
      'id': id,
      'name': name,
      'code': name.substring(0, 3).toUpperCase(),
      'is_primary': primary,
      'is_active': true,
      'is_operational': true,
      'priority': id,
      'store_type': type,
      'effective_store_type': type ?? 'warung',
      'effective_store_type_label': type == 'apotek' ? 'Apotek' : 'Warung / Kelontong',
      'capabilities': capabilities,
      'disabled_features': disabled,
    };

CurrentUser _user(List<Map<String, dynamic>> outlets, {Set<String> features = const {}}) => CurrentUser.fromJson({
      'id': 7,
      'name': 'Pemilik',
      'username': 'pemilik',
      'roles': ['superadmin'],
      'permissions': ['pos.sell', 'pharmacy.prescription.view', 'kitchen.view', 'orders.manage', 'outlets.view', 'outlets.manage'],
      'is_superadmin': false,
      'all_outlets': true,
      'enabled_features': ['settings.outlets', 'pos.cashier', 'pos.receivables', ...features],
      'outlets': outlets,
      'current_outlet_id': 1,
      'tenant': {'id': 9, 'name': 'Toko', 'plan': 'pro', 'plan_label': 'Pro', 'is_multi_outlet': true, 'store_type': 'warung', 'limits': {'outlets': {'used': 2, 'max': 5}}},
    });

StorePreset _preset(String key, String label, Set<String> defaults) => StorePreset.fromJson({
      'key': key,
      'label': label,
      'description': '',
      'icon': 'store',
      'categories': ['Obat Bebas'],
      'sample_product_count': 35,
      'settings': <String, dynamic>{},
      'disabled_features': <String>[],
      'capabilities': [
        for (final capability in ['business.prescription', 'business.batch-expiry', 'business.order-type'])
          {'key': capability, 'label': capability, 'description': '', 'default_on': defaults.contains(capability)},
      ],
    });

void main() {
  group('features per outlet', () {
    final user = _user(
      [
        _outlet(1, 'Pusat', primary: true, capabilities: const []),
        _outlet(2, 'Apotek', capabilities: const ['business.prescription'], disabled: const ['pos.receivables'], type: 'apotek'),
      ],
      features: {'business.prescription', 'business.order-type'},
    );

    test('a capability is on only at the outlets that use it while master data sees the whole shop', () {
      expect(user.usesPrescriptionsAt(2), isTrue);
      expect(user.usesPrescriptionsAt(1), isFalse);
      expect(user.canViewPrescriptionsAt(1), isFalse);
      expect(user.canViewPrescriptionsAt(2), isTrue);
      expect(user.usesPrescriptions, isTrue);
      expect(user.canViewKitchenAt(2), isFalse);
    });

    test('cashier features switched off for one outlet stay on elsewhere', () {
      expect(user.hasFeatureAt('pos.receivables', 2), isFalse);
      expect(user.hasFeatureAt('pos.receivables', 1), isTrue);
      expect(user.hasFeatureAt('pos.cashier', 2), isTrue);
    });

    test('an older server without per-outlet capabilities falls back to the shop list', () {
      final old = _user([_outlet(1, 'Pusat', primary: true)], features: {'business.prescription'});

      expect(old.usesPrescriptionsAt(1), isTrue);
      expect(old.outletById(1)!.capabilities, isNull);
    });

    test('a new delivery note follows the outlet of the sale, not the active outlet', () {
      final shop = _user(
        [
          _outlet(1, 'Pusat', primary: true, capabilities: const ['business.delivery-note']),
          _outlet(2, 'Apotek', capabilities: const []),
        ],
        features: {'business.delivery-note'},
      );
      final sale = SaleDetail.fromJson({
        'id': 1, 'number': 'TRX-9', 'status': 'completed', 'status_label': 'Selesai', 'sold_at': '2026-10-08T10:00:00+07:00', 'cashier': {'name': 'Kasir'},
        'subtotal': 0, 'discount_amount': 0, 'tax_rate': '0', 'tax_amount': 0, 'total': 0, 'paid_amount': 0, 'cash_received': 0, 'change_amount': 0, 'due_amount': 0,
        'items': [], 'payments': [], 'abilities': <String, dynamic>{},
        'outlet': {'id': 2, 'name': 'Apotek', 'code': 'APT'},
      });

      expect(sale.outletId, 2);
      expect(shop.usesDeliveryNotesAt(sale.outletId), isFalse);
      expect(shop.usesDeliveryNotesAt(1), isTrue);
    });

    test('a capability switched off for the whole shop is off at every outlet', () {
      final off = _user([_outlet(1, 'Pusat', primary: true, capabilities: const ['business.prescription'])]);

      expect(off.usesPrescriptionsAt(1), isFalse);
    });

    test('the outlet profile survives the cached profile round trip', () {
      final restored = CurrentUser.fromJson(user.toJson());

      expect(restored.outletById(2)!.capabilities, ['business.prescription']);
      expect(restored.outletById(2)!.disabledFeatures, ['pos.receivables']);
      expect(restored.outletById(2)!.effectiveStoreTypeLabel, 'Apotek');
    });
  });

  group('outlet settings and categories', () {
    test('cashier and pharmacy rules are sent only when the server knows them', () {
      final current = OutletSettingsData.fromJson({
        'tax': {'inherit': true},
        'rules': {'inherit': false, 'allow_credit': false, 'allow_negative_stock': true, 'quick_cash': [5000, 10000]},
        'pharmacy': {'inherit': true, 'prescription_mode': 'warn', 'near_expiry_discount_percent': '10', 'near_expiry_discount_days': 3},
      });

      expect(current.quickCash, [5000, 10000]);
      expect(current.toJson()['rules'], {'inherit': false, 'allow_credit': false, 'allow_negative_stock': true, 'quick_cash': [5000, 10000]});
      expect((current.toJson()['pharmacy'] as Map)['near_expiry_discount_days'], '3');

      final older = OutletSettingsData.fromJson({'tax': {'inherit': true}});
      expect(older.toJson().containsKey('rules'), isFalse);
      expect(older.toJson().containsKey('pharmacy'), isFalse);
    });

    test('a category tells which outlets sell it', () {
      expect(CategoryRecord.fromJson({'id': 1, 'name': 'Obat', 'outlet_ids': [2]}).outletIds, [2]);
      expect(CategoryRecord.fromJson({'id': 1, 'name': 'Minuman', 'outlet_ids': <int>[]}).outletIds, isEmpty);
      expect(CategoryRecord.fromJson({'id': 1, 'name': 'Lama'}).outletIds, isNull);
    });
  });

  testWidgets('the owner adds a pharmacy outlet with the features they keep', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = _MockOutlets();
    when(() => repository.save(
          id: any(named: 'id'),
          name: any(named: 'name'),
          code: any(named: 'code'),
          address: any(named: 'address'),
          phone: any(named: 'phone'),
          copyFromOutletId: any(named: 'copyFromOutletId'),
          storeType: any(named: 'storeType'),
          includeSampleProducts: any(named: 'includeSampleProducts'),
          capabilities: any(named: 'capabilities'),
        )).thenAnswer((_) async => OutletInfo.fromJson(_outlet(3, 'Apotek Sehat', type: 'apotek')));
    final outlets = [OutletInfo.fromJson(_outlet(1, 'Pusat', primary: true, capabilities: const []))];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentUserProvider.overrideWithValue(_user([_outlet(1, 'Pusat', primary: true, capabilities: const [])])),
          outletRepositoryProvider.overrideWithValue(repository),
          storePresetsProvider.overrideWith((ref) async => [
                _preset('warung', 'Warung / Kelontong', const {}),
                _preset('apotek', 'Apotek', const {'business.prescription', 'business.batch-expiry'}),
              ]),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: Scaffold(body: SingleChildScrollView(child: OutletFormSheet(outlets: outlets)))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sama seperti outlet lain (Warung / Kelontong)'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, OutletStrings.nameLabel), 'Apotek Sehat');
    await tester.enterText(find.widgetWithText(TextField, OutletStrings.codeLabel), 'apt');
    await tester.tap(find.byKey(const ValueKey('outlet-store-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apotek').last);
    await tester.pumpAndSettle();

    expect(find.text(OutletStrings.capabilitiesSummary(2)), findsOneWidget);
    await tester.ensureVisible(find.text(OutletStrings.capabilitiesSummary(2)));
    await tester.tap(find.text(OutletStrings.capabilitiesSummary(2)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('outlet-capability-business.batch-expiry')));
    await tester.tap(find.byKey(const ValueKey('outlet-capability-business.batch-expiry')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(OutletStrings.save));
    await tester.tap(find.text(OutletStrings.save));
    await tester.pumpAndSettle();

    verify(() => repository.save(
          id: null,
          name: 'Apotek Sehat',
          code: 'APT',
          address: null,
          phone: null,
          copyFromOutletId: null,
          storeType: 'apotek',
          includeSampleProducts: true,
          capabilities: ['business.prescription'],
        )).called(1);
  });
}
