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
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/auth_controller.dart';
import '../../pos/presentation/widgets/barcode_scanner_view.dart';
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
      _enqueue(countEntry(countId: _id, userId: user.id, item: item, lines: {unit?.id: 1}));
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
          _enqueue(serialScan(countId: _id, userId: user.id, serial: found.serial ?? code, productId: found.productId, productName: found.productName));
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
    _enqueue(countEntry(countId: _id, userId: user.id, item: target, lines: {found.unitId: 1}));
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
    final entry = await showCountEntrySheet(context, countId: _id, userId: user.id, item: item, batches: batches, countedQty: countedQty, systemQty: systemQty);
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

    return Scaffold(
      appBar: AppBar(
        title: Text(value.value?.number ?? StockCountStrings.screenTitle),
        actions: [
          if (value.value?.canManage ?? false)
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
        data: (count) => Column(
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
            if (!count.isEditable)
              Padding(padding: const EdgeInsets.all(AppSpacing.s16), child: Text(StockCountStrings.closed, style: Theme.of(context).textTheme.bodyMedium))
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
                  child: Text(
                    _feedback!,
                    style: TextStyle(color: _feedbackError ? Theme.of(context).colorScheme.error : null, fontWeight: FontWeight.w600),
                  ),
                ),
              Expanded(
                child: switch (_mode) {
                  _Mode.scan => _ScanPane(
                      camera: _camera,
                      recent: _recent.take(5).toList(),
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
                  _Mode.list => _ItemsPane(countId: _id, canSeeSystem: count.canSeeSystem, onPick: (item) => _openEntry(item.toCatalog(), countedQty: item.countedQty, systemQty: count.canSeeSystem ? item.systemQty : null)),
                },
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s8, AppSpacing.s16, AppSpacing.s8),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _finish(count),
                      icon: const Icon(AppIcons.check),
                      label: Text(count.canManage && count.status == StockCountStatuses.counting ? StockCountStrings.toReview : StockCountStrings.finishCounting),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s16, AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              StatusBadge(label: count.statusLabel.toUpperCase(), tone: stockCountTone(count.status)),
              const SizedBox(width: AppSizes.s8),
              Expanded(child: Text(StockCountStrings.progress(thousands(count.countedCount), thousands(count.itemsCount)), style: theme.textTheme.bodySmall)),
            ],
          ),
          const SizedBox(height: AppSizes.s6),
          LinearProgressIndicator(value: count.progress, minHeight: 4),
          const SizedBox(height: AppSizes.s6),
          InkWell(
            onTap: pending > 0 ? onSync : null,
            child: Row(
              children: [
                Icon(pending > 0 ? AppIcons.cloudUpload : AppIcons.cloudCheck, size: AppSizes.s16),
                const SizedBox(width: AppSizes.s6),
                Expanded(
                  child: Text(
                    pending > 0 ? StockCountStrings.pending(pending) : StockCountStrings.allSent,
                    style: theme.textTheme.labelMedium,
                  ),
                ),
                if (syncing) const SizedBox(width: AppSizes.s14, height: AppSizes.s14, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          ),
          if (failed != null) Text(failed!, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error)),
        ],
      ),
    );
  }
}

class _ScanPane extends StatelessWidget {
  const _ScanPane({required this.camera, required this.recent, required this.pendingIds, required this.onToggleCamera, required this.onCode, required this.onUndo});

  final bool camera;
  final List<QueuedCount> recent;
  final Set<String> pendingIds;
  final VoidCallback onToggleCamera;
  final ValueChanged<String> onCode;
  final ValueChanged<QueuedCount> onUndo;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
      children: [
        if (camera)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.s12),
              child: SizedBox(height: 220, child: BarcodeScannerView(continuous: true, hintText: StockCountStrings.scanHint, onDetect: onCode)),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
          child: Row(
            children: [
              Expanded(
                child: SearchField(hint: StockCountStrings.searchHint, onSubmitted: (value) => onCode(value), debounceDuration: Duration.zero),
              ),
              IconButton(
                tooltip: camera ? StockCountStrings.cameraOff : StockCountStrings.cameraOn,
                onPressed: onToggleCamera,
                icon: Icon(camera ? AppIcons.camera : AppIcons.scanBarcode),
              ),
            ],
          ),
        ),
        const SectionTitle(StockCountStrings.recentScans),
        if (recent.isEmpty)
          const Padding(padding: EdgeInsets.all(AppSpacing.s16), child: Text(StockCountStrings.noScans))
        else
          for (final item in recent)
            ListTile(
              dense: true,
              title: Text(item.label),
              subtitle: Text(pendingIds.contains(item.clientUuid) ? StockCountStrings.serialQueued : timeOnly(item.createdAt)),
              trailing: IconButton(tooltip: StockCountStrings.minusOne, icon: const Icon(AppIcons.minus), onPressed: () => onUndo(item)),
            ),
      ],
    );
  }
}

class _TypePane extends StatelessWidget {
  const _TypePane({required this.catalog, required this.search, required this.onSearch, required this.onSubmit, required this.onPick});

  final AsyncValue<CountCatalog?> catalog;
  final String search;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onSubmit;
  final void Function(CountCatalogItem item) onPick;

  @override
  Widget build(BuildContext context) {
    final items = catalog.value?.search(search) ?? const <CountCatalogItem>[];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
          child: SearchField(hint: StockCountStrings.searchHint, initialValue: search, onChanged: onSearch, onSubmitted: onSubmit, autofocus: true),
        ),
        Expanded(
          child: catalog.isLoading && !catalog.hasValue
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
                  ? const EmptyState(icon: AppIcons.packageSearch, title: StockCountStrings.notInCatalogOffline)
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ListTile(
                          title: Text(item.name),
                          subtitle: Text([item.sku, item.barcode].nonNulls.where((value) => value.isNotEmpty).join(' · ')),
                          trailing: Icon(item.trackSerial ? AppIcons.scanBarcode : AppIcons.chevronRight),
                          onTap: () => onPick(item),
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
                      itemBuilder: (context, index) {
                        if (index >= _items.length) {
                          return const Padding(padding: EdgeInsets.all(AppSpacing.s16), child: Center(child: CircularProgressIndicator()));
                        }
                        final item = _items[index];
                        final variance = item.varianceQty;
                        final status = StatusColors.of(context);

                        return ListTile(
                          title: Text(item.displayName),
                          subtitle: Text(
                            [
                              if (item.sku != null) item.sku!,
                              if (widget.canSeeSystem && item.systemQty != null) StockCountStrings.system('${quantity(item.systemQty!)} ${item.unit}'),
                              if (item.needsRecount) StockCountStrings.recount,
                            ].join(' · '),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(item.countedQty == null ? StockCountStrings.notCounted : '${quantity(item.countedQty!)} ${item.unit}'),
                              if (variance != null && variance != 0)
                                Text(
                                  '${variance > 0 ? '+' : ''}${quantity(variance)}',
                                  style: TextStyle(color: variance < 0 ? status.danger : status.success, fontWeight: FontWeight.w700),
                                ),
                            ],
                          ),
                          onTap: () => widget.onPick(item),
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
