import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/storage/app_storage.dart';
import 'data/pos_models.dart';
import 'data/pos_repository.dart';

enum PosCatalogDensity {
  list(0),
  compact(1),
  standard(2),
  large(3);

  const PosCatalogDensity(this.value);
  final int value;

  String get label => switch (this) {
        PosCatalogDensity.list => PosStrings.densityList,
        PosCatalogDensity.compact => PosStrings.densityCompact,
        PosCatalogDensity.standard => PosStrings.densityStandard,
        PosCatalogDensity.large => PosStrings.densityLarge,
      };

  static PosCatalogDensity fromValue(int val) {
    return switch (val) {
      0 => PosCatalogDensity.list,
      1 => PosCatalogDensity.compact,
      3 => PosCatalogDensity.large,
      _ => PosCatalogDensity.standard,
    };
  }

  PosGridConfig computeConfig(double width) {
    final isPhone = width < 600;
    final isTabletLarge = width >= 800;

    return switch (this) {
      PosCatalogDensity.list => PosGridConfig(
          columns: isPhone ? 1 : (width >= 1040 ? 3 : 2),
          mainAxisExtent: 68,
          photoHeight: 44,
          isLarge: false,
          isCompact: false,
        ),
      PosCatalogDensity.compact => PosGridConfig(
          // Phone: 3 Kolom! Tablet: 4-6 Kolom!
          columns: isPhone ? 3 : (width >= 1100 ? 6 : (width >= 800 ? 5 : 4)),
          mainAxisExtent: isPhone ? 172 : 188,
          photoHeight: isPhone ? 86 : 96,
          isLarge: false,
          isCompact: true,
        ),
      PosCatalogDensity.standard => PosGridConfig(
          // Phone: 2 Kolom (Default). Tablet: 3-4 Kolom.
          columns: isPhone ? 2 : (isTabletLarge ? 4 : 3),
          mainAxisExtent: 226,
          photoHeight: 114,
          isLarge: false,
          isCompact: false,
        ),
      PosCatalogDensity.large => PosGridConfig(
          // Phone: 1 Kolom (Wide Showcase). Tablet: 2 Kolom.
          columns: isPhone ? 1 : 2,
          mainAxisExtent: isPhone ? 262 : 275,
          photoHeight: isPhone ? 140 : 160,
          isLarge: true,
          isCompact: false,
        ),
    };
  }
}

class PosGridConfig {
  const PosGridConfig({
    required this.columns,
    required this.mainAxisExtent,
    required this.photoHeight,
    required this.isLarge,
    required this.isCompact,
  });

  final int columns;
  final double mainAxisExtent;
  final double photoHeight;
  final bool isLarge;
  final bool isCompact;
}

final posCatalogDensityProvider = NotifierProvider<PosCatalogDensityNotifier, PosCatalogDensity>(
  PosCatalogDensityNotifier.new,
);

class PosCatalogDensityNotifier extends Notifier<PosCatalogDensity> {
  @override
  PosCatalogDensity build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final saved = prefs.getInt(StorageKeys.catalogDensity);
    return saved != null ? PosCatalogDensity.fromValue(saved) : PosCatalogDensity.standard;
  }

  void setDensity(PosCatalogDensity density) {
    if (state == density) return;
    state = density;
    ref.read(sharedPreferencesProvider).setInt(StorageKeys.catalogDensity, density.value);
  }
}

class PosDisplaySettings {
  const PosDisplaySettings({
    this.keepScreenOn = true,
    this.qrFullBrightness = true,
  });

  final bool keepScreenOn;
  final bool qrFullBrightness;

  PosDisplaySettings copyWith({
    bool? keepScreenOn,
    bool? qrFullBrightness,
  }) =>
      PosDisplaySettings(
        keepScreenOn: keepScreenOn ?? this.keepScreenOn,
        qrFullBrightness: qrFullBrightness ?? this.qrFullBrightness,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PosDisplaySettings &&
          runtimeType == other.runtimeType &&
          keepScreenOn == other.keepScreenOn &&
          qrFullBrightness == other.qrFullBrightness;

  @override
  int get hashCode => Object.hash(keepScreenOn, qrFullBrightness);
}

final posDisplaySettingsProvider = NotifierProvider<PosDisplaySettingsNotifier, PosDisplaySettings>(
  PosDisplaySettingsNotifier.new,
);

class PosDisplaySettingsNotifier extends Notifier<PosDisplaySettings> {
  @override
  PosDisplaySettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final keepScreenOn = prefs.getBool(StorageKeys.posKeepScreenOn) ?? true;
    final qrFullBrightness = prefs.getBool(StorageKeys.posQrFullBrightness) ?? true;
    return PosDisplaySettings(
      keepScreenOn: keepScreenOn,
      qrFullBrightness: qrFullBrightness,
    );
  }

  void setKeepScreenOn(bool value) {
    if (state.keepScreenOn == value) return;
    state = state.copyWith(keepScreenOn: value);
    ref.read(sharedPreferencesProvider).setBool(StorageKeys.posKeepScreenOn, value);
  }

  void setQrFullBrightness(bool value) {
    if (state.qrFullBrightness == value) return;
    state = state.copyWith(qrFullBrightness: value);
    ref.read(sharedPreferencesProvider).setBool(StorageKeys.posQrFullBrightness, value);
  }
}

final posConfigProvider = FutureProvider<PosConfig>((ref) => ref.watch(posRepositoryProvider).config());

final posCategoriesProvider = FutureProvider<List<Category>>((ref) => ref.watch(posRepositoryProvider).categories());

class CatalogQuery {
  const CatalogQuery({this.search = '', this.categoryId});

  final String search;
  final int? categoryId;

  @override
  bool operator ==(Object other) => other is CatalogQuery && other.search == search && other.categoryId == categoryId;

  @override
  int get hashCode => Object.hash(search, categoryId);
}

final catalogQueryProvider = NotifierProvider<CatalogQueryNotifier, CatalogQuery>(CatalogQueryNotifier.new);

class CatalogQueryNotifier extends Notifier<CatalogQuery> {
  @override
  CatalogQuery build() => const CatalogQuery();

  void search(String term) => state = CatalogQuery(search: term.trim(), categoryId: state.categoryId);

  void category(int? id) => state = CatalogQuery(search: state.search, categoryId: id);
}

class CatalogPage {
  const CatalogPage({required this.products, required this.page, required this.hasMore, this.loadingMore = false});

  final List<Product> products;
  final int page;
  final bool hasMore;
  final bool loadingMore;

  CatalogPage copyWith({List<Product>? products, int? page, bool? hasMore, bool? loadingMore}) => CatalogPage(
        products: products ?? this.products,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

final catalogProvider = AsyncNotifierProvider<CatalogController, CatalogPage>(CatalogController.new);

class CatalogController extends AsyncNotifier<CatalogPage> {
  @override
  Future<CatalogPage> build() async {
    final query = ref.watch(catalogQueryProvider);
    final result = await ref.read(posRepositoryProvider).products(search: query.search, categoryId: query.categoryId);

    return CatalogPage(products: result.items, page: result.currentPage, hasMore: result.hasMore);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) {
      return;
    }

    state = AsyncData(current.copyWith(loadingMore: true));
    final query = ref.read(catalogQueryProvider);

    try {
      final result = await ref.read(posRepositoryProvider).products(search: query.search, categoryId: query.categoryId, page: current.page + 1);
      state = AsyncData(
        current.copyWith(products: [...current.products, ...result.items], page: result.currentPage, hasMore: result.hasMore, loadingMore: false),
      );
    } on Object {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }
}

final heldOrderPreviewsProvider = NotifierProvider<HeldOrderPreviewsNotifier, Map<int, String>>(HeldOrderPreviewsNotifier.new);

class HeldOrderPreviewsNotifier extends Notifier<Map<int, String>> {
  @override
  Map<int, String> build() => {};

  void save(int id, String preview) {
    state = {...state, id: preview};
  }

  void remove(int id) {
    final next = {...state}..remove(id);
    state = next;
  }
}

