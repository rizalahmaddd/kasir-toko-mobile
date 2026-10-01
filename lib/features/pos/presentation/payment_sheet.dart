import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/money_field.dart';
import '../../sales/data/sale_models.dart';
import '../../shift/shift_controller.dart';
import '../cart_controller.dart';
import '../data/pos_models.dart';
import '../data/pos_repository.dart';
import '../pos_providers.dart';

final _qrisProvider = FutureProvider.autoDispose.family<QrisPayment, int>((ref, amount) => ref.watch(posRepositoryProvider).qris(amount));

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

  static Future<SaleDetail?> show(BuildContext context) => showModalBottomSheet<SaleDetail>(
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
    setState(() {
      _method = method;
      _error = null;
      _resetEntry();
    });
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
      _handleRejection(error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
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
    final theme = Theme.of(context);
    final colors = StatusColors.of(context);
    final total = _total;
    final remaining = _remaining;
    final change = _isCash ? _entered - remaining : 0;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Pembayaran', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
                    IconButton(tooltip: 'Tutup', icon: const Icon(LucideIcons.x), onPressed: _busy ? null : () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 8),
                _AmountPanel(total: total, remaining: _lines.isEmpty ? null : remaining),
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
                const SizedBox(height: 16),
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
                  if (config.qrisEnabled)
                    _QrisView(amount: _entered > 0 ? _entered : remaining)
                  else
                    Text(
                      'QRIS toko belum diatur di Pengaturan Kasir web. Minta pelanggan scan QRIS cetak lalu isi nominal di bawah.',
                      style: TextStyle(color: colors.warning),
                    ),
                  const SizedBox(height: 12),
                ],
                MoneyField(
                  controller: _amount,
                  label: _isCash ? 'Uang diterima' : 'Nominal',
                  autofocus: _isCash,
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) => _submit(),
                ),
                if (_isCash) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(label: const Text('Uang pas'), onPressed: () => setState(() => _amount.text = thousands(remaining))),
                      for (final value in config.quickCash.where((value) => value >= remaining))
                        ActionChip(label: Text(rupiah(value)), onPressed: () => setState(() => _amount.text = thousands(value))),
                    ],
                  ),
                  if (_entered > 0) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(change >= 0 ? 'Kembalian' : 'Kurang', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                        const Spacer(),
                        Text(
                          rupiah(change.abs()),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: change >= 0 ? colors.success : colors.warning,
                          ),
                        ),
                      ],
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
      ),
    );
  }
}

class _AmountPanel extends StatelessWidget {
  const _AmountPanel({required this.total, this.remaining});

  final int total;
  final int? remaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(colors: [AppColors.slate900, AppColors.slate800]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(remaining == null ? 'Total tagihan' : 'Sisa tagihan', style: const TextStyle(color: AppColors.slate400)),
          const SizedBox(height: 4),
          Text(
            rupiah(remaining ?? total),
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700),
          ),
          if (remaining != null) Text('dari ${rupiah(total)}', style: const TextStyle(color: AppColors.slate400)),
        ],
      ),
    );
  }
}

class _QrisView extends ConsumerWidget {
  const _QrisView({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qris = ref.watch(_qrisProvider(amount));

    return Center(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: switch (qris) {
          AsyncData(:final value) => Column(
              children: [
                QrImageView(data: value.payload, size: 220, backgroundColor: Colors.white),
                if (value.merchantName != null)
                  Text(value.merchantName!, style: const TextStyle(color: AppColors.slate900, fontWeight: FontWeight.w600)),
                Text(rupiah(value.amount), style: const TextStyle(color: AppColors.slate900)),
              ],
            ),
          AsyncError(:final error) => SizedBox(
              width: 220,
              child: Text(error.toString(), style: const TextStyle(color: AppColors.rose600), textAlign: TextAlign.center),
            ),
          _ => const SizedBox.square(dimension: 220, child: Center(child: CircularProgressIndicator())),
        },
      ),
    );
  }
}
