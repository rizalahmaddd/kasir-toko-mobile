import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/auth_controller.dart';
import '../../outlets/outlet_controller.dart';
import '../../pos/presentation/widgets/barcode_scanner_view.dart';
import '../../products/presentation/product_widgets.dart';
import '../count_queue.dart';
import '../data/stock_count_models.dart';
import '../data/stock_count_repository.dart';
import '../stock_count_providers.dart';
import 'count_entry_sheet.dart';
import 'serial_scan_screen.dart';
import 'stock_counts_screen.dart';

enum _Mode { scan, type, list }

class StockCountScreen extends ConsumerStatefulWidget {
  const StockCountScreen({super.key, required this.countId});

  final int countId;

  @override
  ConsumerState<StockCountScreen> createState() => _StockCountScreenState();
}

class _StockCountScreenState extends ConsumerState<StockCountScreen> {
  _Mode _mode = _Mode.scan;
  bool _camera = true;
  String _search = '';
  final _recent = <QueuedCount>[];
  String? _feedback;
  bool _feedbackError = false;

  int get _id => widget.countId;
  int? get _outletId => ref.read(currentOutletIdProvider);

  void _say(String message, {bool error = false}) {
    unawaited(error ? HapticFeedback.heavyImpact() : HapticFeedback.lightImpact());
    if (!error) {
      unawaited(SystemSound.play(SystemSoundType.click));
    }
    setState(() {
      _feedback = message;
      _feedbackError = error;
    });
  }

  void _enqueue(QueuedCount item) {
    ref.read(countQueueProvider.notifier).add(item);
    setState(() => _recent.insert(0, item));
    unawaited(ref.read(countQueueProvider.notifier).sync());
  }

  Future<void> _handleCode(String code) async {
    final user = ref.read(currentUserProvider);
    if (user == null || code.trim().isEmpty) {
      return;
    }
    final catalog = await ref.read(countCatalogProvider(_id).future).catchError((_) => null);
    final hit = catalog?.find(code);

    if (hit != null) {
      final (item, unit) = hit;
      if (item.trackSerial) {
        if (mounted) {
          await SerialScanScreen.open(context, countId: _id, item: item);
        }
        return;
      }
      _enqueue(countEntry(countId: _id, userId: user.id, item: item, lines: {unit?.id: 1}, outletId: _outletId));
      _say(StockCountStrings.scanned(unit?.name ?? item.unit, item.name));
      return;
    }

    try {
      final found = await ref.read(stockCountRepositoryProvider).lookup(_id, code.trim());
      if (!mounted) {
        return;
      }
      switch (found.kind) {
        case 'serial':
          _enqueue(serialScan(countId: _id, userId: user.id, serial: found.serial ?? code, productId: found.productId, productName: found.productName, outletId: _outletId));
          _say('${found.productName ?? ''} · ${found.serial}');
        case 'product' when !found.trackStock:
          _say(StockCountStrings.notTracked(found.productName ?? code), error: true);
        case 'product':
          await _countFound(found, code);
        default:
          await _recordUnknown(code);
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      _say(error.isNetworkError ? StockCountStrings.notInCatalogOffline : errorMessage(error), error: true);
    }
  }

  Future<void> _countFound(CountLookup found, String code) async {
    final user = ref.read(currentUserProvider)!;
    var item = found.item;
    final catalog = await ref.read(countCatalogProvider(_id).future).catchError((_) => null);

    if (item == null && !(catalog?.scopeAll ?? false)) {
      if (!mounted) {
        return;
      }
      final add = await confirmAction(
        context,
        title: StockCountStrings.add,
        message: StockCountStrings.addToCount(found.productName ?? code),
        confirmLabel: StockCountStrings.add,
      );
      if (!add || !mounted) {
        return;
      }
      await ref.read(stockCountRepositoryProvider).addItems(_id, [found.productId!]);
      final refreshed = await ref.read(stockCountRepositoryProvider).lookup(_id, code.trim());
      item = refreshed.item;
    }

    ref.invalidate(countCatalogProvider(_id));
    final target = item?.toCatalog() ??
        CountCatalogItem(itemId: 0, productId: found.productId!, name: found.productName ?? code, unit: '', trackSerial: found.trackSerial);
    if (!mounted) {
      return;
    }
    if (target.trackSerial) {
      await SerialScanScreen.open(context, countId: _id, item: target);
      return;
    }
    _enqueue(countEntry(countId: _id, userId: user.id, item: target, lines: {found.unitId: 1}, outletId: _outletId));
    _say(StockCountStrings.scanned(target.units.where((unit) => unit.id == found.unitId).firstOrNull?.name ?? target.unit, target.name));
  }

  Future<void> _recordUnknown(String code) async {
    final barcode = TextEditingController(text: code);
    final amount = TextEditingController(text: '1');
    final note = TextEditingController();

    final save = await FormSheet.show<bool>(
      context,
      FormSheet(
        title: StockCountStrings.unknownTitle,
        subtitle: StockCountStrings.unknownHint,
        children: [
          TextField(controller: barcode, decoration: const InputDecoration(labelText: StockCountStrings.barcode)),
          const SizedBox(height: AppSizes.s8),
          TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: StockCountStrings.quantity)),
          const SizedBox(height: AppSizes.s8),
          TextField(controller: note, decoration: const InputDecoration(labelText: StockCountStrings.note)),
          const SizedBox(height: AppSizes.s16),
          Builder(builder: (context) => FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text(StockCountStrings.saveEntry))),
        ],
      ),
    );

    final values = (barcode.text.trim(), parseQuantity(amount.text) ?? 0, note.text.trim());
    barcode.dispose();
    amount.dispose();
    note.dispose();
    if (save != true || values.$1.isEmpty || values.$2 <= 0) {
      return;
    }
    try {
      await ref.read(stockCountRepositoryProvider).recordUnknown(_id, barcode: values.$1, quantity: values.$2, note: values.$3.isEmpty ? null : values.$3);
      _say(StockCountStrings.unknownSaved);
    } on ApiException catch (error) {
      _say(errorMessage(error), error: true);
    }
  }

  Future<void> _openEntry(CountCatalogItem item, {double? countedQty, double? systemQty}) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      return;
    }
    if (item.trackSerial) {
      await SerialScanScreen.open(context, countId: _id, item: item);
      return;
    }
    var batches = const <CountBatch>[];
    if (item.trackBatch) {
      try {
        final page = await ref.read(stockCountRepositoryProvider).items(_id, search: item.sku ?? item.name);
        batches = page.items.where((row) => row.productId == item.productId).firstOrNull?.batches ?? const [];
      } on ApiException {
        // Offline: batch yang ada tidak bisa dipilih, tapi hitungan tanpa batch atau batch baru tetap bisa.
      }
    }
    if (!mounted) {
      return;
    }
    final entry = await showCountEntrySheet(context, countId: _id, userId: user.id, outletId: _outletId, item: item, batches: batches, countedQty: countedQty, systemQty: systemQty);
    if (entry != null) {
      _enqueue(entry);
      _say(entry.label);
    }
  }

  Future<void> _undo(QueuedCount item) async {
    if (ref.read(countQueueProvider.notifier).removePending(item.clientUuid)) {
      setState(() => _recent.remove(item));
      return;
    }
    final entryId = ref.read(countQueueProvider).sentEntryIds[item.clientUuid];
    if (entryId == null) {
      return;
    }
    try {
      await ref.read(stockCountRepositoryProvider).voidEntry(_id, entryId);
      setState(() => _recent.remove(item));
      if (mounted) {
        showMessage(context, StockCountStrings.voided);
      }
    } on ApiException catch (error) {
      if (mounted) {
        showError(context, error);
      }
    }
  }

  Future<void> _finish(StockCountDoc count) async {
    final queue = ref.read(countQueueProvider.notifier);
    await queue.sync(includeFailed: true);
    if (!mounted) {
      return;
    }
    if (ref.read(countQueueProvider).pendingFor(_id).isNotEmpty) {
      showMessage(context, StockCountStrings.waitQueue, isError: true);
      return;
    }
    try {
      final updated = await ref.read(stockCountRepositoryProvider).submit(_id);
      ref
        ..invalidate(stockCountProvider(_id))
        ..invalidate(stockCountsProvider);
      if (!mounted) {
        return;
      }
      if (count.canManage && updated.status == StockCountStatuses.review) {
        await context.push(AppRoutes.stockCountReview(_id));
      } else {
        showMessage(context, StockCountStrings.finished);
      }
    } on ApiException catch (error) {
      if (mounted) {
        showError(context, error);
      }
    }
  }

  Future<void> _shareClosed(List<QueuedCount> closed) async {
    final text = closed.map((item) => '${dateTime(item.createdAt)} · ${item.label}').join('\n');
    await SharePlus.instance.share(ShareParams(text: text));
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(stockCountProvider(_id));
    final queue = ref.watch(countQueueProvider);
    final pending = queue.pendingFor(_id);
    final closed = queue.closedFor(_id);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(value.value?.number ?? StockCountStrings.screenTitle),
        actions: [
          if ((value.value?.canManage ?? false) && (value.value?.belongsTo(ref.watch(currentOutletIdProvider)) ?? false))
            IconButton(
              tooltip: StockCountStrings.reviewTitle,
              icon: const Icon(AppIcons.listChecks),
              onPressed: () => context.push(AppRoutes.stockCountReview(_id)),
            ),
        ],
      ),
      body: AsyncView<StockCountDoc>(
        value: value,
        onRetry: () => ref.invalidate(stockCountProvider(_id)),
        data: (count) {
          final ownOutlet = count.belongsTo(ref.watch(currentOutletIdProvider));

          return Column(
            children: [
              _Header(
                count: count,
                pending: pending.length,
                failed: pending.where((item) => item.failed).map((item) => item.error).nonNulls.firstOrNull,
                syncing: queue.syncing,
                onSync: () => ref.read(countQueueProvider.notifier).sync(includeFailed: true),
              ),
              if (closed.isNotEmpty)
                MaterialBanner(
                  content: Text(StockCountStrings.closedKept(closed.length)),
                  actions: [
                    TextButton(onPressed: () => _shareClosed(closed), child: const Text(StockCountStrings.shareClosed)),
                    TextButton(onPressed: () => ref.read(countQueueProvider.notifier).discardClosed(_id), child: const Text(StockCountStrings.discardClosed)),
                  ],
                ),
              if (!ownOutlet)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  child: Text(StockCountStrings.otherOutlet(count.number, count.outletName ?? ''), style: Theme.of(context).textTheme.bodyMedium),
                )
              else if (!count.isEditable)
                Padding(padding: const EdgeInsets.all(AppSpacing.s16), child: Text(StockCountStrings.closed, style: Theme.of(context).textTheme.bodyMedium))
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s6),
                  child: SegmentedButton<_Mode>(
                    segments: const [
                      ButtonSegment(value: _Mode.scan, icon: Icon(AppIcons.scanBarcode), label: Text(StockCountStrings.scanMode)),
                      ButtonSegment(value: _Mode.type, icon: Icon(AppIcons.keyboard), label: Text(StockCountStrings.typeMode)),
                      ButtonSegment(value: _Mode.list, icon: Icon(AppIcons.listChecks), label: Text(StockCountStrings.listMode)),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (selected) => setState(() => _mode = selected.first),
                  ),
                ),
                if (_feedback != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s4),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
                    decoration: BoxDecoration(
                      color: _feedbackError
                          ? theme.colorScheme.errorContainer
                          : theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.r8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _feedbackError ? AppIcons.circleAlert : AppIcons.circleCheck,
                          size: AppSizes.s16,
                          color: _feedbackError ? theme.colorScheme.error : theme.colorScheme.primary,
                        ),
                        const SizedBox(width: AppSizes.s8),
                        Expanded(
                          child: Text(
                            _feedback!,
                            style: TextStyle(
                              color: _feedbackError
                                  ? theme.colorScheme.onErrorContainer
                                  : theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: switch (_mode) {
                    _Mode.scan => _ScanPane(
                        camera: _camera,
                        recent: _recent.take(8).toList(),
                        pendingIds: pending.map((item) => item.clientUuid).toSet(),
                        onToggleCamera: () => setState(() => _camera = !_camera),
                        onCode: _handleCode,
                        onUndo: _undo,
                      ),
                    _Mode.type => _TypePane(
                        catalog: ref.watch(countCatalogProvider(_id)),
                        search: _search,
                        onSearch: (term) => setState(() => _search = term),
                        onSubmit: _handleCode,
                        onPick: _openEntry,
                      ),
                    _Mode.list => _ItemsPane(
                        countId: _id,
                        canSeeSystem: count.canSeeSystem,
                        onPick: (item) => _openEntry(
                          item.toCatalog(),
                          countedQty: item.countedQty,
                          systemQty: count.canSeeSystem ? item.systemQty : null,
                        ),
                      ),
                  },
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s8, AppSpacing.s16, AppSpacing.s8),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate900 : Colors.white,
                    border: Border(top: BorderSide(color: isDark ? AppColors.slate800 : AppColors.slate200)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _finish(count),
                        icon: const Icon(AppIcons.check, size: AppSizes.s18),
                        label: Text(count.canManage && count.status == StockCountStatuses.counting ? StockCountStrings.toReview : StockCountStrings.finishCounting),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.count, required this.pending, required this.syncing, required this.onSync, this.failed});

  final StockCountDoc count;
  final int pending;
  final bool syncing;
  final String? failed;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = StatusColors.of(context);
    final percent = (count.progress * 100).toInt();

    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s8, AppSpacing.s16, AppSpacing.s4),
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              StatusBadge(label: count.statusLabel.toUpperCase(), tone: stockCountTone(count.status)),
              const SizedBox(width: AppSizes.s8),
              if (count.outletName != null) ...[
                Icon(AppIcons.briefcaseBusiness, size: AppSizes.s12, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: AppSizes.s4),
                Text(
                  count.outletName!,
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                ),
              ],
              const Spacer(),
              Text(
                '$percent% (${thousands(count.countedCount)}/${thousands(count.itemsCount)})',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.s8),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.r4),
            child: LinearProgressIndicator(
              value: count.progress,
              minHeight: 6,
              backgroundColor: isDark ? AppColors.slate700 : AppColors.slate200,
            ),
          ),
          const SizedBox(height: AppSizes.s8),
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.r6),
            onTap: pending > 0 ? onSync : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
              child: Row(
                children: [
                  Icon(
                    pending > 0 ? AppIcons.cloudUpload : AppIcons.cloudCheck,
                    size: AppSizes.s14,
                    color: pending > 0 ? colors.warning : colors.success,
                  ),
                  const SizedBox(width: AppSizes.s6),
                  Expanded(
                    child: Text(
                      pending > 0 ? StockCountStrings.pending(pending) : StockCountStrings.allSent,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: pending > 0 ? colors.warning : colors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (syncing) const SizedBox(width: AppSizes.s12, height: AppSizes.s12, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
            ),
          ),
          if (failed != null) ...[
            const SizedBox(height: AppSizes.s4),
            Text(failed!, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error)),
          ],
        ],
      ),
    );
  }
}

class _ScanPane extends StatelessWidget {
  const _ScanPane({
    required this.camera,
    required this.recent,
    required this.pendingIds,
    required this.onToggleCamera,
    required this.onCode,
    required this.onUndo,
  });

  final bool camera;
  final List<QueuedCount> recent;
  final Set<String> pendingIds;
  final VoidCallback onToggleCamera;
  final ValueChanged<String> onCode;
  final ValueChanged<QueuedCount> onUndo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
      children: [
        if (camera)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.r16),
                border: Border.all(color: isDark ? AppColors.slate700 : AppColors.slate300, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.r14),
                child: SizedBox(
                  height: 220,
                  child: BarcodeScannerView(
                    continuous: true,
                    hintText: StockCountStrings.scanHint,
                    onDetect: onCode,
                  ),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s8, AppSpacing.s16, AppSpacing.s4),
          child: Row(
            children: [
              Expanded(
                child: SearchField(
                  hint: StockCountStrings.searchHint,
                  onSubmitted: (value) => onCode(value),
                  debounceDuration: Duration.zero,
                  dense: true,
                ),
              ),
              const SizedBox(width: AppSizes.s8),
              IconButton.outlined(
                tooltip: camera ? StockCountStrings.cameraOff : StockCountStrings.cameraOn,
                onPressed: onToggleCamera,
                icon: Icon(camera ? AppIcons.camera : AppIcons.scanBarcode, size: AppSizes.s20),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.s16),
          child: SectionTitle(StockCountStrings.recentScans),
        ),
        if (recent.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s20),
            child: Center(
              child: Text(
                StockCountStrings.noScans,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          for (final item in recent)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s4),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
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
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.r6),
                    ),
                    child: Icon(AppIcons.check, size: AppSizes.s14, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: AppSizes.s10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: AppSizes.s2),
                        Text(
                          pendingIds.contains(item.clientUuid) ? StockCountStrings.serialQueued : timeOnly(item.createdAt),
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: StockCountStrings.minusOne,
                    icon: const Icon(AppIcons.minus, size: AppSizes.s16),
                    onPressed: () => onUndo(item),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _TypePane extends StatelessWidget {
  const _TypePane({
    required this.catalog,
    required this.search,
    required this.onSearch,
    required this.onSubmit,
    required this.onPick,
  });

  final AsyncValue<CountCatalog?> catalog;
  final String search;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onSubmit;
  final void Function(CountCatalogItem item) onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final items = catalog.value?.search(search) ?? const <CountCatalogItem>[];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
          child: SearchField(
            hint: StockCountStrings.searchHint,
            initialValue: search,
            onChanged: onSearch,
            onSubmitted: onSubmit,
            autofocus: false,
            dense: true,
          ),
        ),
        Expanded(
          child: catalog.isLoading && !catalog.hasValue
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
                  ? const EmptyState(icon: AppIcons.packageSearch, title: StockCountStrings.notInCatalogOffline)
                  : ListView.builder(
                      itemCount: items.length,
                      padding: const EdgeInsets.only(bottom: AppSpacing.s24),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s4),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.slate800 : Colors.white,
                            borderRadius: BorderRadius.circular(AppRadius.r10),
                            border: Border.all(color: isDark ? AppColors.slate700 : AppColors.slate200),
                            boxShadow: [
                              if (!isDark)
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(AppRadius.r10),
                              onTap: () => onPick(item),
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.s12),
                                child: Row(
                                  children: [
                                    ProductThumb(name: item.name, size: 42),
                                    const SizedBox(width: AppSizes.s12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: AppSizes.s4),
                                          Wrap(
                                            spacing: AppSizes.s8,
                                            runSpacing: AppSizes.s2,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              if (item.sku != null && item.sku!.isNotEmpty)
                                                Text(
                                                  item.sku!,
                                                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                                ),
                                              if (item.barcode != null && item.barcode!.isNotEmpty)
                                                Text(
                                                  item.barcode!,
                                                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                                ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: AppSpacing.s2),
                                                decoration: BoxDecoration(
                                                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(AppRadius.r4),
                                                ),
                                                child: Text(
                                                  [item.unit, ...item.units.map((u) => u.name)].join('/'),
                                                  style: theme.textTheme.labelSmall?.copyWith(
                                                    color: theme.colorScheme.primary,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      item.trackSerial ? AppIcons.scanBarcode : AppIcons.chevronRight,
                                      size: AppSizes.s18,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _ItemsPane extends ConsumerStatefulWidget {
  const _ItemsPane({required this.countId, required this.canSeeSystem, required this.onPick});

  final int countId;
  final bool canSeeSystem;
  final ValueChanged<CountItem> onPick;

  @override
  ConsumerState<_ItemsPane> createState() => _ItemsPaneState();
}

class _ItemsPaneState extends ConsumerState<_ItemsPane> {
  String? _filter;
  String _search = '';
  final _items = <CountItem>[];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _items.clear();
      _page = 0;
      _hasMore = true;
      _error = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) {
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await ref.read(stockCountRepositoryProvider).items(widget.countId, filter: _filter, search: _search, page: _page + 1);
      if (!mounted) {
        return;
      }
      setState(() {
        _items.addAll(result.items);
        _page = result.currentPage;
        _hasMore = result.hasMore;
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final status = StatusColors.of(context);

    final filters = [
      (null, StockCountStrings.filterAll),
      ('uncounted', StockCountStrings.filterUncounted),
      ('counted', StockCountStrings.filterCounted),
      if (widget.canSeeSystem) ('variance', StockCountStrings.filterVariance),
      ('recount', StockCountStrings.filterRecount),
    ];

    return Column(
      children: [
        ChoiceChips<String>(
          options: filters,
          selected: _filter,
          onSelected: (value) {
            _filter = value;
            _reload();
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s4),
          child: SearchField(
            hint: StockCountStrings.searchHint,
            onChanged: (term) {
              _search = term;
              _reload();
            },
            dense: true,
          ),
        ),
        Expanded(
          child: _error != null && _items.isEmpty
              ? ErrorState(error: _error!, onRetry: _reload)
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification.metrics.extentAfter < 300) {
                        _loadMore();
                      }
                      return false;
                    },
                    child: ListView.builder(
                      itemCount: _items.length + (_loading ? 1 : 0),
                      padding: const EdgeInsets.only(bottom: AppSpacing.s24),
                      itemBuilder: (context, index) {
                        if (index >= _items.length) {
                          return const Padding(padding: EdgeInsets.all(AppSpacing.s16), child: Center(child: CircularProgressIndicator()));
                        }
                        final item = _items[index];
                        final variance = item.varianceQty;

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s4),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.slate800 : Colors.white,
                            borderRadius: BorderRadius.circular(AppRadius.r10),
                            border: Border.all(
                              color: item.needsRecount
                                  ? status.warning.withValues(alpha: 0.7)
                                  : isDark
                                      ? AppColors.slate700
                                      : AppColors.slate200,
                            ),
                            boxShadow: [
                              if (!isDark)
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(AppRadius.r10),
                              onTap: () => widget.onPick(item),
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.s12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.displayName,
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (item.needsRecount)
                                          StatusBadge(label: StockCountStrings.recount.toUpperCase(), tone: BadgeTone.warning)
                                        else if (item.countedQty == null)
                                          const StatusBadge(label: StockCountStrings.badgeUncounted, tone: BadgeTone.muted)
                                        else
                                          const StatusBadge(label: StockCountStrings.badgeCounted, tone: BadgeTone.success),
                                      ],
                                    ),
                                    const SizedBox(height: AppSizes.s4),
                                    if (item.sku != null && item.sku!.isNotEmpty)
                                      Text(
                                        item.sku!,
                                        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                      ),
                                    const SizedBox(height: AppSizes.s8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s6),
                                      decoration: BoxDecoration(
                                        color: isDark ? AppColors.slate900.withValues(alpha: 0.5) : AppColors.slate100,
                                        borderRadius: BorderRadius.circular(AppRadius.r6),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(StockCountStrings.labelCounted, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 10)),
                                                const SizedBox(height: AppSizes.s2),
                                                Text(
                                                  item.countedQty == null ? '-' : '${quantity(item.countedQty!)} ${item.unit}',
                                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (widget.canSeeSystem) ...[
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(StockCountStrings.labelSystem, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 10)),
                                                  const SizedBox(height: AppSizes.s2),
                                                  Text(
                                                    item.systemQty == null ? '-' : '${quantity(item.systemQty!)} ${item.unit}',
                                                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(StockCountStrings.labelVariance, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 10)),
                                                  const SizedBox(height: AppSizes.s2),
                                                  Text(
                                                    variance == null || variance == 0
                                                        ? '0'
                                                        : '${variance > 0 ? '+' : ''}${quantity(variance)}',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 13,
                                                      color: variance == null || variance == 0
                                                          ? theme.colorScheme.onSurfaceVariant
                                                          : variance < 0
                                                              ? status.danger
                                                              : status.success,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
