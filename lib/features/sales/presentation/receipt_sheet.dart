import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/state_views.dart';
import '../data/sale_models.dart';
import '../data/sales_repository.dart';

final receiptProvider = FutureProvider.autoDispose.family<Receipt, int>((ref, saleId) => ref.watch(salesRepositoryProvider).receipt(saleId));

Future<void> openWhatsApp(BuildContext context, String? url) async {
  final uri = url == null ? null : Uri.tryParse(url);
  final opened = uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);

  if (!opened && context.mounted) {
    showMessage(context, 'WhatsApp tidak bisa dibuka di perangkat ini.', isError: true);
  }
}

class ReceiptSheet extends ConsumerWidget {
  const ReceiptSheet({super.key, required this.saleId});

  final int saleId;

  static Future<void> show(BuildContext context, int saleId) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => FractionallySizedBox(heightFactor: 0.9, child: ReceiptSheet(saleId: saleId)),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receipt = ref.watch(receiptProvider(saleId));

    return AsyncView(
      value: receipt,
      onRetry: () => ref.invalidate(receiptProvider(saleId)),
      data: (receipt) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Container(
                  width: receipt.paperWidth == '80' ? 380 : 300,
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Text(
                    receipt.text,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.slate900, height: 1.35),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => SharePlus.instance.share(ShareParams(text: receipt.text, subject: 'Struk ${receipt.number}')),
                    icon: const Icon(LucideIcons.share2, size: 18),
                    label: const Text('Bagikan'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => openWhatsApp(context, receipt.whatsappUrl),
                    icon: const Icon(LucideIcons.messageCircle, size: 18),
                    label: const Text('Kirim WhatsApp'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
