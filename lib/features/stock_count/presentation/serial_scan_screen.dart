import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/auth_controller.dart';
import '../../pos/presentation/widgets/barcode_scanner_view.dart';
import '../../outlets/outlet_controller.dart';
import '../count_queue.dart';
import '../data/stock_count_models.dart';
import '../stock_count_providers.dart';

/// Scan setiap unit barang bernomor seri. Scan masuk antrean dulu (bisa offline), hasil cocoknya
/// tampil setelah terkirim.
class SerialScanScreen extends ConsumerStatefulWidget {
  const SerialScanScreen({super.key, required this.countId, required this.item});

  final int countId;
  final CountCatalogItem item;

  static Future<void> open(BuildContext context, {required int countId, required CountCatalogItem item}) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SerialScanScreen(countId: countId, item: item)));

  @override
  ConsumerState<SerialScanScreen> createState() => _SerialScanScreenState();
}

class _SerialScanScreenState extends ConsumerState<SerialScanScreen> {
  final _input = TextEditingController();
  final _scanned = <QueuedCount>[];
  bool _camera = true;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _record(String code) {
    final serial = code.trim().toUpperCase();
    final user = ref.read(currentUserProvider);
    if (serial.isEmpty || user == null) {
      return;
    }
    if (_scanned.any((item) => item.payload['serial'] == serial)) {
      unawaited(HapticFeedback.heavyImpact());
      return;
    }
    final queued = serialScan(
      countId: widget.countId,
      userId: user.id,
      serial: serial,
      productId: widget.item.productId,
      productName: widget.item.name,
      outletId: ref.read(currentOutletIdProvider),
    );
    ref.read(countQueueProvider.notifier).add(queued);
    unawaited(HapticFeedback.mediumImpact());
    unawaited(SystemSound.play(SystemSoundType.click));
    setState(() => _scanned.insert(0, queued));
    _input.clear();
    unawaited(ref.read(countQueueProvider.notifier).sync());
  }

  void _undo(QueuedCount item) {
    if (ref.read(countQueueProvider.notifier).removePending(item.clientUuid)) {
      setState(() => _scanned.remove(item));
    } else {
      showMessage(context, StockCountStrings.waitQueue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(countQueueProvider);
    final pendingIds = queue.pending.map((item) => item.clientUuid).toSet();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item.name),
        actions: [
          IconButton(
            tooltip: _camera ? StockCountStrings.cameraOff : StockCountStrings.cameraOn,
            onPressed: () => setState(() => _camera = !_camera),
            icon: Icon(_camera ? AppIcons.camera : AppIcons.keyboard),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_camera)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s8, AppSpacing.s16, AppSpacing.s4),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.r16),
                  border: Border.all(color: isDark ? AppColors.slate700 : AppColors.slate300, width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.r14),
                  child: SizedBox(
                    height: 220,
                    child: BarcodeScannerView(continuous: true, hintText: StockCountStrings.serialInput, onDetect: _record),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(StockCountStrings.serialHint, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: AppSizes.s8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        autofocus: !_camera,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: StockCountStrings.serialInput,
                          prefixIcon: Icon(AppIcons.barcode, size: AppSizes.s18),
                          isDense: true,
                        ),
                        onSubmitted: _record,
                      ),
                    ),
                    const SizedBox(width: AppSizes.s8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s14),
                      ),
                      onPressed: () => _record(_input.text),
                      child: const Icon(AppIcons.plus, size: AppSizes.s18),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.s10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.r6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(AppIcons.boxes, size: AppSizes.s14, color: theme.colorScheme.primary),
                          const SizedBox(width: AppSizes.s4),
                          Text(
                            StockCountStrings.serialCount(_scanned.length),
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _scanned.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.s24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(AppIcons.barcode, size: AppSizes.s48, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                          const SizedBox(height: AppSizes.s12),
                          Text(
                            StockCountStrings.noSerials,
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _scanned.length,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
                    itemBuilder: (context, index) {
                      final item = _scanned[index];
                      final result = queue.serialResults[item.clientUuid];
                      final waiting = pendingIds.contains(item.clientUuid);

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s4),
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s10),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.slate800 : Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.r8),
                          border: Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.s6),
                              decoration: BoxDecoration(
                                color: (waiting ? AppColors.amber500 : AppColors.emerald500).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppRadius.r6),
                              ),
                              child: Icon(
                                waiting ? AppIcons.cloudUpload : AppIcons.check,
                                size: AppSizes.s14,
                                color: waiting ? AppColors.amber500 : AppColors.emerald500,
                              ),
                            ),
                            const SizedBox(width: AppSizes.s10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${item.payload['serial']}',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, fontFamily: 'monospace'),
                                  ),
                                  const SizedBox(height: AppSizes.s2),
                                  Text(
                                    waiting ? StockCountStrings.serialQueued : StockCountStrings.serialResults[result] ?? '',
                                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            if (waiting)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: StockCountStrings.minusOne,
                                icon: const Icon(AppIcons.minus, size: AppSizes.s16),
                                onPressed: () => _undo(item),
                              )
                            else
                              StatusBadge(
                                label: (StockCountStrings.serialResults[result] ?? '').toUpperCase(),
                                tone: result == 'matched' ? BadgeTone.success : BadgeTone.warning,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
