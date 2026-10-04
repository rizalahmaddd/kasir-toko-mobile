import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_strings.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/app_storage.dart';
import '../../core/utils/formatters.dart' as fmt;
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

  /// Returns a warning to show the cashier, or null when the item was added as asked.
  String? add(Product product, {double quantity = 1}) {
    final index = state.items.indexWhere((item) => item.productId == product.id);
    final current = index == -1 ? 0.0 : state.items[index].quantity;
    final wanted = current + quantity;

    if (product.trackStock && !_allowNegativeStock && wanted > product.stock) {
      return product.stock <= 0
          ? PosStrings.stockOut(product.name)
          : PosStrings.stockRemaining(product.name, fmt.quantity(product.stock), product.unit);
    }

    final items = [...state.items];
    if (index == -1) {
      items.insert(0, CartItem.fromProduct(product, quantity: quantity));
    } else {
      items[index] = items[index].copyWith(
        quantity: wanted,
        price: product.price,
        stock: product.stock,
        imageUrl: product.imageUrl,
      );
    }
    state = state.copyWith(items: items);

    if (product.trackStock && _allowNegativeStock && wanted > product.stock) {
      final curStock = product.stock <= 0
          ? PosStrings.stockStatusEmpty
          : PosStrings.stockStatusRemaining(fmt.quantity(product.stock), product.unit);
      return PosStrings.stockSystemNotice(product.name, curStock);
    }

    return null;
  }

  String? setQuantity(int productId, double quantity) {
    if (quantity <= 0) {
      remove(productId);
      return null;
    }

    final item = state.items.firstWhere((item) => item.productId == productId);
    if (item.trackStock && !_allowNegativeStock && quantity > item.stock) {
      return PosStrings.stockRemaining(item.name, fmt.quantity(item.stock), item.unit);
    }

    _replace(productId, (item) => item.copyWith(quantity: quantity));
    return null;
  }

  void updateItem(int productId, {required double quantity, required int discount, String? note}) {
    _replace(
      productId,
      (item) => item.copyWith(quantity: quantity, discount: discount, note: note, clearNote: note == null || note.isEmpty),
    );
  }

  void remove(int productId) {
    state = state.copyWith(items: state.items.where((item) => item.productId != productId).toList());
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
      if (product.price != item.price) {
        notices.add(PosStrings.priceChanged(item.name, fmt.rupiah(product.price)));
      }
      items.add(item.copyWith(price: product.price, stock: product.stock));
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
        state = state.copyWith(
          items: [
            for (final item in state.items)
              if (prices['${item.productId}'] case {'price': final num price}) item.copyWith(price: price.toInt()) else item,
          ],
        );
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

  void _replace(int productId, CartItem Function(CartItem item) update) {
    state = state.copyWith(items: [for (final item in state.items) item.productId == productId ? update(item) : item]);
  }
}
