import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';

import 'package:web_pos_mobile/core/constants/app_routes.dart';
import 'package:web_pos_mobile/core/constants/status_values.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../../../router.dart';
import '../../auth/auth_controller.dart';
import '../onboarding.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

const _icons = {
  'store': AppIcons.store,
  'shopping-basket': AppIcons.shoppingBasket,
  'coffee': AppIcons.coffee,
  'utensils-crossed': AppIcons.utensilsCrossed,
  'shirt': AppIcons.shirt,
  'hammer': AppIcons.hammer,
  'smartphone': AppIcons.smartphone,
  'pill': AppIcons.pill,
  'croissant': AppIcons.croissant,
  'package': AppIcons.package,
};

const _paymentLabels = {
  PaymentMethods.cash: OnboardingStrings.paymentLabelCash,
  PaymentMethods.qris: OnboardingStrings.paymentLabelQris,
  PaymentMethods.transfer: OnboardingStrings.paymentLabelTransfer,
  PaymentMethods.card: OnboardingStrings.paymentLabelCard,
};

const _featureLabels = {
  'pos.receivables': OnboardingStrings.featureLabelReceivables,
  'pos.customer-display': OnboardingStrings.featureLabelCustomerDisplay,
};

/// Store-type picker shown to a new shop owner, and reachable from the menu to re-apply a preset
/// while the shop has no sales yet.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  StorePreset? _selected;
  int _currentStep = 0;
  Set<String> _selectedCategories = {};
  bool _includeSamples = true;
  bool _taxEnabled = false;
  double _taxRate = 11.0;
  String _taxLabel = OnboardingStrings.taxDefaultLabel;
  bool _allowCredit = true;
  bool _allowNegativeStock = false;
  Set<String> _capabilities = {};
  bool _busy = false;

  void _selectPreset(StorePreset preset) {
    setState(() {
      _selected = preset;
      _currentStep = 0;
      _selectedCategories = preset.categories.toSet();
      _includeSamples = preset.sampleProductCount > 0;
      _taxEnabled = preset.settings.taxEnabled;
      _taxRate = preset.settings.taxRate;
      _taxLabel = preset.settings.taxLabel.isNotEmpty ? preset.settings.taxLabel : OnboardingStrings.taxDefaultLabel;
      _allowCredit = preset.settings.allowCredit;
      _allowNegativeStock = preset.settings.allowNegativeStock;
      _capabilities = {for (final capability in preset.capabilities) if (capability.defaultOn) capability.key};
    });
  }

  void _handleBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      setState(() {
        _selected = null;
        _currentStep = 0;
      });
    }
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
      context.go(user == null ? AppRoutes.login : homeFor(user));
    } on Object catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        showError(context, error);
      }
    }
  }

  void _apply(StorePreset preset) {
    if (_selectedCategories.isEmpty) {
      showMessage(context, OnboardingStrings.selectCategoryMin, isError: true);
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
            capabilities: _capabilities.toList(),
          );
      final parts = [
        OnboardingStrings.categoriesCreated(result.categoriesCreated),
        if (_includeSamples && result.productsCreated > 0) OnboardingStrings.sampleProductsCreated(result.productsCreated),
      ];
      final skipped = result.productsSkipped > 0 ? ' ${OnboardingStrings.productsSkipped(result.productsSkipped)}' : '';
      return OnboardingStrings.presetApplied(preset.label, parts.join(OnboardingStrings.createdJoin), skipped);
    });
  }

  void _skip() => _run(() async {
        await ref.read(onboardingActionsProvider).skip();
        return OnboardingStrings.skipMessage;
      });

  @override
  Widget build(BuildContext context) {
    final firstRun = ref.watch(currentUserProvider)?.needsOnboarding ?? false;
    final selected = _selected;

    return PopScope(
      canPop: selected == null && !firstRun,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && selected != null && !_busy) {
          _handleBack();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: selected != null
              ? IconButton(
                  icon: const Icon(AppIcons.arrowLeft),
                  onPressed: _busy ? null : _handleBack,
                )
              : firstRun
                  ? null
                  : const BackButton(),
          title: Text(selected == null ? OnboardingStrings.titlePicker : selected.label),
          actions: [
            if (firstRun && selected == null)
              TextButton(
                onPressed: _busy ? null : () => ref.read(authControllerProvider.notifier).logout(),
                child: const Text(OnboardingStrings.logout),
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
                  currentStep: _currentStep,
                  onStepChanged: (step) => setState(() => _currentStep = step),
                  onBackToPresets: () => setState(() {
                    _selected = null;
                    _currentStep = 0;
                  }),
                  selectedCategories: _selectedCategories,
                  includeSamples: _includeSamples,
                  taxEnabled: _taxEnabled,
                  taxRate: _taxRate,
                  taxLabel: _taxLabel,
                  allowCredit: _allowCredit,
                  allowNegativeStock: _allowNegativeStock,
                  capabilities: _capabilities,
                  onToggleCapability: (key) => setState(() => _capabilities.contains(key) ? _capabilities.remove(key) : _capabilities.add(key)),
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
              padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s16, AppSpacing.s16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      firstRun ? OnboardingStrings.pickerHeadingFirstRun : OnboardingStrings.pickerHeadingChange,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSizes.s4),
                    Text(
                      firstRun ? OnboardingStrings.pickerSubtitleFirstRun : OnboardingStrings.pickerSubtitleChange,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
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
                padding: const EdgeInsets.all(AppSpacing.s16),
                sliver: SliverToBoxAdapter(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: busy ? null : onSkip,
                    child: busy
                        ? const SizedBox.square(dimension: AppSizes.s16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text(OnboardingStrings.skipButton),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSizes.s24)),
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
        borderRadius: BorderRadius.circular(AppRadius.r14),
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
          padding: const EdgeInsets.all(AppSpacing.s14),
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
                      borderRadius: BorderRadius.circular(AppRadius.r10),
                    ),
                    child: Icon(
                      _icons[preset.icon] ?? AppIcons.store,
                      size: AppSizes.s22,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  if (current)
                    const StatusBadge(label: OnboardingStrings.inUseBadge, tone: BadgeTone.info),
                ],
              ),
              const SizedBox(height: AppSizes.s12),
              Text(
                preset.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSizes.s4),
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

enum _WizardStepType {
  categories,
  capabilities,
  settings,
}

class _WizardStepInfo {
  const _WizardStepInfo({
    required this.type,
    required this.title,
    required this.tabLabel,
    required this.subtitle,
  });

  final _WizardStepType type;
  final String title;
  final String tabLabel;
  final String subtitle;
}

class _PresetPreview extends StatefulWidget {
  const _PresetPreview({
    required this.preset,
    required this.firstRun,
    required this.currentStep,
    required this.onStepChanged,
    required this.onBackToPresets,
    required this.selectedCategories,
    required this.includeSamples,
    required this.taxEnabled,
    required this.taxRate,
    required this.taxLabel,
    required this.allowCredit,
    required this.allowNegativeStock,
    required this.capabilities,
    required this.onToggleCapability,
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
  final int currentStep;
  final ValueChanged<int> onStepChanged;
  final VoidCallback onBackToPresets;
  final Set<String> selectedCategories;
  final bool includeSamples;
  final bool taxEnabled;
  final double taxRate;
  final String taxLabel;
  final bool allowCredit;
  final bool allowNegativeStock;
  final bool busy;

  final ValueChanged<String> onToggleCategory;
  final Set<String> capabilities;
  final ValueChanged<String> onToggleCapability;
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
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _taxRateController = TextEditingController(
      text: _formatRate(widget.taxRate),
    );
    _pageController = PageController(initialPage: widget.currentStep);
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
    if (oldWidget.currentStep != widget.currentStep) {
      final steps = _buildSteps(widget.preset);
      final target = widget.currentStep.clamp(0, steps.length - 1);
      if (_pageController.hasClients && _pageController.page?.round() != target) {
        _pageController.animateToPage(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOutCubic,
        );
      }
    }
  }

  static String _formatRate(double rate) {
    return rate.truncateToDouble() == rate ? rate.toStringAsFixed(0) : rate.toString();
  }

  @override
  void dispose() {
    _taxRateController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  List<_WizardStepInfo> _buildSteps(StorePreset preset) {
    return [
      const _WizardStepInfo(
        type: _WizardStepType.categories,
        title: OnboardingStrings.stepCategoriesTitle,
        tabLabel: OnboardingStrings.stepCategoriesTab,
        subtitle: OnboardingStrings.stepCategoriesSubtitle,
      ),
      if (preset.capabilities.isNotEmpty)
        const _WizardStepInfo(
          type: _WizardStepType.capabilities,
          title: BusinessStrings.capabilitiesTitle,
          tabLabel: OnboardingStrings.stepCapabilitiesTab,
          subtitle: OnboardingStrings.stepCapabilitiesSubtitle,
        ),
      const _WizardStepInfo(
        type: _WizardStepType.settings,
        title: OnboardingStrings.stepSettingsTitle,
        tabLabel: OnboardingStrings.stepSettingsTab,
        subtitle: OnboardingStrings.stepSettingsSubtitle,
      ),
    ];
  }

  void _goToStep(int targetStep, List<_WizardStepInfo> steps) {
    if (targetStep < 0 || targetStep >= steps.length) return;
    if (targetStep > 0 && widget.selectedCategories.isEmpty) {
      showMessage(context, OnboardingStrings.selectCategoryMin, isError: true);
      return;
    }
    widget.onStepChanged(targetStep);
  }

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps(widget.preset);
    final clampedStep = widget.currentStep.clamp(0, steps.length - 1);
    final isFirstStep = clampedStep == 0;
    final isLastStep = clampedStep == steps.length - 1;

    return Column(
      children: [
        _WizardStepperHeader(
          steps: steps,
          currentStep: clampedStep,
          onStepTapped: (index) => _goToStep(index, steps),
        ),
        const Divider(height: 1),
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildCategoriesStep(context),
              if (widget.preset.capabilities.isNotEmpty)
                _buildCapabilitiesStep(context),
              _buildSettingsStep(context),
            ],
          ),
        ),
        _buildBottomBar(
          context,
          currentStep: clampedStep,
          isFirstStep: isFirstStep,
          isLastStep: isLastStep,
          steps: steps,
        ),
      ],
    );
  }

  Widget _buildCategoriesStep(BuildContext context) {
    final theme = Theme.of(context);
    final preset = widget.preset;
    final selectedCategories = widget.selectedCategories;
    final includeSamples = widget.includeSamples;
    final busy = widget.busy;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s16, AppSpacing.s20),
      child: MaxWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preset Header Card
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.r12),
                      ),
                      child: Icon(_icons[preset.icon] ?? AppIcons.store, size: AppSizes.s24, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: AppSizes.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(preset.label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: AppSizes.s2),
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
            const SizedBox(height: AppSizes.s16),

            // Categories Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  OnboardingStrings.categoriesSection(selectedCategories.length, preset.categories.length),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Row(
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: busy ? null : widget.onSelectAllCategories,
                      child: const Text(OnboardingStrings.selectAll, style: TextStyle(fontSize: 12)),
                    ),
                    const Text(' · ', style: TextStyle(color: Colors.grey)),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: busy ? null : widget.onClearAllCategories,
                      child: const Text(OnboardingStrings.clearAll, style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSizes.s8),

            // Categories & Sample Products Card
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s14),
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
                    const SizedBox(height: AppSizes.s12),
                    Row(
                      children: [
                        Icon(AppIcons.info, size: AppSizes.s14, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: AppSizes.s6),
                        Expanded(
                          child: Text(
                            OnboardingStrings.categoriesHint,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (preset.sampleProductCount > 0) ...[
                      const Divider(height: 24),
                      AppSwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: includeSamples,
                        onChanged: busy ? null : widget.onIncludeSamplesChanged,
                        secondary: Icon(
                          AppIcons.package,
                          color: includeSamples ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                        ),
                        title: const Text(OnboardingStrings.includeSamplesTitle, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                        subtitle: Text(
                          selectedCategories.length < preset.categories.length
                              ? OnboardingStrings.includeSamplesSubtitlePartial(selectedCategories.length)
                              : OnboardingStrings.includeSamplesSubtitle(preset.sampleProductCount),
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapabilitiesStep(BuildContext context) {
    final theme = Theme.of(context);
    final preset = widget.preset;
    final busy = widget.busy;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s16, AppSpacing.s20),
      child: MaxWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              BusinessStrings.capabilitiesTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSizes.s4),
            Text(
              OnboardingStrings.stepCapabilitiesSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSizes.s14),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s8),
                child: Column(
                  children: [
                    for (int i = 0; i < preset.capabilities.length; i++) ...[
                      if (i > 0) const Divider(height: 16),
                      CheckboxListTile(
                        key: ValueKey('capability-${preset.capabilities[i].key}'),
                        contentPadding: EdgeInsets.zero,
                        value: widget.capabilities.contains(preset.capabilities[i].key),
                        onChanged: busy ? null : (_) => widget.onToggleCapability(preset.capabilities[i].key),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                preset.capabilities[i].label,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                              ),
                            ),
                            if (preset.capabilities[i].defaultOn) ...[
                              const SizedBox(width: AppSizes.s6),
                              const StatusBadge(label: BusinessStrings.recommended, tone: BadgeTone.success),
                            ],
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.s4),
                          child: Text(
                            preset.capabilities[i].description,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSizes.s12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(AppIcons.info, size: AppSizes.s14, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: AppSizes.s6),
                Expanded(
                  child: Text(
                    BusinessStrings.capabilitiesHint,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsStep(BuildContext context) {
    final theme = Theme.of(context);
    final preset = widget.preset;
    final settings = preset.settings;
    final firstRun = widget.firstRun;
    final taxEnabled = widget.taxEnabled;
    final taxRate = widget.taxRate;
    final taxLabel = widget.taxLabel;
    final allowCredit = widget.allowCredit;
    final allowNegativeStock = widget.allowNegativeStock;
    final busy = widget.busy;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s16, AppSpacing.s20),
      child: MaxWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  OnboardingStrings.settingsSection,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppSizes.s8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: AppSpacing.s2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.r6),
                  ),
                  child: Text(
                    OnboardingStrings.settingsFlexibleBadge,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.s4),
            Text(
              OnboardingStrings.stepSettingsSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSizes.s12),

            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
                child: Column(
                  children: [
                    // Tax Switch
                    AppSwitchListTile(
                      value: taxEnabled,
                      onChanged: busy ? null : widget.onTaxEnabledChanged,
                      secondary: Icon(
                        AppIcons.receipt,
                        color: taxEnabled ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                      ),
                      title: Row(
                        children: [
                          const Text(OnboardingStrings.taxTitle, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                          const SizedBox(width: AppSizes.s6),
                          Text(
                            taxEnabled ? OnboardingStrings.taxSummary(taxLabel, quantity(taxRate)) : OnboardingStrings.taxNone,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: taxEnabled ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      subtitle: const Text(OnboardingStrings.taxSubtitle, style: TextStyle(fontSize: 11.5)),
                    ),
                    if (taxEnabled)
                      Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.s44, bottom: AppSpacing.s8),
                        child: Row(
                          children: [
                            const Text(OnboardingStrings.taxRateLabel, style: TextStyle(fontSize: 12)),
                            const SizedBox(width: AppSizes.s8),
                            SizedBox(
                              width: 72,
                              height: 34,
                              child: TextField(
                                controller: _taxRateController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: AppSpacing.s8),
                                  suffixText: '%',
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.r8)),
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
                        AppIcons.handCoins,
                        color: allowCredit ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                      ),
                      title: const Text(OnboardingStrings.creditTitle, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                      subtitle: const Text(OnboardingStrings.creditSubtitle, style: TextStyle(fontSize: 11.5)),
                    ),
                    const Divider(height: 12),

                    // Negative Stock Switch
                    AppSwitchListTile(
                      value: allowNegativeStock,
                      onChanged: busy ? null : widget.onAllowNegativeStockChanged,
                      secondary: Icon(
                        AppIcons.packageMinus,
                        color: allowNegativeStock ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                      ),
                      title: const Text(OnboardingStrings.negativeStockTitle, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                      subtitle: const Text(OnboardingStrings.negativeStockSubtitle, style: TextStyle(fontSize: 11.5)),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSizes.s14),

            // Summary Info Card
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      OnboardingStrings.presetSummaryTitle,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSizes.s8),
                    InfoRow(OnboardingStrings.paymentMethodLabel, settings.paymentMethods.map((m) => _paymentLabels[m] ?? m).join(', ')),
                    InfoRow(OnboardingStrings.quickCashLabel, settings.quickCash.map(thousands).join(' · ')),
                    InfoRow(OnboardingStrings.receiptFooterLabel, settings.receiptFooter.isEmpty ? '-' : settings.receiptFooter),
                  ],
                ),
              ),
            ),

            if (preset.disabledFeatures.isNotEmpty) ...[
              const SizedBox(height: AppSizes.s14),
              Text(
                OnboardingStrings.disabledModulesTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppSizes.s6),
              Text(
                preset.disabledFeatures.map((f) => _featureLabels[f] ?? f).join(', '),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],

            if (!firstRun) ...[
              const SizedBox(height: AppSizes.s14),
              Text(
                OnboardingStrings.applyNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context, {
    required int currentStep,
    required bool isFirstStep,
    required bool isLastStep,
    required List<_WizardStepInfo> steps,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final busy = widget.busy;
    final selectedCategories = widget.selectedCategories;

    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s10, AppSpacing.s16, AppSpacing.s16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.slate800 : AppColors.slate200,
          ),
        ),
      ),
      child: MaxWidth(
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r12)),
                ),
                onPressed: busy
                    ? null
                    : () {
                        if (currentStep > 0) {
                          _goToStep(currentStep - 1, steps);
                        } else {
                          widget.onBackToPresets();
                        }
                      },
                child: const Text(OnboardingStrings.prevButton),
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r12)),
                ),
                onPressed: busy || (isFirstStep && selectedCategories.isEmpty)
                    ? null
                    : () {
                        if (isLastStep) {
                          widget.onApply();
                        } else {
                          _goToStep(currentStep + 1, steps);
                        }
                      },
                icon: busy
                    ? const SizedBox.square(dimension: AppSizes.s16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(isLastStep ? AppIcons.check : AppIcons.arrowRight, size: AppSizes.s18),
                label: Text(
                  isLastStep ? OnboardingStrings.applyButton : OnboardingStrings.nextButton,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WizardStepperHeader extends StatelessWidget {
  const _WizardStepperHeader({
    required this.steps,
    required this.currentStep,
    required this.onStepTapped,
  });

  final List<_WizardStepInfo> steps;
  final int currentStep;
  final ValueChanged<int> onStepTapped;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeInfo = steps[currentStep.clamp(0, steps.length - 1)];

    return Container(
      color: isDark ? AppColors.slate900 : Colors.white,
      padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s10, AppSpacing.s16, AppSpacing.s10),
      child: MaxWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (int i = 0; i < steps.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: _StepIndicatorPill(
                      index: i,
                      isActive: i == currentStep,
                      isCompleted: i < currentStep,
                      label: steps[i].tabLabel,
                      onTap: () => onStepTapped(i),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSizes.s8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.r6),
                  ),
                  child: Text(
                    OnboardingStrings.stepCounter(currentStep + 1, steps.length),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.s8),
                Expanded(
                  child: Text(
                    activeInfo.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepIndicatorPill extends StatelessWidget {
  const _StepIndicatorPill({
    required this.index,
    required this.isActive,
    required this.isCompleted,
    required this.label,
    required this.onTap,
  });

  final int index;
  final bool isActive;
  final bool isCompleted;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color bgColor;
    final Color borderColor;
    final Color textColor;
    final Color badgeBg;
    final Color badgeText;

    if (isActive) {
      bgColor = theme.colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.12);
      borderColor = theme.colorScheme.primary;
      textColor = theme.colorScheme.primary;
      badgeBg = theme.colorScheme.primary;
      badgeText = Colors.white;
    } else if (isCompleted) {
      bgColor = isDark ? AppColors.slate800 : AppColors.slate100;
      borderColor = theme.colorScheme.primary.withValues(alpha: 0.4);
      textColor = isDark ? AppColors.slate200 : AppColors.slate700;
      badgeBg = theme.colorScheme.primary.withValues(alpha: 0.2);
      badgeText = theme.colorScheme.primary;
    } else {
      bgColor = isDark ? AppColors.slate950 : AppColors.slate50;
      borderColor = isDark ? AppColors.slate800 : AppColors.slate200;
      textColor = theme.colorScheme.onSurfaceVariant;
      badgeBg = isDark ? AppColors.slate800 : AppColors.slate200;
      badgeText = theme.colorScheme.onSurfaceVariant;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.r8),
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          onTap();
        },
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppRadius.r8),
            border: Border.all(color: borderColor, width: isActive ? 1.5 : 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 17,
                height: 17,
                decoration: BoxDecoration(
                  color: badgeBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: isCompleted
                    ? Icon(AppIcons.check, size: 10, color: badgeText)
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: badgeText,
                          height: 1,
                        ),
                      ),
              ),
              const SizedBox(width: AppSizes.s4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                    color: textColor,
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
      borderRadius: BorderRadius.circular(AppRadius.r10),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.r10),
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          onTap?.call();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.r10),
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
                isSelected ? AppIcons.check : AppIcons.plus,
                size: AppSizes.s14,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSizes.s6),
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
