import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/auth_controller.dart';
import '../../shift/presentation/open_shift_card.dart';
import '../../shift/shift_controller.dart';
import '../cart_controller.dart';
import '../pos_providers.dart';
import 'cart_panel.dart';
import 'catalog_panel.dart';
import 'pos_actions.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';
import 'package:web_pos_mobile/core/theme/app_durations.dart';

class PosScreen extends ConsumerWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    if (user != null && (!user.can('pos.sell') || !user.hasFeature('pos.cashier'))) {
      return const Scaffold(
        body: EmptyState(
          icon: AppIcons.ban,
          title: PosStrings.posUnavailableTitle,
          description: PosStrings.posUnavailableDescription,
        ),
      );
    }

    final shift = ref.watch(currentShiftProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: switch (shift) {
                AsyncData(value: null) => const OpenShiftCard(),
                AsyncData() => const _Cashier(),
                AsyncError(:final error) => ShiftLoadError(error: error),
                _ => const PosCatalogSkeleton(),
              },
            ),
          ],
        ),
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
    if (now.difference(_lastKey) > AppDurations.milliseconds100) {
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
          appBar: AppBar(title: const Text(PosStrings.cartAppBarTitle)),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final taxRate = ref.watch(posConfigProvider).value?.taxRate ?? 0;
    final total = cart.totals(taxRate).total;

    if (cart.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s12, AppSpacing.s6, AppSpacing.s12, AppSpacing.s12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate950 : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.slate800 : AppColors.slate200,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.r16),
          gradient: LinearGradient(
            colors: isDark
                ? const [AppColors.emerald600, AppColors.emerald700]
                : const [AppColors.emerald500, AppColors.emerald600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.emerald500.withValues(alpha: isDark ? 0.3 : 0.25),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.r16),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.r16),
            onTap: () {
              unawaited(HapticFeedback.lightImpact());
              onOpen();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppRadius.r10),
                    ),
                    child: const Icon(
                      AppIcons.shoppingBag,
                      size: AppSizes.s20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: AppSizes.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          PosStrings.cartItemCount(quantity(cart.itemCount)),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                          ),
                        ),
                        Text(
                          cart.customer != null ? cart.customer!.name : PosStrings.openCartHint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        rupiah(total),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            PosStrings.payLabel,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: AppSizes.s2),
                          Icon(AppIcons.chevronRight, size: AppSizes.s14, color: Colors.white70),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
