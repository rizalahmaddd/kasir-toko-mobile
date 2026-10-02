import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../../router.dart';
import '../../auth/auth_controller.dart';
import '../onboarding.dart';

const _icons = {
  'store': LucideIcons.store,
  'shopping-basket': LucideIcons.shoppingBasket,
  'coffee': LucideIcons.coffee,
  'utensils-crossed': LucideIcons.utensilsCrossed,
  'shirt': LucideIcons.shirt,
  'hammer': LucideIcons.hammer,
  'smartphone': LucideIcons.smartphone,
  'pill': LucideIcons.pill,
  'croissant': LucideIcons.croissant,
  'package': LucideIcons.package,
};

const _paymentLabels = {'cash': 'Tunai', 'qris': 'QRIS', 'transfer': 'Transfer', 'card': 'Kartu'};

const _featureLabels = {'pos.receivables': 'Piutang (kasbon)', 'pos.customer-display': 'Layar pelanggan'};

/// Store-type picker shown to a new shop owner, and reachable from the menu to re-apply a preset
/// while the shop has no sales yet.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  StorePreset? _selected;
  bool _includeSamples = true;
  bool _busy = false;

  Future<void> _run(Future<String> Function() action) async {
    setState(() => _busy = true);
    try {
      final message = await action();
      if (!mounted) {
        return;
      }
      final user = ref.read(currentUserProvider);
      showMessage(context, message);
      context.go(user == null ? '/login' : homeFor(user));
    } on Object catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        showError(context, error);
      }
    }
  }

  void _apply(StorePreset preset) => _run(() async {
        final result = await ref.read(onboardingActionsProvider).apply(preset.key, includeSampleProducts: _includeSamples);
        final parts = [
          '${result.categoriesCreated} kategori',
          if (_includeSamples) '${result.productsCreated} produk contoh',
        ];
        final skipped = result.productsSkipped > 0 ? ' ${result.productsSkipped} produk dilewati karena batas paket.' : '';
        return 'Preset ${preset.label} diterapkan: ${parts.join(' dan ')} dibuat.$skipped';
      });

  void _skip() => _run(() async {
        await ref.read(onboardingActionsProvider).skip();
        return 'Toko siap dipakai. Tambahkan kategori dan produk kapan saja.';
      });

  @override
  Widget build(BuildContext context) {
    final firstRun = ref.watch(currentUserProvider)?.needsOnboarding ?? false;
    final selected = _selected;

    return PopScope(
      canPop: selected == null && !firstRun,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && selected != null && !_busy) {
          setState(() => _selected = null);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: selected != null
              ? IconButton(icon: const Icon(LucideIcons.arrowLeft), onPressed: _busy ? null : () => setState(() => _selected = null))
              : firstRun
                  ? null
                  : const BackButton(),
          title: Text(selected == null ? 'Jenis toko' : selected.label),
          actions: [
            if (firstRun && selected == null)
              TextButton(
                onPressed: _busy ? null : () => ref.read(authControllerProvider.notifier).logout(),
                child: const Text('Keluar'),
              ),
          ],
        ),
        body: SafeArea(
          child: selected == null
              ? _PresetPicker(firstRun: firstRun, busy: _busy, onSelect: (preset) => setState(() => _selected = preset), onSkip: _skip)
              : _PresetPreview(
                  preset: selected,
                  firstRun: firstRun,
                  includeSamples: _includeSamples,
                  busy: _busy,
                  onIncludeSamples: (value) => setState(() => _includeSamples = value),
                  onApply: () => _apply(selected),
                ),
        ),
      ),
    );
  }
}

class _PresetPicker extends ConsumerWidget {
  const _PresetPicker({required this.firstRun, required this.busy, required this.onSelect, required this.onSkip});

  final bool firstRun;
  final bool busy;
  final ValueChanged<StorePreset> onSelect;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final presets = ref.watch(storePresetsProvider);
    final columns = context.isWide ? 4 : (context.isMedium ? 3 : 2);

    return AsyncView(
      value: presets,
      onRetry: () => ref.invalidate(storePresetsProvider),
      data: (items) => MaxWidth(
        width: 960,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              sliver: SliverToBoxAdapter(
                child: Text(
                  firstRun
                      ? 'Pilih jenis toko Anda. Kategori, produk contoh, dan pengaturan kasir akan disiapkan sesuai jenisnya, dan semuanya bisa diubah nanti.'
                      : 'Terapkan preset lain selama toko belum punya transaksi. Kategori dan produk yang sudah ada tidak dihapus.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 168,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) => _PresetCard(preset: items[index], onTap: busy ? null : () => onSelect(items[index])),
              ),
            ),
            if (firstRun)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: busy ? null : onSkip,
                    child: busy
                        ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Lewati, mulai dari kosong'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PresetCard extends ConsumerWidget {
  const _PresetCard({required this.preset, required this.onTap});

  final StorePreset preset;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final current = ref.watch(currentUserProvider)?.tenant?.storeType == preset.key;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: current ? theme.colorScheme.primary : theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_icons[preset.icon] ?? LucideIcons.store, size: 26, color: theme.colorScheme.primary),
                  const Spacer(),
                  if (current) const StatusBadge(label: 'Dipakai', tone: BadgeTone.info),
                ],
              ),
              const SizedBox(height: 10),
              Text(preset.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  preset.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetPreview extends StatelessWidget {
  const _PresetPreview({
    required this.preset,
    required this.firstRun,
    required this.includeSamples,
    required this.busy,
    required this.onIncludeSamples,
    required this.onApply,
  });

  final StorePreset preset;
  final bool firstRun;
  final bool includeSamples;
  final bool busy;
  final ValueChanged<bool> onIncludeSamples;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = preset.settings;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: MaxWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(preset.description, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  SectionTitle('Kategori (${preset.categories.length})'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [for (final name in preset.categories) Chip(label: Text(name), visualDensity: VisualDensity.compact)],
                  ),
                  const SectionTitle('Pengaturan kasir'),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        children: [
                          InfoRow('Pajak', settings.taxEnabled ? '${settings.taxLabel} ${percent(settings.taxRate)}' : 'Tidak ada'),
                          InfoRow('Kasbon', settings.allowCredit ? 'Aktif' : 'Nonaktif'),
                          InfoRow('Jual saat stok habis', settings.allowNegativeStock ? 'Boleh' : 'Tidak boleh'),
                          InfoRow('Metode bayar', settings.paymentMethods.map((m) => _paymentLabels[m] ?? m).join(', ')),
                          InfoRow('Uang cepat', settings.quickCash.map(thousands).join(' · ')),
                          InfoRow('Footer struk', settings.receiptFooter.isEmpty ? '-' : settings.receiptFooter),
                        ],
                      ),
                    ),
                  ),
                  if (preset.disabledFeatures.isNotEmpty) ...[
                    const SectionTitle('Modul yang dimatikan'),
                    Text(
                      preset.disabledFeatures.map((f) => _featureLabels[f] ?? f).join(', '),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Card(
                    margin: EdgeInsets.zero,
                    child: CheckboxListTile(
                      value: includeSamples,
                      onChanged: busy || preset.sampleProductCount == 0 ? null : (value) => onIncludeSamples(value ?? true),
                      title: const Text('Sertakan produk contoh'),
                      subtitle: Text(
                        preset.sampleProductCount == 0
                            ? 'Preset ini tidak punya produk contoh.'
                            : '${preset.sampleProductCount} produk dengan harga perkiraan, bisa diubah atau dihapus.',
                      ),
                    ),
                  ),
                  if (!firstRun) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Pengaturan kasir di atas akan menggantikan pengaturan saat ini.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: MaxWidth(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: busy ? null : onApply,
              icon: busy
                  ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(LucideIcons.check, size: 18),
              label: const Text('Terapkan'),
            ),
          ),
        ),
      ],
    );
  }
}
