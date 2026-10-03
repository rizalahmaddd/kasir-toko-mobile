import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/money_field.dart';
import '../../../core/widgets/state_views.dart';
import '../../data_changes.dart';
import '../shift_controller.dart';

/// Shown in place of the cashier and shift screens until the cashier opens a shift.
class OpenShiftCard extends ConsumerStatefulWidget {
  const OpenShiftCard({super.key});

  @override
  ConsumerState<OpenShiftCard> createState() => _OpenShiftCardState();
}

class _OpenShiftCardState extends ConsumerState<OpenShiftCard> {
  final _cash = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _cash.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(currentShiftProvider.notifier).open(parseRupiah(_cash.text));
      ref.read(dataChangesProvider).after({DataChange.shifts});
    } on ApiException catch (error) {
      setState(() => _error = error.fieldError('opening_cash') ?? error.message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 4,
            shadowColor: Colors.black26,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(LucideIcons.wallet, size: 28, color: theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  Text('Buka shift dulu', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    'Hitung uang di laci sebelum mulai berjualan. Angka ini jadi patokan saat tutup shift nanti.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  MoneyField(controller: _cash, label: 'Modal awal di laci', errorText: _error, onSubmitted: (_) => _open()),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy ? null : _open,
                    icon: _busy
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(LucideIcons.circlePlay, size: 18),
                    label: const Text('Buka Shift'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ShiftLoadError extends ConsumerWidget {
  const ShiftLoadError({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ErrorState(error: error, onRetry: () => ref.invalidate(currentShiftProvider));
}
