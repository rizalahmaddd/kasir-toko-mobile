import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../../printing/presentation/printer_screen.dart';
import '../../printing/printer.dart';
import '../data/kitchen_models.dart';
import '../data/kitchen_repository.dart';

/// Layar dapur di HP/tablet: tiket outlet aktif yang belum disiapkan, disegarkan otomatis tiap 15 detik.
class KitchenScreen extends ConsumerStatefulWidget {
  const KitchenScreen({super.key});

  @override
  ConsumerState<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends ConsumerState<KitchenScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => ref.invalidate(kitchenTicketsProvider));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<KitchenTicket> Function() action, String done) async {
    try {
      await action();
      ref.invalidate(kitchenTicketsProvider);
      if (mounted) {
        showMessage(context, done);
      }
    } on ApiException catch (error) {
      if (mounted) {
        showError(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(kitchenStatusProvider);
    final repository = ref.read(kitchenRepositoryProvider);
    final canPrint = ref.watch(printerSettingsProvider).isConfigured;

    return Scaffold(
      appBar: AppBar(title: const Text(KitchenStrings.screenTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s12),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'pending', label: Text(KitchenStrings.pending)),
                ButtonSegment(value: 'done', label: Text(KitchenStrings.doneToday)),
              ],
              selected: {status},
              onSelectionChanged: (value) => ref.read(kitchenStatusProvider.notifier).set(value.first),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(kitchenTicketsProvider.future),
              child: AsyncView<List<KitchenTicket>>(
                value: ref.watch(kitchenTicketsProvider),
                onRetry: () => ref.invalidate(kitchenTicketsProvider),
                data: (tickets) => tickets.isEmpty
                    ? ListView(children: [EmptyState(icon: AppIcons.chefHat, title: status == 'done' ? KitchenStrings.emptyDone : KitchenStrings.empty, description: KitchenStrings.emptyHint)])
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth >= 600) {
                            final columns = constraints.maxWidth >= 960 ? 3 : 2;
                            return SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(AppSpacing.s12, AppSpacing.s0, AppSpacing.s12, AppSpacing.s24),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (int col = 0; col < columns; col++) ...[
                                    if (col > 0) const SizedBox(width: AppSpacing.s10),
                                    Expanded(
                                      child: Column(
                                        children: [
                                          for (int i = col; i < tickets.length; i += columns)
                                            _buildTicketCard(context, tickets[i], repository, canPrint),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.s12, AppSpacing.s0, AppSpacing.s12, AppSpacing.s24),
                            itemCount: tickets.length,
                            itemBuilder: (context, index) => _buildTicketCard(context, tickets[index], repository, canPrint),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCard(BuildContext context, KitchenTicket ticket, KitchenRepository repository, bool canPrint) {
    final minutes = DateTime.now().difference(ticket.createdAt).inMinutes;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.s10),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(ticket.label, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
                if (ticket.orderTypeLabel != null) StatusBadge(label: ticket.orderTypeLabel!.toUpperCase(), tone: BadgeTone.info),
              ],
            ),
            Text(
              [timeOnly(ticket.createdAt), ?ticket.cashier, ?ticket.saleNumber, if (!ticket.isDone) KitchenStrings.minutes(minutes)].join(' · '),
              style: TextStyle(fontSize: 12, color: !ticket.isDone && minutes >= 15 ? StatusColors.of(context).warning : Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const Divider(),
            for (final item in ticket.items) ...[
              Text('${quantity(item.quantity)}× ${item.name}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              if (item.modifiers.isNotEmpty) Text(item.modifiers.join(', '), style: TextStyle(fontSize: 12, color: StatusColors.of(context).info)),
              if (item.note != null && item.note!.isNotEmpty) Text(item.note!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: StatusColors.of(context).warning)),
              const SizedBox(height: AppSizes.s6),
            ],
            const SizedBox(height: AppSizes.s4),
            Row(
              children: [
                Expanded(
                  child: ticket.isDone
                      ? OutlinedButton(onPressed: () => _run(() => repository.reopen(ticket.id), KitchenStrings.reopened), child: const Text(KitchenStrings.reopen))
                      : FilledButton.icon(
                          onPressed: () => _run(() => repository.done(ticket.id), KitchenStrings.markedDone(ticket.label)),
                          icon: const Icon(AppIcons.check, size: AppSizes.s18),
                          label: const Text(KitchenStrings.markDone),
                        ),
                ),
                if (canPrint)
                  IconButton(
                    tooltip: PosStrings.printKitchenTicket,
                    onPressed: () => runPrint(context, () => ref.read(printerServiceProvider).printKitchenTicket(ticket), success: PrintingStrings.kitchenTicketPrinted),
                    icon: const Icon(AppIcons.printer),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
