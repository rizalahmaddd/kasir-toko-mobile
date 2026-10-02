import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/money_field.dart';
import '../../auth/auth_controller.dart';
import '../../offline/catalog_snapshot.dart';
import '../../offline/offline_queue.dart';
import '../../sales/data/sale_models.dart';
import '../../shift/shift_controller.dart';
import '../cart_controller.dart';
import '../data/pos_models.dart';
import '../data/pos_repository.dart';
import '../pos_providers.dart';
import 'widgets/payment_amount_panel.dart';
import 'widgets/qris_view.dart';

const _methodIcons = {
  'cash': LucideIcons.banknote,
  'qris': LucideIcons.qrCode,
  'transfer': LucideIcons.landmark,
  'card': LucideIcons.creditCard,
};

/// Rejections where the server already told us what changed; the cart is fixed up and the
/// cashier reviews it before paying again.
const _cartRejections = {'unavailable', 'price_changed', 'insufficient_stock'};

class PaymentSheet extends ConsumerStatefulWidget {
  const PaymentSheet({super.key});

  /// Resolves to a [SaleDetail] when the server recorded the sale, or a [QueuedSale] when it was kept offline.
  static Future<Object?> show(BuildContext context) => showModalBottomSheet<Object>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: false,
        builder: (_) => const PaymentSheet(),
      );

  @override
  ConsumerState<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<PaymentSheet> {
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final List<PaymentLine> _lines = [];
  late String _method;
  bool _busy = false;
  bool _showCustomNominal = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final methods = ref.read(posConfigProvider).requireValue.paymentMethods;
    _method = methods.isEmpty ? 'cash' : methods.first.value;
    _resetEntry();
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  PosConfig get _config => ref.read(posConfigProvider).requireValue;

  int get _total => ref.read(cartProvider).totals(_config.taxRate).total;

  int get _committed => _lines.fold(0, (sum, line) => sum + line.amount);

  int get _remaining => (_total - _committed).clamp(0, _total);

  int get _entered => parseRupiah(_amount.text);

  bool get _isCash => _method == 'cash';

  /// Non-cash defaults to the exact remaining amount; cash starts empty so the cashier types what was handed over.
  void _resetEntry() {
    _reference.clear();
    _amount.text = _isCash || _remaining == 0 ? '' : thousands(_remaining);
  }

  void _selectMethod(String method) {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _method = method;
      _showCustomNominal = false;
      _error = null;
      _resetEntry();
    });
  }

  List<int> _quickCashOptions(int remaining, List<int> configPresets) {
    if (remaining <= 0) return const [];
    final set = <int>{};

    // Round up to nearest 10k
    final r10k = ((remaining + 9999) ~/ 10000) * 10000;
    if (r10k > remaining) set.add(r10k);

    // Round up to nearest 20k
    final r20k = ((remaining + 19999) ~/ 20000) * 20000;
    if (r20k > remaining) set.add(r20k);

    // Round up to nearest 50k
    final r50k = ((remaining + 49999) ~/ 50000) * 50000;
    if (r50k > remaining) set.add(r50k);

    // Round up to nearest 100k
    final r100k = ((remaining + 99999) ~/ 100000) * 100000;
    if (r100k > remaining) set.add(r100k);

    // Standard Indonesian notes above remaining
    for (final note in const [20000, 50000, 100000, 200000, 300000, 500000, 1000000]) {
      if (note > remaining) set.add(note);
    }
    for (final p in configPresets) {
      if (p > remaining) set.add(p);
    }

    final list = set.toList()..sort();
    return list.take(4).toList();
  }

  List<PaymentLine> _allPayments() => [
        ..._lines,
        if (_entered > 0) PaymentLine(method: _method, amount: _entered, reference: _reference.text.trim().isEmpty ? null : _reference.text.trim()),
      ];

  void _addSplit() {
    if (_entered <= 0) {
      setState(() => _error = 'Isi nominal dulu.');
      return;
    }
    if (_entered >= _remaining) {
      setState(() => _error = 'Nominal ini sudah melunasi tagihan. Tekan Selesaikan Pembayaran.');
      return;
    }
    setState(() {
      _lines.add(_allPayments().last);
      _error = null;
      _resetEntry();
    });
  }

  Future<void> _submit() async {
    final cart = ref.read(cartProvider);
    final payments = _allPayments();
    final paid = payments.fold(0, (sum, payment) => sum + payment.amount);
    final nonCash = payments.where((payment) => payment.method != 'cash').fold(0, (sum, payment) => sum + payment.amount);
    final shortfall = _total - paid;

    if (nonCash > _total) {
      setState(() => _error = 'Pembayaran non-tunai melebihi total. Non-tunai tidak punya kembalian.');
      return;
    }

    if (shortfall > 0) {
      if (!_config.allowCredit) {
        setState(() => _error = 'Pembayaran kurang ${rupiah(shortfall)}.');
        return;
      }
      if (cart.customer == null) {
        setState(() => _error = 'Pembayaran kurang ${rupiah(shortfall)}. Pilih pelanggan dulu kalau sisanya dicatat sebagai kasbon.');
        return;
      }
      final confirmed = await _confirmCredit(cart.customer!.name, shortfall);
      if (!confirmed) {
        return;
      }
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final sale = await ref.read(posRepositoryProvider).checkout(cart: cart, payments: payments, expectedTotal: _total);
      ref.read(cartProvider.notifier).clear();
      ref
        ..invalidate(catalogProvider)
        ..invalidate(posConfigProvider)
        ..invalidate(currentShiftProvider);
      if (mounted) {
        Navigator.pop(context, sale);
      }
    } on ApiException catch (error) {
      if (error.isNetworkError) {
        _queueOffline(cart, payments, paid);
      } else {
        _handleRejection(error);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  /// The server couldn't be reached; keep the sale (same client_uuid) and let the syncer send it later.
  void _queueOffline(Cart cart, List<PaymentLine> payments, int paid) {
    final user = ref.read(currentUserProvider);
    if (user == null || !mounted) {
      return;
    }

    final totals = cart.totals(_config.taxRate);
    final labels = {for (final method in _config.paymentMethods) method.value: method.label};
    final cash = payments.where((p) => p.method == 'cash').fold(0, (sum, p) => sum + p.amount);
    final change = paid > totals.total ? paid - totals.total : 0;
    final now = DateTime.now();
    final sale = QueuedSale(
      payload: PosRepository.checkoutPayload(cart: cart, payments: payments, expectedTotal: totals.total),
      cart: cart.toJson(total: totals.total),
      userId: user.id,
      total: totals.total,
      paid: paid,
      itemCount: cart.itemCount,
      createdAt: now,
      customerName: cart.customer?.name,
      preview: {
        'id': 0,
        'number': 'OFFLINE-${cart.clientUuid.substring(0, 8).toUpperCase()}',
        'status': 'completed',
        'status_label': 'Menunggu sinkron',
        'sold_at': now.toIso8601String(),
        'cashier': {'id': user.id, 'name': user.name},
        'customer': cart.customer == null ? null : {'id': cart.customer!.id, 'name': cart.customer!.name},
        'subtotal': totals.subtotal,
        'discount_type': cart.discountType?.name,
        'discount_value': cart.discountValue,
        'discount_amount': totals.discountAmount,
        'tax_rate': _config.taxRate,
        'tax_amount': totals.taxAmount,
        'total': totals.total,
        'paid_amount': paid.clamp(0, totals.total),
        'cash_received': cash,
        'change_amount': change,
        'due_amount': (totals.total - paid).clamp(0, totals.total),
        'items': [
          for (final item in cart.items)
            {
              'product_name': item.name,
              'unit': item.unit,
              'quantity': item.quantity,
              'price': item.price,
              'discount_amount': item.appliedDiscount,
              'total': item.total,
              'note': item.note,
            },
        ],
        'payments': [
          for (final p in payments)
            {'kind': 'sale', 'method': p.method, 'method_label': labels[p.method] ?? p.method, 'amount': p.amount, 'paid_at': now.toIso8601String()},
        ],
      },
    );

    ref.read(offlineQueueProvider.notifier).add(sale);
    ref.read(catalogSnapshotProvider.notifier).deduct({for (final item in cart.items) item.productId: item.quantity});
    ref.read(cartProvider.notifier).clear();
    ref.invalidate(catalogProvider);
    Navigator.pop(context, sale);
  }

  void _handleRejection(ApiException error) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);

    if (_cartRejections.contains(error.reason)) {
      ref.read(cartProvider.notifier).applyRejection(error);
      ref.invalidate(catalogProvider);
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }

    switch (error.reason) {
      case 'no_shift':
        ref
          ..invalidate(currentShiftProvider)
          ..invalidate(posConfigProvider);
        Navigator.pop(context);
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      case 'total_mismatch':
        ref.invalidate(posConfigProvider);
        setState(() => _error = 'Pengaturan pajak baru saja berubah. Periksa total lalu bayar lagi.');
      default:
        setState(
          () => _error = error.isNetworkError
              ? '${error.message} Tekan bayar lagi, transaksi tidak akan tercatat dua kali.'
              : error.message,
        );
    }
  }

  Future<bool> _confirmCredit(String customer, int amount) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Catat sebagai kasbon?'),
        content: Text('Sisa ${rupiah(amount)} dicatat sebagai kasbon atas nama $customer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Catat Kasbon')),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(posConfigProvider).requireValue;
    final colors = StatusColors.of(context);
    final total = _total;
    final remaining = _remaining;
    final change = _isCash ? _entered - remaining : 0;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BottomSheetHeader(
                title: 'Pembayaran',
                onClose: _busy ? null : () => Navigator.pop(context),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PaymentAmountPanel(total: total, remaining: _lines.isEmpty ? null : remaining),
                      if (_lines.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        for (final (index, line) in _lines.indexed)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(_methodIcons[line.method] ?? LucideIcons.wallet, size: 18),
                            title: Text(config.paymentMethods.where((m) => m.value == line.method).firstOrNull?.label ?? line.method),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(rupiah(line.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
                                IconButton(
                                  tooltip: 'Hapus pembayaran ini',
                                  icon: const Icon(LucideIcons.x, size: 16),
                                  onPressed: () => setState(() {
                                    _lines.removeAt(index);
                                    _resetEntry();
                                  }),
                                ),
                              ],
                            ),
                          ),
                      ],
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final method in config.paymentMethods)
                            ChoiceChip(
                              avatar: Icon(_methodIcons[method.value] ?? LucideIcons.wallet, size: 16),
                              label: Text(method.label),
                              selected: _method == method.value,
                              showCheckmark: false,
                              onSelected: (_) => _selectMethod(method.value),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_method == 'qris' && remaining > 0) ...[
                        if (config.qrisEnabled) ...[
                          QrisPaymentView(amount: _entered > 0 ? _entered : remaining),
                          const SizedBox(height: 8),
                          Center(
                            child: TextButton.icon(
                              onPressed: () {
                                unawaited(HapticFeedback.lightImpact());
                                setState(() => _showCustomNominal = !_showCustomNominal);
                              },
                              icon: Icon(_showCustomNominal ? LucideIcons.chevronUp : LucideIcons.slidersHorizontal, size: 15),
                              label: Text(
                                _showCustomNominal ? 'Sembunyikan Pengaturan Nominal' : 'Ubah Nominal / Split QRIS',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colors.warning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: colors.warning.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(LucideIcons.alertTriangle, size: 20, color: colors.warning),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'QRIS toko belum diatur di Pengaturan Kasir web. Minta pelanggan scan QRIS cetak lalu isi nominal.',
                                    style: TextStyle(color: colors.warning, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                      if (_isCash || _method != 'qris' || _showCustomNominal || !config.qrisEnabled) ...[
                        MoneyField(
                          controller: _amount,
                          label: _isCash ? 'Uang diterima' : 'Nominal',
                          autofocus: _isCash && context.isMedium,
                          onChanged: (_) => setState(() => _error = null),
                          onSubmitted: (_) => _submit(),
                        ),
                      ],
                      if (_isCash) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ActionChip(
                              label: const Text('Uang pas'),
                              onPressed: () {
                                unawaited(HapticFeedback.selectionClick());
                                setState(() => _amount.text = thousands(remaining));
                              },
                            ),
                            for (final value in _quickCashOptions(remaining, config.quickCash))
                              ActionChip(
                                label: Text(rupiah(value)),
                                onPressed: () {
                                  unawaited(HapticFeedback.selectionClick());
                                  setState(() => _amount.text = thousands(value));
                                },
                              ),
                          ],
                        ),
                        if (_entered > 0) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: (change >= 0 ? colors.success : colors.warning).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: (change >= 0 ? colors.success : colors.warning).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  change >= 0 ? 'Kembalian' : 'Kurang',
                                  style: TextStyle(
                                    color: change >= 0 ? colors.success : colors.warning,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  rupiah(change.abs()),
                                  style: AppTypography.money(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: change >= 0 ? colors.success : colors.warning,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ] else if (_method == 'transfer' || _method == 'card') ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _reference,
                          maxLength: 100,
                          decoration: const InputDecoration(labelText: 'No. referensi (opsional)', hintText: 'mis. 4 digit akhir kartu'),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!, style: TextStyle(color: colors.danger)),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(_method == 'qris' ? 'Pembayaran QRIS Diterima' : 'Selesaikan Pembayaran'),
                      ),
                      if (config.paymentMethods.length > 1) ...[
                        const SizedBox(height: 4),
                        TextButton.icon(
                          onPressed: _busy ? null : _addSplit,
                          icon: const Icon(LucideIcons.plus, size: 16),
                          label: const Text('Bayar sebagian, sisanya metode lain'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
