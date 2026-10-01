import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/auth_controller.dart';
import '../../shift/presentation/open_shift_card.dart';
import '../../shift/shift_controller.dart';
import '../cart_controller.dart';
import '../pos_providers.dart';
import 'cart_panel.dart';
import 'catalog_panel.dart';
import 'pos_actions.dart';

class PosScreen extends ConsumerWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    if (user != null && (!user.can('pos.sell') || !user.hasFeature('pos.cashier'))) {
      return const Scaffold(
        body: EmptyState(
          icon: LucideIcons.ban,
          title: 'Layar kasir tidak tersedia',
          description: 'Akun ini tidak punya izin berjualan, atau fitur kasir dimatikan di pengaturan toko.',
        ),
      );
    }

    final shift = ref.watch(currentShiftProvider);

    return Scaffold(
      body: SafeArea(
        child: switch (shift) {
          AsyncData(value: null) => const OpenShiftCard(),
          AsyncData() => const _Cashier(),
          AsyncError(:final error) => ShiftLoadError(error: error),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _Cashier extends ConsumerStatefulWidget {
  const _Cashier();

  @override
  ConsumerState<_Cashier> createState() => _CashierState();
}

class _CashierState extends ConsumerState<_Cashier> {
  static bool _syncedRestoredCart = false;

  final _scanBuffer = StringBuffer();
  DateTime _lastKey = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    if (!_syncedRestoredCart) {
      _syncedRestoredCart = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncRestoredCart());
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    super.dispose();
  }

  Future<void> _syncRestoredCart() async {
    try {
      final notices = await ref.read(cartProvider.notifier).syncWithServer();
      if (notices.isNotEmpty && mounted) {
        showMessage(context, notices.join('\n'));
      }
    } on ApiException {
      // Checkout re-validates prices and stock anyway; a failed refresh here is not worth a warning.
    }
  }

  /// USB/Bluetooth scanners type the code fast and end with Enter. Only listened to when no text
  /// field has focus, so typing in the search box still works normally.
  bool _onHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent || !mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) {
      return false;
    }

    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused != null && focused.findAncestorWidgetOfExactType<EditableText>() != null) {
      return false;
    }

    final now = DateTime.now();
    if (now.difference(_lastKey) > const Duration(milliseconds: 100)) {
      _scanBuffer.clear();
    }
    _lastKey = now;

    if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final code = _scanBuffer.toString();
      _scanBuffer.clear();
      if (code.length >= 3) {
        addByCode(context, ref, code);
        return true;
      }
      return false;
    }

    final character = event.character;
    if (character != null && character.length == 1 && character.codeUnitAt(0) >= 32) {
      _scanBuffer.write(character);
    }

    return false;
  }

  void _openCart() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Keranjang')),
          body: const SafeArea(child: CartPanel()),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(posConfigProvider);

    if (config.hasError && !config.hasValue) {
      return ErrorState(error: config.error!, onRetry: () => ref.invalidate(posConfigProvider));
    }

    if (context.isWide) {
      return Row(
        children: [
          const Expanded(child: CatalogPanel()),
          const VerticalDivider(width: 1),
          SizedBox(width: context.screenWidth >= 1200 ? 420 : 360, child: const CartPanel()),
        ],
      );
    }

    return Column(
      children: [
        const Expanded(child: CatalogPanel()),
        _CartBar(onOpen: _openCart),
      ],
    );
  }
}

class _CartBar extends ConsumerWidget {
  const _CartBar({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final taxRate = ref.watch(posConfigProvider).value?.taxRate ?? 0;

    if (cart.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), padding: const EdgeInsets.symmetric(horizontal: 16)),
        onPressed: onOpen,
        child: Row(
          children: [
            const Icon(LucideIcons.shoppingCart, size: 20),
            const SizedBox(width: 10),
            Text('${quantity(cart.itemCount)} barang'),
            const Spacer(),
            Text(rupiah(cart.totals(taxRate).total), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 4),
            const Icon(LucideIcons.chevronRight, size: 20),
          ],
        ),
      ),
    );
  }
}
