import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../data/pos_models.dart';
import '../../data/pos_repository.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';
import '../../../../core/utils/display_service.dart';
import '../../pos_providers.dart';

final qrisProvider = FutureProvider.autoDispose.family<QrisPayment, int>(
  (ref, amount) => ref.watch(posRepositoryProvider).qris(amount),
);

class QrisPaymentView extends ConsumerStatefulWidget {
  const QrisPaymentView({super.key, required this.amount});

  final int amount;

  @override
  ConsumerState<QrisPaymentView> createState() => _QrisPaymentViewState();
}

class _QrisPaymentViewState extends ConsumerState<QrisPaymentView> with WidgetsBindingObserver {
  DisplayService? _displayService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _applyBrightness() {
    final qrFullBrightness = ref.read(posDisplaySettingsProvider).qrFullBrightness;
    if (qrFullBrightness) {
      _displayService?.setMaxBrightness();
    } else {
      _displayService?.resetBrightness();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _displayService = ref.read(displayServiceProvider);
    _applyBrightness();
  }

  @override
  void didUpdateWidget(covariant QrisPaymentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amount != widget.amount) {
      _applyBrightness();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _applyBrightness();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _displayService?.resetBrightness();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _displayService?.resetBrightness();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PosDisplaySettings>(posDisplaySettingsProvider, (prev, next) {
      if (prev?.qrFullBrightness != next.qrFullBrightness) {
        _applyBrightness();
      }
    });

    ref.listen<AsyncValue<QrisPayment>>(qrisProvider(widget.amount), (prev, next) {
      if (next.hasError) {
        _displayService?.resetBrightness();
      } else if (next.hasValue) {
        _applyBrightness();
      }
    });

    final qris = ref.watch(qrisProvider(widget.amount));

    return Center(
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.r20),
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
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s10),
                  color: AppColors.slate50,
                  child: Row(
                    children: [
                      // QRIS styled logo representation
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s3),
                        decoration: BoxDecoration(
                          color: AppColors.rose600,
                          borderRadius: BorderRadius.circular(AppRadius.r4),
                        ),
                        child: const Text(
                          PosStrings.qrisBrand,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSizes.s8),
                      const Expanded(
                        child: Text(
                          PosStrings.qrisNationalStandard,
                          style: TextStyle(
                            color: AppColors.slate600,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(AppIcons.shieldCheck, size: AppSizes.s16, color: AppColors.emerald600),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.slate200),

                // Merchant Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s16, AppSpacing.s8),
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
                      const SizedBox(height: AppSizes.s2),
                      const Text(
                        PosStrings.qrisScanInstruction,
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
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s20, vertical: AppSpacing.s6),
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.r14),
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
                  padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s6, AppSpacing.s16, AppSpacing.s14),
                  child: Column(
                    children: [
                      const Text(
                        PosStrings.qrisTotalLabel,
                        style: TextStyle(
                          color: AppColors.slate500,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: AppSizes.s2),
                      Text(
                        rupiah(value.amount),
                        style: AppTypography.money(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.slate900,
                        ),
                      ),
                      const SizedBox(height: AppSizes.s8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s4),
                        decoration: BoxDecoration(
                          color: AppColors.emerald500.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.r20),
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
                            SizedBox(width: AppSizes.s6),
                            Flexible(
                              child: Text(
                                PosStrings.qrisWaitingPayment,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.emerald700,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
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
              padding: const EdgeInsets.all(AppSpacing.s24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(AppIcons.alertCircle, color: AppColors.rose600, size: AppSizes.s36),
                  const SizedBox(height: AppSizes.s8),
                  Text(
                    error.toString(),
                    style: const TextStyle(color: AppColors.rose600, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSizes.s12),
                  OutlinedButton.icon(
                    onPressed: () => ref.invalidate(qrisProvider(widget.amount)),
                    icon: const Icon(AppIcons.refreshCw, size: AppSizes.s16),
                    label: const Text(PosStrings.retry),
                  ),
                ],
              ),
            ),
          _ => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.s20),
              child: AppShimmer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SkeletonBox(width: 224, height: 224, borderRadius: 14),
                    SizedBox(height: AppSizes.s20),
                    SkeletonBox(width: 140, height: 12, borderRadius: 4),
                    SizedBox(height: AppSizes.s8),
                    SkeletonBox(width: 180, height: 24, borderRadius: 6),
                    SizedBox(height: AppSizes.s12),
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
