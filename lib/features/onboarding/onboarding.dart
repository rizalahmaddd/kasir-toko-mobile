import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/utils/json.dart';
import '../auth/auth_controller.dart';
import '../auth/data/current_user.dart';
import '../offline/catalog_snapshot.dart';
import '../pos/pos_providers.dart';
import '../printing/printer.dart';
import '../products/products_providers.dart';

/// A store type the owner can start from, with what applying it would create and change.
class StorePreset {
  const StorePreset({
    required this.key,
    required this.label,
    required this.description,
    required this.icon,
    required this.categories,
    required this.sampleProductCount,
    required this.settings,
    required this.disabledFeatures,
  });

  factory StorePreset.fromJson(Map<String, dynamic> json) => StorePreset(
        key: json['key'] as String,
        label: json['label'] as String? ?? '',
        description: json['description'] as String? ?? '',
        icon: json['icon'] as String? ?? '',
        categories: (json['categories'] as List? ?? const []).cast<String>(),
        sampleProductCount: asInt(json['sample_product_count']),
        settings: PresetSettings.fromJson(asMap(json['settings'])),
        disabledFeatures: (json['disabled_features'] as List? ?? const []).cast<String>(),
      );

  final String key;
  final String label;
  final String description;

  /// Lucide icon name, e.g. `coffee`.
  final String icon;
  final List<String> categories;
  final int sampleProductCount;
  final PresetSettings settings;
  final List<String> disabledFeatures;
}

class PresetSettings {
  const PresetSettings({
    required this.taxEnabled,
    required this.taxRate,
    required this.taxLabel,
    required this.allowCredit,
    required this.allowNegativeStock,
    required this.paymentMethods,
    required this.quickCash,
    required this.receiptFooter,
  });

  factory PresetSettings.fromJson(Map<String, dynamic> json) => PresetSettings(
        taxEnabled: json['tax_enabled'] as bool? ?? false,
        taxRate: asDouble(json['tax_rate']),
        taxLabel: json['tax_label'] as String? ?? '',
        allowCredit: json['allow_credit'] as bool? ?? false,
        allowNegativeStock: json['allow_negative_stock'] as bool? ?? false,
        paymentMethods: (json['payment_methods'] as List? ?? const []).cast<String>(),
        quickCash: (json['quick_cash'] as List? ?? const []).map(asInt).toList(),
        receiptFooter: json['receipt_footer'] as String? ?? '',
      );

  final bool taxEnabled;
  final double taxRate;
  final String taxLabel;
  final bool allowCredit;
  final bool allowNegativeStock;
  final List<String> paymentMethods;
  final List<int> quickCash;
  final String receiptFooter;
}

class PresetResult {
  const PresetResult({required this.categoriesCreated, required this.productsCreated, required this.productsSkipped, required this.tenant});

  factory PresetResult.fromJson(Map<String, dynamic> json) => PresetResult(
        categoriesCreated: asInt(json['categories_created']),
        productsCreated: asInt(json['products_created']),
        productsSkipped: asInt(json['products_skipped']),
        tenant: TenantInfo.fromJson(asMap(json['tenant'])),
      );

  final int categoriesCreated;
  final int productsCreated;

  /// Sample products left out because the plan's product limit was reached.
  final int productsSkipped;
  final TenantInfo tenant;
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) => OnboardingRepository(ref.watch(apiClientProvider)));

class OnboardingRepository {
  OnboardingRepository(this._api);

  final ApiClient _api;

  Future<List<StorePreset>> presets() async => ApiClient.list(await _api.get('onboarding/presets')).map(StorePreset.fromJson).toList();

  Future<PresetResult> apply(String storeType, {required bool includeSampleProducts}) async => PresetResult.fromJson(
        ApiClient.data(await _api.post('onboarding/apply', data: {'store_type': storeType, 'include_sample_products': includeSampleProducts})),
      );

  Future<TenantInfo> skip() async => TenantInfo.fromJson(ApiClient.data(await _api.post('onboarding/skip')));
}

final storePresetsProvider = FutureProvider.autoDispose<List<StorePreset>>((ref) => ref.watch(onboardingRepositoryProvider).presets());

final onboardingActionsProvider = Provider<OnboardingActions>(OnboardingActions.new);

class OnboardingActions {
  OnboardingActions(this._ref);

  final Ref _ref;

  Future<PresetResult> apply(String storeType, {required bool includeSampleProducts}) async {
    final result = await _ref.read(onboardingRepositoryProvider).apply(storeType, includeSampleProducts: includeSampleProducts);
    await _finish(result.tenant);
    return result;
  }

  Future<void> skip() async => _finish(await _ref.read(onboardingRepositoryProvider).skip());

  /// A preset rewrites categories, products and POS settings, so nothing cached before it is valid.
  Future<void> _finish(TenantInfo tenant) async {
    await _ref.read(authControllerProvider.notifier).updateTenant(tenant);

    _ref
      ..invalidate(posConfigProvider)
      ..invalidate(posCategoriesProvider)
      ..invalidate(catalogProvider)
      ..invalidate(productsProvider)
      ..invalidate(allCategoriesProvider)
      ..invalidate(categoriesProvider)
      ..invalidate(stockProvider)
      ..invalidate(receiptProfileProvider);

    if (_ref.read(catalogSnapshotProvider).value != null) {
      unawaited(_ref.read(catalogSnapshotProvider.notifier).download().then((_) {}, onError: (_) {}));
    }
  }
}
