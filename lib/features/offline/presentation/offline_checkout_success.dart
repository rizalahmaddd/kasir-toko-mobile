import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../printing/presentation/printer_screen.dart';
import '../../printing/printer.dart';
import '../../sales/data/sale_models.dart';
import '../offline_queue.dart';

class OfflineCheckoutSuccess extends ConsumerStatefulWidget {
  const OfflineCheckoutSuccess({super.key, required this.sale});

  final QueuedSale sale;

  static Future<void> show(BuildContext context, QueuedSale sale) =>
      showDialog<void>(context: context, barrierDismissible: false, builder: (_) => OfflineCheckoutSuccess(sale: sale));

  @override
  ConsumerState<OfflineCheckoutSuccess> createState() => _OfflineCheckoutSuccessState();
}

class _OfflineCheckoutSuccessState extends ConsumerState<OfflineCheckoutSuccess> {
  @override
  void initState() {
    super.initState();
    if (ref.read(printerSettingsProvider).autoPrint) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _print());
    }
  }

  void _print() => runPrint(context, () => ref.read(printerServiceProvider).printDetail(SaleDetail.fromJson(widget.sale.preview)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = StatusColors.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final sale = widget.sale;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(LucideIcons.cloudOff, size: 40, color: colors.warning),
              const SizedBox(height: 12),
              Text('Tersimpan di perangkat', textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'Server tidak terjangkau. Transaksi dikirim otomatis begitu koneksi kembali.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 20),
              if (sale.change > 0) ...[
                Text('Kembalian', textAlign: TextAlign.center, style: TextStyle(color: muted)),
                Text(
                  rupiah(sale.change),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700, color: colors.success),
                ),
              ] else
                Text(rupiah(sale.total), textAlign: TextAlign.center, style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 24),
              if (ref.watch(printerSettingsProvider).isConfigured) ...[
                OutlinedButton.icon(onPressed: _print, icon: const Icon(LucideIcons.printer, size: 18), label: const Text('Cetak Struk')),
                const SizedBox(height: 8),
              ],
              FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Transaksi Baru')),
            ],
          ),
        ),
      ),
    );
  }
}
