import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
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
  Set<String> _selectedCategories = {};
  bool _includeSamples = true;
  bool _taxEnabled = false;
  double _taxRate = 11.0;
  String _taxLabel = 'PPN';
  bool _allowCredit = true;
  bool _allowNegativeStock = false;
  bool _busy = false;

  void _selectPreset(StorePreset preset) {
    setState(() {
      _selected = preset;
      _selectedCategories = preset.categories.toSet();
      _includeSamples = preset.sampleProductCount > 0;
      _taxEnabled = preset.settings.taxEnabled;
      _taxRate = preset.settings.taxRate;
      _taxLabel = preset.settings.taxLabel.isNotEmpty ? preset.settings.taxLabel : 'PPN';
      _allowCredit = preset.settings.allowCredit;
      _allowNegativeStock = preset.settings.allowNegativeStock;
    });
  }

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

  void _apply(StorePreset preset) {
    if (_selectedCategories.isEmpty) {
      showMessage(context, 'Pilih minimal 1 kategori untuk toko Anda.', isError: true);
      return;
    }

    _run(() async {
      final result = await ref.read(onboardingActionsProvider).apply(
            preset.key,
            includeSampleProducts: _includeSamples,
            categories: _selectedCategories.toList(),
            settings: {
              'tax_enabled': _taxEnabled,
              'tax_rate': _taxRate,
              'tax_label': _taxLabel,
              'allow_credit': _allowCredit,
              'allow_negative_stock': _allowNegativeStock,
            },
          );
      final parts = [
        '${result.categoriesCreated} kategori',
        if (_includeSamples && result.productsCreated > 0) '${result.productsCreated} produk contoh',
      ];
      final skipped = result.productsSkipped > 0 ? ' ${result.productsSkipped} produk dilewati karena batas paket.' : '';
      return 'Preset ${preset.label} diterapkan: ${parts.join(' dan ')} dibuat.$skipped';
    });
  }

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
              ? IconButton(
                  icon: const Icon(LucideIcons.arrowLeft),
                  onPressed: _busy ? null : () => setState(() => _selected = null),
                )
              : firstRun
                  ? null
                  : const BackButton(),
          title: Text(selected == null ? 'Pilih Jenis Toko' : selected.label),
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
              ? _PresetPicker(
                  firstRun: firstRun,
                  busy: _busy,
                  onSelect: _selectPreset,
                  onSkip: _skip,
                )
              : _PresetPreview(
                  preset: selected,
                  firstRun: firstRun,
                  selectedCategories: _selectedCategories,
                  includeSamples: _includeSamples,
                  taxEnabled: _taxEnabled,
                  taxRate: _taxRate,
                  taxLabel: _taxLabel,
                  allowCredit: _allowCredit,
                  allowNegativeStock: _allowNegativeStock,
                  busy: _busy,
                  onToggleCategory: (category) {
                    setState(() {
                      if (_selectedCategories.contains(category)) {
                        _selectedCategories.remove(category);
                      } else {
                        _selectedCategories.add(category);
                      }
                    });
                  },
                  onSelectAllCategories: () {
                    setState(() => _selectedCategories = selected.categories.toSet());
                  },
                  onClearAllCategories: () {
                    setState(() => _selectedCategories.clear());
                  },
                  onIncludeSamplesChanged: (value) => setState(() => _includeSamples = value),
                  onTaxEnabledChanged: (value) => setState(() => _taxEnabled = value),
                  onTaxRateChanged: (value) => setState(() => _taxRate = value),
                  onAllowCreditChanged: (value) => setState(() => _allowCredit = value),
                  onAllowNegativeStockChanged: (value) => setState(() => _allowNegativeStock = value),
                  onApply: () => _apply(selected),
                ),
        ),
      ),
    );
  }
}

class _PresetPicker extends ConsumerWidget {
  const _PresetPicker({
    required this.firstRun,
    required this.busy,
    required this.onSelect,
    required this.onSkip,
  });

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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      firstRun
                          ? 'Pilih jenis usaha Anda untuk memulai'
                          : 'Ubah atau terapkan preset jenis toko baru',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      firstRun
                          ? 'Kategori, produk contoh, dan pengaturan kasir akan disesuaikan dengan jenis toko Anda. Anda tetap bisa memilih kategori dan mengubah pengaturannya.'
                          : 'Terapkan preset lain selama toko belum punya transaksi. Data yang sudah ada tidak akan dihapus.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
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
                  mainAxisExtent: 172,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) => _PresetCard(
                  preset: items[index],
                  onTap: busy ? null : () => onSelect(items[index]),
                ),
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
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
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
    final isDark = theme.brightness == Brightness.dark;
    final current = ref.watch(currentUserProvider)?.tenant?.storeType == preset.key;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: current
              ? theme.colorScheme.primary
              : (isDark ? AppColors.slate800 : AppColors.slate200),
          width: current ? 1.8 : 1,
        ),
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
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: current
                          ? theme.colorScheme.primary.withValues(alpha: 0.15)
                          : (isDark ? AppColors.slate800 : AppColors.slate100),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _icons[preset.icon] ?? LucideIcons.store,
                      size: 22,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  if (current)
                    const StatusBadge(label: 'Dipakai', tone: BadgeTone.info),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                preset.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  preset.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetPreview extends StatefulWidget {
  const _PresetPreview({
    required this.preset,
    required this.firstRun,
    required this.selectedCategories,
    required this.includeSamples,
    required this.taxEnabled,
    required this.taxRate,
    required this.taxLabel,
    required this.allowCredit,
    required this.allowNegativeStock,
    required this.busy,
    required this.onToggleCategory,
    required this.onSelectAllCategories,
    required this.onClearAllCategories,
    required this.onIncludeSamplesChanged,
    required this.onTaxEnabledChanged,
    required this.onTaxRateChanged,
    required this.onAllowCreditChanged,
    required this.onAllowNegativeStockChanged,
    required this.onApply,
  });

  final StorePreset preset;
  final bool firstRun;
  final Set<String> selectedCategories;
  final bool includeSamples;
  final bool taxEnabled;
  final double taxRate;
  final String taxLabel;
  final bool allowCredit;
  final bool allowNegativeStock;
  final bool busy;

  final ValueChanged<String> onToggleCategory;
  final VoidCallback onSelectAllCategories;
  final VoidCallback onClearAllCategories;
  final ValueChanged<bool> onIncludeSamplesChanged;
  final ValueChanged<bool> onTaxEnabledChanged;
  final ValueChanged<double> onTaxRateChanged;
  final ValueChanged<bool> onAllowCreditChanged;
  final ValueChanged<bool> onAllowNegativeStockChanged;
  final VoidCallback onApply;

  @override
  State<_PresetPreview> createState() => _PresetPreviewState();
}

class _PresetPreviewState extends State<_PresetPreview> {
  late final TextEditingController _taxRateController;

  @override
  void initState() {
    super.initState();
    _taxRateController = TextEditingController(
      text: _formatRate(widget.taxRate),
    );
  }

  @override
  void didUpdateWidget(covariant _PresetPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taxRate != widget.taxRate) {
      final formatted = _formatRate(widget.taxRate);
      if (_taxRateController.text != formatted) {
        _taxRateController.text = formatted;
      }
    }
  }

  static String _formatRate(double rate) {
    return rate.truncateToDouble() == rate ? rate.toStringAsFixed(0) : rate.toString();
  }

  @override
  void dispose() {
    _taxRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final preset = widget.preset;
    final settings = preset.settings;
    final firstRun = widget.firstRun;
    final selectedCategories = widget.selectedCategories;
    final includeSamples = widget.includeSamples;
    final taxEnabled = widget.taxEnabled;
    final taxRate = widget.taxRate;
    final taxLabel = widget.taxLabel;
    final allowCredit = widget.allowCredit;
    final allowNegativeStock = widget.allowNegativeStock;
    final busy = widget.busy;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: MaxWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Preset Info Header Card
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(_icons[preset.icon] ?? LucideIcons.store, size: 24, color: theme.colorScheme.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(preset.label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(
                                  preset.description,
                                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Section 1: Categories
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Kategori Produk (${selectedCategories.length}/${preset.categories.length})',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Row(
                        children: [
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: busy ? null : widget.onSelectAllCategories,
                            child: const Text('Pilih Semua', style: TextStyle(fontSize: 12)),
                          ),
                          const Text(' · ', style: TextStyle(color: Colors.grey)),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: busy ? null : widget.onClearAllCategories,
                            child: const Text('Batal Semua', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final category in preset.categories)
                                _CategoryChip(
                                  category: category,
                                  isSelected: selectedCategories.contains(category),
                                  onTap: busy ? null : () => widget.onToggleCategory(category),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(LucideIcons.info, size: 14, color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Uncheck kategori yang tidak diinginkan. Hanya kategori yang dicentang yang akan dibuat.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (preset.sampleProductCount > 0) ...[
                            const Divider(height: 20),
                            AppSwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: includeSamples,
                              onChanged: busy ? null : widget.onIncludeSamplesChanged,
                              secondary: Icon(
                                LucideIcons.package,
                                color: includeSamples ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                              ),
                              title: const Text('Sertakan produk contoh', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                              subtitle: Text(
                                selectedCategories.length < preset.categories.length
                                    ? 'Hanya produk contoh untuk ${selectedCategories.length} kategori yang dipilih.'
                                    : '${preset.sampleProductCount} produk contoh dengan harga modal & jual awal.',
                                style: const TextStyle(fontSize: 11.5),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Section 2: Customizable POS Settings
                  Row(
                    children: [
                      Text(
                        'Pengaturan Kasir',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Fleksibel',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        children: [
                          // Tax Switch
                          AppSwitchListTile(
                            value: taxEnabled,
                            onChanged: busy ? null : widget.onTaxEnabledChanged,
                            secondary: Icon(
                              LucideIcons.receipt,
                              color: taxEnabled ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                            ),
                            title: Row(
                              children: [
                                const Text('Pajak', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                                const SizedBox(width: 6),
                                Text(
                                  taxEnabled ? '$taxLabel ${quantity(taxRate)}%' : 'Tidak ada',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: taxEnabled ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: const Text('Aktifkan pungutan pajak otomatis di struk kasir.', style: TextStyle(fontSize: 11.5)),
                          ),
                          if (taxEnabled)
                            Padding(
                              padding: const EdgeInsets.only(left: 44, bottom: 8),
                              child: Row(
                                children: [
                                  const Text('Tarif Pajak:', style: TextStyle(fontSize: 12)),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 72,
                                    height: 34,
                                    child: TextField(
                                      controller: _taxRateController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                        suffixText: '%',
                                        isDense: true,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onSubmitted: (val) {
                                        final parsed = double.tryParse(val.replaceAll(',', '.'));
                                        if (parsed != null && parsed >= 0 && parsed <= 100) {
                                          widget.onTaxRateChanged(parsed);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const Divider(height: 12),

                          // Credit Sale Switch
                          AppSwitchListTile(
                            value: allowCredit,
                            onChanged: busy ? null : widget.onAllowCreditChanged,
                            secondary: Icon(
                              LucideIcons.handCoins,
                              color: allowCredit ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                            ),
                            title: const Text('Bolehkan kasbon (piutang)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                            subtitle: const Text('Izinkan metode bayar kasbon/tempo untuk pelanggan.', style: TextStyle(fontSize: 11.5)),
                          ),
                          const Divider(height: 12),

                          // Negative Stock Switch
                          AppSwitchListTile(
                            value: allowNegativeStock,
                            onChanged: busy ? null : widget.onAllowNegativeStockChanged,
                            secondary: Icon(
                              LucideIcons.packageMinus,
                              color: allowNegativeStock ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                            ),
                            title: const Text('Jual saat stok habis / minus', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                            subtitle: const Text('Bolehkan transaksi saat stok sistem 0 atau minus.', style: TextStyle(fontSize: 11.5)),
                          ),
                          const Divider(height: 12),

                          // Summary of other settings
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              children: [
                                InfoRow('Metode bayar', settings.paymentMethods.map((m) => _paymentLabels[m] ?? m).join(', ')),
                                InfoRow('Uang cepat', settings.quickCash.map(thousands).join(' · ')),
                                InfoRow('Footer struk', settings.receiptFooter.isEmpty ? '-' : settings.receiptFooter),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Section 3: Disabled Features (if any)
                  if (preset.disabledFeatures.isNotEmpty) ...[
                    Text(
                      'Modul yang Dimatikan',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      preset.disabledFeatures.map((f) => _featureLabels[f] ?? f).join(', '),
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (!firstRun) ...[
                    Text(
                      'Catatan: Menerapkan preset akan memperbarui pengaturan kasir toko Anda.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Bottom Action Button
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate900 : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? AppColors.slate800 : AppColors.slate200,
              ),
            ),
          ),
          child: MaxWidth(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: busy || selectedCategories.isEmpty ? null : widget.onApply,
              icon: busy
                  ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(LucideIcons.check, size: 18),
              label: const Text(
                'Terapkan',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final String category;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isSelected
          ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.12)
          : (isDark ? AppColors.slate800.withValues(alpha: 0.6) : AppColors.slate100),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          onTap?.call();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.6)
                  : (isDark ? AppColors.slate700.withValues(alpha: 0.5) : AppColors.slate300),
              width: isSelected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? LucideIcons.check : LucideIcons.plus,
                size: 14,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                category,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.white : theme.colorScheme.primary)
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
