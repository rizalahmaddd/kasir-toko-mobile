import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_strings.dart';
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
            SizedBox(
              height: 220,
              child: BarcodeScannerView(continuous: true, hintText: StockCountStrings.serialInput, onDetect: _record),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(StockCountStrings.serialHint, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: AppSizes.s8),
                TextField(
                  controller: _input,
                  autofocus: !_camera,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: StockCountStrings.serialInput,
                    suffixIcon: IconButton(icon: const Icon(AppIcons.plus), onPressed: () => _record(_input.text)),
                  ),
                  onSubmitted: _record,
                ),
                const SizedBox(height: AppSizes.s8),
                Text(StockCountStrings.serialCount(_scanned.length), style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _scanned.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _scanned[index];
                final result = queue.serialResults[item.clientUuid];
                final waiting = pendingIds.contains(item.clientUuid);

                return ListTile(
                  title: Text('${item.payload['serial']}'),
                  subtitle: Text(waiting ? StockCountStrings.serialQueued : StockCountStrings.serialResults[result] ?? ''),
                  trailing: waiting
                      ? IconButton(tooltip: StockCountStrings.minusOne, icon: const Icon(AppIcons.minus), onPressed: () => _undo(item))
                      : StatusBadge(
                          label: (StockCountStrings.serialResults[result] ?? '').toUpperCase(),
                          tone: result == 'matched' ? BadgeTone.success : BadgeTone.warning,
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
