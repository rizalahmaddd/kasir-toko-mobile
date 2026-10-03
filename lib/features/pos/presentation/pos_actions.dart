import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/state_views.dart';
import '../cart_controller.dart';
import '../data/pos_models.dart';
import '../data/pos_repository.dart';
import '../pos_providers.dart';

void addToCart(BuildContext context, WidgetRef ref, Product product, {double quantity = 1}) {
  final warning = ref.read(cartProvider.notifier).add(product, quantity: quantity);

  if (warning != null) {
    final allowNegative = ref.read(posConfigProvider).value?.allowNegativeStock ?? false;
    final isBlocked = product.trackStock && !allowNegative;
    if (isBlocked) {
      unawaited(HapticFeedback.heavyImpact());
      showMessage(context, warning, isError: true);
    } else {
      unawaited(HapticFeedback.lightImpact());
      showMessage(context, warning, isError: false);
    }
  } else {
    unawaited(HapticFeedback.selectionClick());
  }
}

/// Barcode first, then SKU, same order as the web cashier.
Future<void> addByCode(BuildContext context, WidgetRef ref, String code) async {
  final trimmed = code.trim();
  if (trimmed.isEmpty) {
    return;
  }

  try {
    final product = await ref.read(posRepositoryProvider).lookup(trimmed);
    if (context.mounted) {
      addToCart(context, ref, product);
    }
  } on ApiException catch (error) {
    if (context.mounted) {
      unawaited(HapticFeedback.heavyImpact());
      showMessage(context, error.statusCode == 404 ? 'Kode $trimmed tidak ditemukan.' : error.message, isError: true);
    }
  }
}
