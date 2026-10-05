import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_strings.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/app_storage.dart';
import '../../core/utils/formatters.dart' as fmt;
import '../auth/access.dart';
import '../auth/auth_controller.dart';
import 'data/pos_models.dart';
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
    super.state = value;
    ref.read(sharedPreferencesProvider).setString(StorageKeys.cart, jsonEncode(value.toJson()));
  }

  bool get _allowNegativeStock => ref.read(posConfigProvider).value?.allowNegativeStock ?? false;

  bool get _multiUnit => ref.read(currentUserProvider)?.usesMultiUnit ?? false;

  /// Jumlah satuan dasar produk ini di baris lain keranjang.
  double _otherBase(int productId, String exceptKey) =>
      state.items.where((item) => item.productId == productId && item.key != exceptKey).fold(0.0, (sum, item) => sum + item.baseQuantity);

  /// Returns a warning to show the cashier, or null when the item was added as asked. Tanpa [unitId]
  /// dipakai satuan hasil scan barcode, lalu satuan default kasir, lalu satuan dasar.
  String? add(Product product, {double quantity = 1, int? unitId}) {
    final unit = _multiUnit ? (product.unitById(unitId) ?? product.unitById(product.matchedUnitId) ?? (unitId == null ? product.defaultUnit : null)) : null;
    final key = '${product.id}:${unit?.id ?? 0}';
    final index = state.items.indexWhere((item) => item.key == key && (item.note == null || item.note!.isEmpty) && item.discount == 0);
    final current = index == -1 ? 0.0 : state.items[index].quantity;
    final wanted = current + quantity;
    final factor = unit?.factor ?? 1;
    final wantedBase = _otherBase(product.id, key) + wanted * factor;

    if (product.trackStock && !_allowNegativeStock && wantedBase > product.stock + 0.0001) {
      return product.stock <= 0
          ? PosStrings.stockOut(product.name)
          : PosStrings.stockRemaining(product.name, fmt.quantity(product.stock), product.unit);
    }

    final items = [...state.items];
    if (index == -1) {
      items.insert(0, CartItem.fromProduct(product, quantity: quantity, unit: unit, withUnits: _multiUnit));
    } else {
      items[index] = items[index].copyWith(
        quantity: wanted,
        price: unit?.price ?? product.price,
        stock: product.stock,
        imageUrl: product.imageUrl,
        basePrice: product.price,
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

    _replace(key, (item) => item.copyWith(quantity: quantity));
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
    state = Cart(clientUuid: _uuid.v4());
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
      var line = item.copyWith(units: _multiUnit ? product.units : const [], basePrice: product.price, requiresPrescription: product.requiresPrescription);
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
        final prices = context['prices'] as Map<String, dynamic>? ?? const {};
        final unitPrices = context['unit_prices'] as Map<String, dynamic>? ?? const {};
        state = state.copyWith(
          items: [
            for (final item in state.items)
              if (unitPrices['${item.unitId}'] case {'price': final num price} when item.unitId != null)
                item.copyWith(price: price.toInt())
              else if (prices['${item.productId}'] case {'price': final num price} when item.unitId == null)
                item.copyWith(price: price.toInt())
              else
                item,
          ],
        );
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
