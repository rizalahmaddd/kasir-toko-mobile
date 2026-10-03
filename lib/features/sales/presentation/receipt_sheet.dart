import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/offline/cached_notifier.dart';
import '../../../core/widgets/state_views.dart';
import '../../printing/presentation/printer_screen.dart';
import '../../printing/printer.dart';
import '../data/sale_models.dart';
import '../data/sales_repository.dart';

final receiptProvider = AsyncNotifierProvider.autoDispose.family<ReceiptNotifier, Receipt, int>(ReceiptNotifier.new);

class ReceiptNotifier extends CachedFamilyNotifier<Receipt, int> {
  ReceiptNotifier(super.arg);

  @override
  Future<Receipt?> loadCache(int id) => ref.read(salesRepositoryProvider).getCachedReceipt(id);

  @override
  Future<Receipt> fetchRemote(int id) => ref.read(salesRepositoryProvider).receipt(id);
}

Future<void> openWhatsApp(BuildContext context, String? url) async {
  final uri = url == null ? null : Uri.tryParse(url);
  final opened = uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);

  if (!opened && context.mounted) {
    showMessage(context, 'WhatsApp tidak bisa dibuka di perangkat ini.', isError: true);
  }
}

/// Custom serrated paper tear edge clipper for realistic POS thermal receipts.
class ReceiptClipper extends CustomClipper<Path> {
  const ReceiptClipper({this.teethSize = 6.0});

  final double teethSize;

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, teethSize);

    // Top serrated edge
    final topTeethCount = (size.width / (teethSize * 2)).floor().clamp(1, 100);
    final topStep = size.width / topTeethCount;
    for (int i = 0; i < topTeethCount; i++) {
      path.lineTo(i * topStep + topStep / 2, 0);
      path.lineTo((i + 1) * topStep, teethSize);
    }

    // Right side
    path.lineTo(size.width, size.height - teethSize);

    // Bottom serrated edge
    final bottomTeethCount = (size.width / (teethSize * 2)).floor().clamp(1, 100);
    final bottomStep = size.width / bottomTeethCount;
    for (int i = bottomTeethCount; i > 0; i--) {
      path.lineTo(i * bottomStep - bottomStep / 2, size.height);
      path.lineTo((i - 1) * bottomStep, size.height - teethSize);
    }

    // Left side
    path.lineTo(0, teethSize);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class ReceiptSheet extends ConsumerWidget {
  const ReceiptSheet({super.key, required this.saleId});

  final int saleId;

  static Future<void> show(BuildContext context, int saleId) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
          child: ReceiptSheet(saleId: saleId),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receipt = ref.watch(receiptProvider(saleId));
    final printerConfigured = ref.watch(printerSettingsProvider).isConfigured;

    return AsyncView(
      value: receipt,
      onRetry: () => ref.invalidate(receiptProvider(saleId)),
      data: (receipt) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BottomSheetHeader(
            title: 'Struk Pembelian',
            subtitle: receipt.number,
            actions: [
              IconButton(
                tooltip: 'Salin Teks',
                icon: const Icon(LucideIcons.copy, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: receipt.text));
                  showMessage(context, 'Teks struk berhasil disalin');
                },
              ),
            ],
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Center(
                child: PhysicalShape(
                  clipper: const ReceiptClipper(teethSize: 6),
                  color: Colors.white,
                  elevation: 5,
                  shadowColor: Colors.black.withValues(alpha: 0.15),
                  child: Container(
                    width: receipt.paperWidth == '80' ? 380 : 310,
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.receipt, size: 15, color: AppColors.slate500),
                            SizedBox(width: 6),
                            Text(
                              'BUKTI PEMBAYARAN',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: AppColors.slate500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _FormattedReceiptView(text: receipt.text),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                if (printerConfigured) ...[
                  IconButton.filledTonal(
                    tooltip: 'Cetak Struk',
                    icon: const Icon(LucideIcons.printer, size: 18),
                    onPressed: () => runPrint(
                      context,
                      () => ref.read(printerServiceProvider).printSale(saleId),
                      success: 'Struk dicetak.',
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
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
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => openWhatsApp(context, receipt.whatsappUrl),
                    icon: const Icon(LucideIcons.messageCircle, size: 18),
                    label: const Text('WhatsApp'),
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

class _ReceiptDivider extends StatelessWidget {
  const _ReceiptDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 280.0;
        const dashWidth = 4.0;
        const dashSpace = 3.0;
        final dashCount = (boxWidth / (dashWidth + dashSpace)).floor().clamp(5, 100);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(dashCount, (_) {
              return const SizedBox(
                width: dashWidth,
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Color(0xFFCBD5E1)),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class _FormattedReceiptView extends StatelessWidget {
  const _FormattedReceiptView({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final widgets = <Widget>[];

    bool inHeader = true;
    bool summarySeen = false;

    for (int i = 0; i < lines.length; i++) {
      final rawLine = lines[i];
      final line = rawLine.trim();

      if (line.isEmpty) {
        if (widgets.isNotEmpty && widgets.last is! _ReceiptDivider) {
          widgets.add(const _ReceiptDivider());
        }
        inHeader = false;
        continue;
      }

      // 1. Total line: "*Total: Rp...*"
      if (line.startsWith('*') && line.contains('Total:')) {
        summarySeen = true;
        inHeader = false;
        final clean = line.replaceAll('*', '');
        final colonIdx = clean.indexOf(':');
        final label = colonIdx != -1 ? clean.substring(0, colonIdx).trim() : 'TOTAL';
        final amount = colonIdx != -1 ? clean.substring(colonIdx + 1).trim() : clean;

        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontFamilyFallback: ['Menlo', 'Courier'],
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate900,
                  ),
                ),
                Text(
                  amount,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontFamilyFallback: ['Menlo', 'Courier'],
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate900,
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // 2. Header: Transaction number & Date (e.g. "TRX-2026-000103 · 02 Okt 2026 15:14")
      if (line.contains(' · ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              line,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontFamilyFallback: ['Menlo', 'Courier'],
                fontSize: 11,
                color: AppColors.slate600,
              ),
            ),
          ),
        );
        continue;
      }

      // 3. Header: Store Name "*Store Name*"
      if (inHeader && line.startsWith('*') && line.endsWith('*')) {
        final storeName = line.replaceAll('*', '');
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              storeName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontFamilyFallback: ['Menlo', 'Courier'],
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.slate900,
                letterSpacing: 0.3,
              ),
            ),
          ),
        );
        continue;
      }

      // 4. Item calculation row: "  1 x Rp7.000 = Rp7.000"
      if (line.contains(' = ')) {
        inHeader = false;
        final parts = line.split(' = ');
        final formula = parts[0].trim();
        final itemTotal = parts[1].trim();

        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    formula,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontFamilyFallback: ['Menlo', 'Courier'],
                      fontSize: 12,
                      color: AppColors.slate600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  itemTotal,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontFamilyFallback: ['Menlo', 'Courier'],
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate900,
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // 5. Item discount row: "  Diskon -Rp..."
      if (rawLine.startsWith(' ') && (line.startsWith('Diskon') || line.startsWith('Diskon -'))) {
        inHeader = false;
        final discountAmount = line.replaceFirst('Diskon', '').trim();
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Diskon item',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontFamilyFallback: ['Menlo', 'Courier'],
                    fontSize: 11,
                    color: Color(0xFFDC2626),
                  ),
                ),
                Text(
                  discountAmount,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontFamilyFallback: ['Menlo', 'Courier'],
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // 6. Summary lines (Subtotal, Diskon, Pajak, Tunai, Kembali, Sisa kasbon)
      if (line.contains(':') && !inHeader) {
        final colonIdx = line.indexOf(':');
        final label = line.substring(0, colonIdx).trim();
        final value = line.substring(colonIdx + 1).trim();

        if (label.toLowerCase().startsWith('subtotal')) {
          summarySeen = true;
        }

        final isDiscount = label.toLowerCase().contains('diskon');
        final isSubtotal = label.toLowerCase().contains('subtotal');
        final isDue = label.toLowerCase().contains('kasbon') || label.toLowerCase().contains('sisa');

        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontFamilyFallback: const ['Menlo', 'Courier'],
                    fontSize: 12,
                    fontWeight: isSubtotal ? FontWeight.w600 : FontWeight.w500,
                    color: isDiscount ? const Color(0xFFDC2626) : AppColors.slate700,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontFamilyFallback: const ['Menlo', 'Courier'],
                    fontSize: 12,
                    fontWeight: isSubtotal ? FontWeight.w600 : FontWeight.w700,
                    color: isDiscount
                        ? const Color(0xFFDC2626)
                        : isDue
                            ? const Color(0xFFDC2626)
                            : AppColors.slate900,
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // 7. Footer message (after summary is completed)
      if (summarySeen) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text(
              line,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontFamilyFallback: ['Menlo', 'Courier'],
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: AppColors.slate600,
              ),
            ),
          ),
        );
        continue;
      }

      // 8. Item name
      inHeader = false;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: Text(
            line,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontFamilyFallback: ['Menlo', 'Courier'],
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.slate900,
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );
  }
}

