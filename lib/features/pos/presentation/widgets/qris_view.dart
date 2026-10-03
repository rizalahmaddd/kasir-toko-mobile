import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../data/pos_models.dart';
import '../../data/pos_repository.dart';

final qrisProvider = FutureProvider.autoDispose.family<QrisPayment, int>(
  (ref, amount) => ref.watch(posRepositoryProvider).qris(amount),
);

class QrisPaymentView extends ConsumerWidget {
  const QrisPaymentView({super.key, required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qris = ref.watch(qrisProvider(amount));

    return Center(
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.slate200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: switch (qris) {
          AsyncData(:final value) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top official QRIS badge bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: const Color(0xFFF8FAFC),
                  child: Row(
                    children: [
                      // QRIS styled logo representation
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'QRIS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Standar Pembayaran Nasional',
                          style: TextStyle(
                            color: AppColors.slate600,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(LucideIcons.shieldCheck, size: 16, color: AppColors.emerald600),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.slate200),

                // Merchant Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    children: [
                      if (value.merchantName != null && value.merchantName!.isNotEmpty)
                        Text(
                          value.merchantName!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.slate900,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            letterSpacing: -0.2,
                          ),
                        ),
                      const SizedBox(height: 2),
                      const Text(
                        'Scan QR ini dengan GoPay, OVO, Dana, BCA, atau m-Banking',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.slate500,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),

                // QR Code with subtle frame
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.slate200, width: 1.5),
                    ),
                    child: QrImageView(
                      data: value.payload,
                      size: 200,
                      backgroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),

                // Amount Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                  child: Column(
                    children: [
                      const Text(
                        'TOTAL PEMBAYARAN',
                        style: TextStyle(
                          color: AppColors.slate500,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        rupiah(value.amount),
                        style: AppTypography.money(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.slate900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.emerald500.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.emerald500.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 8,
                              height: 8,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppColors.emerald600,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Menunggu pembayaran pembeli',
                              style: TextStyle(
                                color: AppColors.emerald700,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          AsyncError(:final error) => Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.alertCircle, color: AppColors.rose600, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    style: const TextStyle(color: AppColors.rose600, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => ref.invalidate(qrisProvider(amount)),
                    icon: const Icon(LucideIcons.refreshCw, size: 16),
                    label: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
          _ => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: AppShimmer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SkeletonBox(width: 224, height: 224, borderRadius: 14),
                    SizedBox(height: 20),
                    SkeletonBox(width: 140, height: 12, borderRadius: 4),
                    SizedBox(height: 8),
                    SkeletonBox(width: 180, height: 24, borderRadius: 6),
                    SizedBox(height: 12),
                    SkeletonBox(width: 160, height: 24, borderRadius: 12),
                  ],
                ),
              ),
            ),
        },
      ),
    );
  }
}
