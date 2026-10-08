import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/state_views.dart';
import '../cart_controller.dart';
import '../data/pos_models.dart';
import '../data/pos_repository.dart';
import '../pos_providers.dart';
import '../../kitchen/data/kitchen_repository.dart';
import '../../printing/presentation/printer_screen.dart';
import '../../printing/printer.dart';
import 'widgets/modifier_picker_sheet.dart';
import 'widgets/serial_picker_sheet.dart';
import 'widgets/variant_picker_sheet.dart';

/// Menu dengan grup pilihan tambahan membuka pemilih dulu; batal berarti tidak ada yang ditambahkan.
Future<void> addToCart(BuildContext context, WidgetRef ref, Product product, {double quantity = 1, int? unitId}) async {
  final config = ref.read(posConfigProvider).value;
  if ((config?.variantsEnabled ?? false) && product.variants.isNotEmpty) {
    final variant = await VariantPickerSheet.show(context, product, allowNegativeStock: config?.allowNegativeStock ?? false);
    if (variant == null || !context.mounted) {
      return;
    }
    product = product.variantProduct(variant);
  }

  var serials = const <String>[];
  if ((config?.serialsEnabled ?? false) && product.trackSerial) {
    final taken = ref.read(cartProvider).items.where((item) => item.productId == product.id).expand((item) => item.serials).toSet();
    final picked = await SerialPickerSheet.show(context, productId: product.id, title: product.name, selected: [?product.matchedSerial], exclude: taken);
    if (picked == null || !context.mounted) {
      return;
    }
    serials = picked;
  }

  var modifiers = const <SelectedModifier>[];
  if ((ref.read(posConfigProvider).value?.modifiersEnabled ?? false) && product.modifierGroups.isNotEmpty) {
    final picked = await ModifierPickerSheet.show(context, title: product.name, groups: product.modifierGroups);
    if (picked == null || !context.mounted) {
      return;
    }
    modifiers = picked;
  }

final warning = ref.read(cartProvider.notifier).add(product, quantity: quantity, unitId: unitId, modifiers: modifiers, serials: serials);

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

void decrementFromCart(BuildContext context, WidgetRef ref, Product product, {double quantity = 1}) {
  final cart = ref.read(cartProvider);
  final item = cart.items.where((i) => i.productId == product.id).firstOrNull;
  if (item == null) return;

  final newQty = item.quantity - quantity;
  if (newQty <= 0) {
    ref.read(cartProvider.notifier).remove(item.key);
    unawaited(HapticFeedback.mediumImpact());
  } else {
    final warning = ref.read(cartProvider.notifier).setQuantity(item.key, newQty);
    if (warning != null) {
      unawaited(HapticFeedback.heavyImpact());
      showMessage(context, warning, isError: true);
    } else {
      unawaited(HapticFeedback.selectionClick());
    }
  }
}

void removeFromCart(BuildContext context, WidgetRef ref, String key) {
  ref.read(cartProvider.notifier).remove(key);
  unawaited(HapticFeedback.mediumImpact());
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
      await addToCart(context, ref, product);
    }
  } on ApiException catch (error) {
    if (context.mounted) {
      unawaited(HapticFeedback.heavyImpact());
      showMessage(context, error.statusCode == 404 ? PosStrings.codeNotFound(trimmed) : error.message, isError: true);
    }
  }
}

/// Pilih ulang nomor seri baris keranjang; jumlah baris mengikuti banyaknya nomor seri.
Future<void> editLineSerials(BuildContext context, WidgetRef ref, CartItem item) async {
  final taken = ref.read(cartProvider).items.where((other) => other.productId == item.productId && other.key != item.key).expand((other) => other.serials).toSet();
  final picked = await SerialPickerSheet.show(context, productId: item.productId, title: item.name, selected: item.serials, exclude: taken);
  if (picked == null || !context.mounted) {
    return;
  }
  final warning = ref.read(cartProvider.notifier).setSerials(item.key, picked);
  if (warning != null) {
    showMessage(context, warning, isError: true);
  }
}

/// Cetak tiket dapur otomatis bila printer & cetak otomatis aktif; selain itu tiket cukup tampil di Layar Dapur.
Future<void> printKitchenTicketIfAuto(BuildContext context, WidgetRef ref, int ticketId) async {
  final settings = ref.read(printerSettingsProvider);
  if (!settings.isConfigured || !settings.autoPrint) {
    return;
  }

  try {
    final ticket = await ref.read(kitchenRepositoryProvider).show(ticketId);
    if (context.mounted) {
      await runPrint(context, () => ref.read(printerServiceProvider).printKitchenTicket(ticket), success: PrintingStrings.kitchenTicketPrinted);
    }
  } on ApiException catch (error) {
    if (context.mounted) {
      showError(context, error);
    }
  }
}
