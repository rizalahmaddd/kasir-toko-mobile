import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_strings.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/app_storage.dart';
import '../../core/utils/formatters.dart' as fmt;
import '../auth/access.dart';
import '../outlets/outlet_controller.dart';
import '../auth/auth_controller.dart';
import 'data/pos_models.dart';
import 'cart_math.dart';
import 'data/pos_repository.dart';
import 'pos_providers.dart';

const _uuid = Uuid();

final cartProvider = NotifierProvider<CartController, Cart>(CartController.new);

class CartController extends Notifier<Cart> {
  @override
  Cart build() {
    final saved = ref.read(sharedPreferencesProvider).getString(StorageKeys.cart);
    if (saved == null) {
      return Cart(clientUuid: _uuid.v4());
    }

    try {
      return Cart.fromJson(jsonDecode(saved) as Map<String, dynamic>, fallbackUuid: _uuid.v4());
    } on Object {
      return Cart(clientUuid: _uuid.v4());
    }
  }

  @override
  set state(Cart value) {
    final priced = _applyTiers(value);
    super.state = priced;
    ref.read(sharedPreferencesProvider).setString(StorageKeys.cart, jsonEncode(priced.toJson()));
  }

  /// Harga grosir dihitung dari jumlah semua baris satuan dasar produk yang sama, seperti di server.
  Cart _applyTiers(Cart cart) => _applyNearExpiry(_applyGrosir(cart));

  /// Potongan ED dekat: unit ED dekat produk dibagi berurutan ke baris satuan dasarnya, sama dengan server.
  Cart _applyNearExpiry(Cart cart) {
    final percent = _config?.nearExpiryDiscountPercent ?? 0;
    if (!cart.items.any((item) => item.nearExpiry > 0 || item.autoDiscount > 0)) {
      return cart;
    }

    final left = <int, double>{};
    return cart.copyWith(
      items: [
        for (final item in cart.items)
          if (item.unitId != null || item.nearExpiry <= 0)
            item.copyWith(autoDiscount: 0)
          else
            item.copyWith(autoDiscount: _takeNearExpiry(left, item, percent)),
      ],
    );
  }

  int _takeNearExpiry(Map<int, double> left, CartItem item, double percent) {
    final available = left[item.productId] ?? item.nearExpiry;
    left[item.productId] = available - item.quantity > 0 ? double.parse((available - item.quantity).toStringAsFixed(3)) : 0;

    return nearExpiryDiscount(item.unitPrice, item.quantity, available, percent);
  }

  Cart _applyGrosir(Cart cart) {
    if (!cart.items.any((item) => item.tiers.isNotEmpty || item.tierPrice != null)) {
      return cart;
    }

    final quantities = <int, double>{};
    for (final item in cart.items.where((item) => item.unitId == null)) {
      quantities[item.productId] = (quantities[item.productId] ?? 0) + item.quantity;
    }

    return cart.copyWith(
      items: [
        for (final item in cart.items)
          item.unitId != null || item.tiers.isEmpty
              ? item.copyWith(clearTierPrice: true)
              : item.copyWith(tierPrice: tierPrice(item.price, item.tiers, quantities[item.productId] ?? 0)),
      ],
    );
  }

  PosConfig? get _config => ref.read(posConfigProvider).value;

  String? get _defaultOrderType => (_config?.orderTypeEnabled ?? false) ? OrderTypes.dineIn : null;

  bool get _allowNegativeStock => _config?.allowNegativeStock ?? false;

  bool get _multiUnit => ref.read(currentUserProvider)?.usesMultiUnitAt(ref.read(currentOutletIdProvider)) ?? false;

  /// Jumlah satuan dasar produk ini di baris lain keranjang.
  double _otherBase(int productId, String exceptKey) =>
      state.items.where((item) => item.productId == productId && item.key != exceptKey).fold(0.0, (sum, item) => sum + item.baseQuantity);

  /// Returns a warning to show the cashier, or null when the item was added as asked. Tanpa [unitId]
  /// dipakai satuan hasil scan barcode, lalu satuan default kasir, lalu satuan dasar.
  /// Produk bernomor seri ditambahkan bersama nomor serinya; jumlah baris = banyaknya nomor seri.
  String? add(Product product, {double quantity = 1, int? unitId, List<SelectedModifier> modifiers = const [], List<String> serials = const []}) {
    final unit = _multiUnit ? (product.unitById(unitId) ?? product.unitById(product.matchedUnitId) ?? (unitId == null ? product.defaultUnit : null)) : null;
    final key = '${product.id}:${unit?.id ?? 0}:${(modifiers.map((m) => m.id).toList()..sort()).join('-')}';
    final index = state.items.indexWhere((item) => item.key == key && (item.note == null || item.note!.isEmpty) && item.discount == 0);
    final current = index == -1 ? 0.0 : state.items[index].quantity;
    final mergedSerials = {...(index == -1 ? const <String>[] : state.items[index].serials), ...serials}.toList();
    final wanted = product.trackSerial && serials.isNotEmpty ? mergedSerials.length.toDouble() : current + quantity;
    final factor = unit?.factor ?? 1;
    final wantedBase = _otherBase(product.id, key) + wanted * factor;

    if (product.trackStock && !_allowNegativeStock && wantedBase > product.stock + 0.0001) {
      return product.stock <= 0
          ? PosStrings.stockOut(product.name)
          : PosStrings.stockRemaining(product.name, fmt.quantity(product.stock), product.unit);
    }

    final items = [...state.items];
    if (index == -1) {
      items.insert(
        0,
        CartItem.fromProduct(
          product,
          quantity: wanted,
          unit: unit,
          withUnits: _multiUnit,
          modifiers: modifiers,
          withTiers: _config?.tieredPriceEnabled ?? false,
          withModifiers: _config?.modifiersEnabled ?? false,
          serials: mergedSerials,
        ),
      );
    } else {
      items[index] = items[index].copyWith(
        quantity: wanted,
        price: unit?.price ?? product.price,
        stock: product.stock,
        imageUrl: product.imageUrl,
        basePrice: product.price,
        tiers: (_config?.tieredPriceEnabled ?? false) ? product.tiers : const [],
        serials: mergedSerials,
      );
    }
    state = state.copyWith(items: items);

    if (product.trackStock && _allowNegativeStock && wantedBase > product.stock) {
      final curStock = product.stock <= 0
          ? PosStrings.stockStatusEmpty
          : PosStrings.stockStatusRemaining(fmt.quantity(product.stock), product.unit);
      return PosStrings.stockSystemNotice(product.name, curStock);
    }

    return null;
  }

  String? setQuantity(String key, double quantity) {
    if (quantity <= 0) {
      remove(key);
      return null;
    }

    final item = state.items.firstWhere((item) => item.key == key);
    final error = stockProblem(item, quantity, item.factor);
    if (error != null) {
      return error;
    }

    _replace(key, (item) => item.copyWith(quantity: quantity, serials: item.serials.length > quantity ? item.serials.take(quantity.round()).toList() : null));
    return null;
  }

  /// Pesan bila [quantity] dalam satuan berfaktor [factor] melebihi stok (stok minus tidak diizinkan).
  String? stockProblem(CartItem item, double quantity, double factor) {
    if (item.trackStock && !_allowNegativeStock && _otherBase(item.productId, item.key) + quantity * factor > item.stock + 0.0001) {
      return PosStrings.stockRemaining(item.name, fmt.quantity(item.stock), item.baseUnit ?? item.unit);
    }

    return null;
  }

  /// Ubah jumlah, diskon, catatan, dan satuan baris. Bila satuan baru sudah ada di baris lain, baris tetap terpisah.
  void updateItem(String key, {required double quantity, required int discount, String? note, ProductUnitOption? unit, bool changeUnit = false}) {
    _replace(key, (item) {
      final base = changeUnit ? item.withUnit(unit) : item;

      return base.copyWith(quantity: quantity, discount: discount, note: note, clearNote: note == null || note.isEmpty);
    });
  }

  /// Jumlah baris mengikuti nomor seri yang dipilih. Null bila stok mengizinkan, selain itu pesan untuk kasir.
  String? setSerials(String key, List<String> serials) {
    final item = state.items.firstWhere((item) => item.key == key);
    final problem = stockProblem(item, serials.length.toDouble(), item.factor);
    if (problem != null) {
      return problem;
    }
    if (serials.isEmpty) {
      remove(key);
      return null;
    }

    _replace(key, (item) => item.copyWith(serials: serials, quantity: serials.length.toDouble()));
    return null;
  }

  /// Muat barang pesanan untuk dilunasi; uang mukanya dipotong dari total saat checkout.
  void loadOrder(LinkedOrder order, List<({Product product, double quantity, String? note})> lines, {CustomerOption? customer}) {
    state = Cart(
      clientUuid: _uuid.v4(),
      orderType: _defaultOrderType,
      customer: customer,
      customerOrder: order,
      items: [
        for (final line in lines)
          CartItem.fromProduct(
            line.product,
            quantity: line.quantity,
            withUnits: _multiUnit,
            withTiers: _config?.tieredPriceEnabled ?? false,
            withModifiers: false,
          ).copyWith(note: line.note),
      ],
    );
  }

  void clearCustomerOrder() {
    state = state.copyWith(clearCustomerOrder: true);
  }

  void setModifiers(String key, List<SelectedModifier> modifiers) {
    _replace(key, (item) => item.copyWith(modifiers: modifiers));
  }

  void setOrderType(String type) {
    state = state.copyWith(orderType: type, clearTable: type != OrderTypes.dineIn);
  }

  void setTable(String table) {
    state = state.copyWith(table: table.trim(), clearTable: table.trim().isEmpty);
  }

  void remove(String key) {
    state = state.copyWith(items: state.items.where((item) => item.key != key).toList());
  }

  void setPrescription(LinkedPrescription prescription) {
    state = state.copyWith(clearPrescription: true).copyWith(prescription: prescription);
  }

  void setPrescriptionDraft(PrescriptionDraft draft) {
    state = state.copyWith(clearPrescription: true).copyWith(prescriptionDraft: draft);
  }

  void clearPrescription() {
    state = state.copyWith(clearPrescription: true);
  }

  void setCustomer(CustomerOption? customer) {
    state = customer == null ? state.copyWith(clearCustomer: true) : state.copyWith(customer: customer);
  }

  void setDiscount(DiscountType? type, double value) {
    state = type == null || value <= 0 ? state.copyWith(clearDiscount: true) : state.copyWith(discountType: type, discountValue: value);
  }

  void clear() {
    state = Cart(clientUuid: _uuid.v4(), orderType: _defaultOrderType);
  }

  /// A resumed cart is a new transaction, so it never reuses an old client_uuid.
  void load(Map<String, dynamic> json) {
    state = Cart.fromJson(json, fallbackUuid: _uuid.v4()).copyWith(clientUuid: _uuid.v4());
  }

  /// Refreshes price & stock of a cart restored from disk or a held order. Returns notices for
  /// products whose price changed or that are no longer sold.
  Future<List<String>> syncWithServer() async {
    if (state.isEmpty) {
      return const [];
    }

    final products = await ref.read(posRepositoryProvider).productsByIds(state.items.map((item) => item.productId));
    final byId = {for (final product in products) product.id: product};
    final notices = <String>[];
    final items = <CartItem>[];

    for (final item in state.items) {
      final product = byId[item.productId];
      if (product == null) {
        notices.add(PosStrings.productNoLongerSold(item.name));
        continue;
      }
      var line = item.copyWith(
        units: _multiUnit ? product.units : const [],
        basePrice: product.price,
        requiresPrescription: product.requiresPrescription,
        tiers: (_config?.tieredPriceEnabled ?? false) ? product.tiers : const [],
modifierGroups: (_config?.modifiersEnabled ?? false) ? product.modifierGroups : const [],
        nearExpiry: product.nearExpiry,
      );
      final options = {
        for (final group in product.modifierGroups)
          for (final option in group.modifiers) option.id: option,
      };
      if (line.modifiers.isNotEmpty) {
        final kept = [
          for (final m in line.modifiers)
            if (options[m.id] != null) m.withPrice(options[m.id]!.price),
        ];
        if (kept.length != line.modifiers.length) {
          notices.add(PosStrings.modifierRemoved(item.name));
        }
        line = line.copyWith(modifiers: kept);
      }
      final unit = product.unitById(item.unitId);
      if (item.unitId != null && unit == null) {
        notices.add(PosStrings.unitRemoved(item.name, item.unit));
        line = line.withUnit(null);
      }
      final price = unit?.price ?? product.price;
      if (price != line.price) {
        notices.add(PosStrings.priceChanged(item.name, fmt.rupiah(price)));
      }
      items.add(line.copyWith(price: price, stock: product.stock));
    }

    state = state.copyWith(items: items);

    return notices;
  }

  /// Applies a checkout rejection to the cart where the server tells us what changed.
  void applyRejection(ApiException error) {
    final context = error.context;

    switch (error.reason) {
      case 'unavailable':
        final ids = (context['product_ids'] as List? ?? const []).map((id) => (id as num).toInt()).toSet();
        state = state.copyWith(items: state.items.where((item) => !ids.contains(item.productId)).toList());
      case 'price_changed':
        final modifierPrices = context['modifier_prices'] as Map<String, dynamic>? ?? const {};
        if (modifierPrices.isNotEmpty) {
          state = state.copyWith(
            items: [
              for (final item in state.items)
                item.copyWith(
                  modifiers: [
                    for (final m in item.modifiers)
                      if (modifierPrices['${m.id}'] case {'price': final num price}) m.withPrice(price.toInt()) else m,
                  ],
                ),
            ],
          );
        }
        final prices = context['prices'] as Map<String, dynamic>? ?? const {};
        final unitPrices = context['unit_prices'] as Map<String, dynamic>? ?? const {};
        state = state.copyWith(
          items: [
            for (final item in state.items)
              if (unitPrices['${item.unitId}'] case {'price': final num price} when item.unitId != null)
                item.copyWith(price: price.toInt())
              else if (prices['${item.productId}'] case final Map<String, dynamic> info when item.unitId == null)
                item.copyWith(
                  price: ((info['base_price'] ?? info['price']) as num).toInt(),
                  tiers: info['tiers'] is List ? (info['tiers'] as List).cast<Map<String, dynamic>>().map(PriceTier.fromJson).toList() : null,
                )
              else
                item,
          ],
        );
      case 'near_expiry_changed':
        ref.invalidate(posConfigProvider);
        final nearExpiry = context['near_expiry'] as Map<String, dynamic>? ?? const {};
        state = state.copyWith(
          items: [
            for (final item in state.items)
              if (nearExpiry['${item.productId}'] case {'quantity': final num quantity}) item.copyWith(nearExpiry: quantity.toDouble()) else item,
          ],
        );
      case 'serial_unavailable':
        final serials = (context['serials'] as List? ?? const []).map((s) => '$s').toSet();
        state = state.copyWith(items: [for (final item in state.items) item.copyWith(serials: item.serials.where((s) => !serials.contains(s)).toList())]);
      case 'order_closed':
        state = state.copyWith(clearCustomerOrder: true);
      case 'modifier_unavailable':
        final ids = (context['modifier_ids'] as List? ?? const []).map((id) => (id as num).toInt()).toSet();
        state = state.copyWith(items: [for (final item in state.items) item.copyWith(modifiers: item.modifiers.where((m) => !ids.contains(m.id)).toList())]);
      case 'unit_unavailable':
        final ids = (context['unit_ids'] as List? ?? const []).map((id) => (id as num).toInt()).toSet();
        state = state.copyWith(items: [for (final item in state.items) ids.contains(item.unitId) ? item.withUnit(null) : item]);
      case 'prescription_invalid':
        state = state.copyWith(clearPrescription: true);
      case 'insufficient_stock':
        final stock = context['stock'] as Map<String, dynamic>? ?? const {};
        state = state.copyWith(
          items: [
            for (final item in state.items)
              if (stock['${item.productId}'] case final num left) item.copyWith(stock: left.toDouble()) else item,
          ],
        );
    }
  }

  void _replace(String key, CartItem Function(CartItem item) update) {
    state = state.copyWith(items: [for (final item in state.items) item.key == key ? update(item) : item]);
  }
}
