import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/state_views.dart';
import '../../pos/cart_controller.dart';
import '../../pos/data/pos_models.dart';
import '../../pos/data/pos_repository.dart';
import '../data/orders_repository.dart';

/// Muat barang pesanan ke keranjang kasir untuk dilunasi; DP dipotong saat checkout.
Future<void> settleOrderAtCashier(BuildContext context, WidgetRef ref, int orderId) async {
  try {
    final cart = await ref.read(ordersRepositoryProvider).cart(orderId);
    final products = {for (final product in await ref.read(posRepositoryProvider).productsByIds(cart.items.map((item) => item.productId))) product.id: product};

    ref.read(cartProvider.notifier).loadOrder(
          LinkedOrder(id: cart.orderId, number: cart.number, deposit: cart.deposit),
          [
            for (final item in cart.items)
              if (products[item.productId] != null) (product: products[item.productId]!, quantity: item.quantity, note: item.note),
          ],
          customer: cart.customerId == null ? null : CustomerOption(id: cart.customerId!, name: cart.customerName ?? ''),
        );

    if (context.mounted) {
      showMessage(context, cart.skipped.isEmpty ? OrderStrings.loadedToCart(cart.number) : OrderStrings.loadedWithSkipped(cart.skipped.join(', ')), isError: cart.skipped.isNotEmpty);
      context.go(AppRoutes.pos);
    }
  } on ApiException catch (error) {
    if (context.mounted) {
      showError(context, error);
    }
  }
}
