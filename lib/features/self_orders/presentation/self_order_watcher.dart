import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/state_views.dart';
import '../../pos/pos_providers.dart';
import '../data/self_order_models.dart';
import '../data/self_order_repository.dart';

/// Menyegarkan kotak masuk pesanan QR tiap 15 detik selama layar kasir terbuka (sama dengan Layar Dapur;
/// aplikasi tidak memakai websocket), lalu memberi tahu kasir saat ada pesanan baru atau pesanan siap diantar.
class SelfOrderWatcher extends ConsumerStatefulWidget {
  const SelfOrderWatcher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SelfOrderWatcher> createState() => _SelfOrderWatcherState();
}

class _SelfOrderWatcherState extends ConsumerState<SelfOrderWatcher> {
  Timer? _timer;
  Set<int>? _known;
  final _announcedReady = <int>{};

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (ref.read(posConfigProvider).value?.selfOrderEnabled ?? false) {
        ref.invalidate(selfOrdersProvider);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onOrders(List<SelfOrder> orders) {
    final known = _known;
    _known = {for (final order in orders) order.id};

    // Pemuatan pertama hanya mencatat keadaan; kasir tidak dibanjiri notifikasi pesanan lama.
    if (known == null) {
      _announcedReady.addAll(orders.where((order) => order.isReady).map((order) => order.id));
      return;
    }

    final fresh = orders.where((order) => order.isPending && !known.contains(order.id)).toList();
    if (fresh.isNotEmpty && mounted) {
      unawaited(HapticFeedback.mediumImpact());
      showMessage(context, SelfOrderStrings.newOrder(fresh.map((order) => order.label).join(', ')));
    }

    for (final order in orders.where((order) => order.isReady && _announcedReady.add(order.id))) {
      unawaited(_announceReady(order));
    }
  }

  Future<void> _announceReady(SelfOrder order) async {
    if (!mounted) {
      return;
    }
    unawaited(HapticFeedback.heavyImpact());

    final served = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(SelfOrderStrings.readyTitle),
        content: Text(order.isDineIn ? SelfOrderStrings.readyDineIn(order.label, order.customerName) : SelfOrderStrings.readyTakeAway(order.label, order.customerName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(SelfOrderStrings.later)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(order.isDineIn ? SelfOrderStrings.delivered : SelfOrderStrings.pickedUp)),
        ],
      ),
    );
    if (served != true) {
      return;
    }

    try {
      await ref.read(selfOrderRepositoryProvider).served(order.id);
      ref.invalidate(selfOrdersProvider);
    } on ApiException catch (error) {
      if (mounted) {
        showError(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(selfOrdersProvider, (_, next) {
      final orders = next.value;
      if (orders != null && !next.isLoading) {
        _onOrders(orders);
      }
    });

    return widget.child;
  }
}
