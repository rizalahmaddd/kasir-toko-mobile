import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_pos_mobile/core/offline/offline_cache.dart';
import 'package:web_pos_mobile/core/storage/app_storage.dart';
import 'package:web_pos_mobile/features/auth/data/current_user.dart';

Map<String, dynamic> _userJson({Object? tenant}) => {
      'id': 3,
      'name': 'Pemilik',
      'username': 'pemilik',
      'roles': ['superadmin'],
      'permissions': <String>[],
      'is_superadmin': true,
      'enabled_features': <String>[],
      'tenant': tenant,
    };

Future<ProviderContainer> _container({int? tenantId}) async {
  final prefs = await SharedPreferences.getInstance();

  return ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    offlineTenantProvider.overrideWithValue(tenantId),
  ]);
}

void main() {
  group('TenantInfo', () {
    test('reads the shop and its subscription state from /auth/me', () {
      final user = CurrentUser.fromJson(_userJson(tenant: {
        'id': 9,
        'name': 'Toko Maju',
        'plan': 'trial',
        'plan_label': 'Uji Coba',
        'access_ends_at': '2026-10-16T23:59:59+07:00',
        'blocked_reason': null,
      }));

      expect(user.tenant?.name, 'Toko Maju');
      expect(user.tenant?.isTrial, isTrue);
      expect(user.tenant?.accessEndsAt, isNotNull);
      expect(user.isTenantBlocked, isFalse);
    });

    test('survives the cached-profile round trip, including a blocked state', () {
      final user = CurrentUser.fromJson(_userJson(tenant: {'id': 9, 'name': 'Toko Maju', 'plan': 'pro', 'plan_label': 'Pro'}));
      final blocked = user.withTenant(user.tenant!.blocked('subscription_expired', message: 'Langganan habis.'));
      final restored = CurrentUser.fromJson(blocked.toJson());

      expect(restored.isTenantBlocked, isTrue);
      expect(restored.tenant?.blockedReason, 'subscription_expired');
      expect(restored.tenant?.blockedMessage, 'Langganan habis.');
    });

    test('reads how to renew a blocked shop and keeps it in the cached profile', () {
      final user = CurrentUser.fromJson(_userJson(tenant: {
        'id': 9,
        'name': 'Toko Maju',
        'plan': 'trial',
        'plan_label': 'Uji Coba',
        'blocked_reason': 'trial_expired',
        'renewal': {
          'contact': 'WA 0812-0000-1111',
          'payment_instructions': 'Transfer BCA 123',
          'plans': [
            {'key': 'basic', 'label': 'Basic', 'price': 99000},
          ],
        },
      }));
      final restored = CurrentUser.fromJson(user.toJson());
      final renewal = restored.tenant?.renewal;

      expect(renewal?.contact, 'WA 0812-0000-1111');
      expect(renewal?.paymentInstructions, 'Transfer BCA 123');
      expect(renewal?.plans.single.label, 'Basic');
      expect(renewal?.plans.single.price, 99000);
      expect(restored.tenant?.blocked('trial_expired').renewal, isNotNull);
    });

    test('has no renewal info while the shop is usable or on older servers', () {
      final user = CurrentUser.fromJson(_userJson(tenant: {'id': 9, 'name': 'Toko Maju', 'plan': 'pro', 'plan_label': 'Pro', 'renewal': null}));

      expect(user.tenant?.renewal, isNull);
    });

    test('accepts profiles from servers without multi-tenancy', () {
      final user = CurrentUser.fromJson(_userJson());

      expect(user.tenant, isNull);
      expect(user.isTenantBlocked, isFalse);
    });
  });

  group('OfflineCache', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      final dir = Directory.systemTemp.createTempSync('offline_cache_test');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => dir.path,
      );
    });

    test('never serves one shop the cached data of another shop on the same server', () async {
      final shopA = await _container(tenantId: 1);
      await shopA.read(offlineCacheProvider).put('pos_config', {'tax': 11});

      final shopB = await _container(tenantId: 2);

      expect(shopA.read(offlineCacheProvider).get('pos_config'), {'tax': 11});
      expect(shopB.read(offlineCacheProvider).get('pos_config'), isNull);
    });

    test('clear() keeps sales that are still waiting to be sent', () async {
      SharedPreferences.setMockInitialValues({'offline_sales_queue': '[{"x":1}]'});
      final container = await _container(tenantId: 1);
      await container.read(offlineCacheProvider).put('pos_config', {'tax': 11});

      await container.read(offlineCacheProvider).clear();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('offline_sales_queue'), '[{"x":1}]');
      expect(container.read(offlineCacheProvider).get('pos_config'), isNull);
    });
  });
}
