import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:web_pos_mobile/core/constants/app_fonts.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../printer.dart';
import '../receipt_layout.dart';
import 'receipt_preview.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';

/// Runs a print job and reports the outcome in a snackbar.
Future<void> runPrint(BuildContext context, Future<void> Function() job, {String success = PrintingStrings.receiptPrinted}) async {
  try {
    await job();
    if (context.mounted) {
      showMessage(context, success);
    }
  } on PrinterException catch (error) {
    if (context.mounted) {
      showMessage(context, error.message, isError: true);
    }
  } on ApiException catch (error) {
    if (context.mounted) {
      showError(context, error);
    }
  } on PlatformException catch (error) {
    if (context.mounted) {
      showMessage(context, PrintingStrings.printerProblem(error.message ?? error.code), isError: true);
    }
  }
}

class PrinterScreen extends ConsumerStatefulWidget {
  const PrinterScreen({super.key});

  @override
  ConsumerState<PrinterScreen> createState() => _PrinterScreenState();
}

enum _PreviewKind { sale, test }

class _PrinterScreenState extends ConsumerState<PrinterScreen> {
  List<BluetoothInfo>? _devices;
  String? _error;
  bool _scanning = false;
  bool _devicesExpanded = false;
  bool _testingConnection = false;
  _PreviewKind _preview = _PreviewKind.sale;
  late final _sample = sampleSale();

  @override
  void initState() {
    super.initState();
    final hasConfigured = ref.read(printerSettingsProvider).isConfigured;
    _devicesExpanded = !hasConfigured;
    if (!hasConfigured) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
    }
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final devices = await ref.read(printerServiceProvider).pairedDevices();
      if (mounted) {
        setState(() => _devices = devices);
      }
    } on PrinterException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() => _error = error.message ?? error.code);
      }
    } on MissingPluginException {
      if (mounted) {
        setState(() => _error = PrintingStrings.bluetoothUnsupported);
      }
    } finally {
      if (mounted) {
        setState(() => _scanning = false);
      }
    }
  }

  Future<void> _testConnection(PrinterSettings settings) async {
    if (!settings.isConfigured) return;
    setState(() => _testingConnection = true);
    try {
      final isEnabled = await PrintBluetoothThermal.bluetoothEnabled;
      if (!isEnabled) {
        if (mounted) {
          showMessage(context, PrintingStrings.bluetoothPhoneOff, isError: true);
        }
        return;
      }
      final isConnected = await PrintBluetoothThermal.connectionStatus ||
          await PrintBluetoothThermal.connect(macPrinterAddress: settings.address!);
      if (mounted) {
        if (isConnected) {
          showMessage(context, PrintingStrings.printerConnected(settings.name ?? 'struk'));
        } else {
          showMessage(context, PrintingStrings.cannotConnectPrinter(settings.name ?? 'printer'), isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, PrintingStrings.connectionCheckFailed('$e'), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _testingConnection = false);
      }
    }
  }

  Future<void> _choose(BluetoothInfo device) async {
    final name = device.name.isEmpty ? device.macAdress : device.name;
    await ref.read(printerSettingsProvider.notifier).choose(device.macAdress, name);
    if (mounted) {
      setState(() => _devicesExpanded = false);
      showMessage(context, PrintingStrings.printerChosen(name));
    }
  }

  List<PrintLine> _previewLines(PrinterSettings settings, ReceiptProfile profile) => switch (_preview) {
    _PreviewKind.sale => saleReceipt(_sample, profile: profile, paperWidth: settings.paperWidth, showStoreInfo: settings.showStoreInfo),
    _PreviewKind.test => testPage(profile, paperWidth: settings.paperWidth, showStoreInfo: settings.showStoreInfo),
  };

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(printerSettingsProvider);
    final profile = ref.watch(receiptProfileProvider);

    final setup = [
      _StatusCard(
        settings: settings,
        testingConnection: _testingConnection,
        onTestConnection: () => _testConnection(settings),
      ),
      const SizedBox(height: AppSizes.s6),
      if (!_devicesExpanded && settings.isConfigured) ...[
        _devicesCollapsedCard(settings),
      ] else ...[
        SectionTitle(
          PrintingStrings.bluetoothDevicesTitle,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (settings.isConfigured)
                TextButton.icon(
                  onPressed: () => setState(() => _devicesExpanded = false),
                  icon: const Icon(AppIcons.chevronUp, size: AppSizes.s15),
                  label: const Text(PrintingStrings.closeButton),
                ),
              TextButton.icon(
                onPressed: _scanning ? null : _scan,
                icon: _scanning
                    ? const SizedBox.square(dimension: AppSizes.s14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(AppIcons.refreshCw, size: AppSizes.s15),
                label: const Text(PrintingStrings.scanButton),
              ),
            ],
          ),
        ),
        _devicesSection(settings),
      ],
      const SectionTitle(PrintingStrings.paperAndPrintTitle),
      _PrintOptions(settings: settings),
      const SectionTitle(PrintingStrings.receiptContentTitle),
      _ReceiptContent(settings: settings, profile: profile),
    ];

    final preview = [
      const SectionTitle(PrintingStrings.previewTitle),
      SegmentedButton<_PreviewKind>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: _PreviewKind.sale, label: Text(PrintingStrings.saleReceiptPreview)),
          ButtonSegment(value: _PreviewKind.test, label: Text(PrintingStrings.testPagePreview)),
        ],
        selected: {_preview},
        onSelectionChanged: (value) => setState(() => _preview = value.first),
      ),
      const SizedBox(height: AppSizes.s10),
      _Panel(
        color: Theme.of(context).brightness == Brightness.dark ? AppColors.slate950 : AppColors.slate100,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s20),
        child: Column(
          children: [
            ReceiptPreview(
              lines: _previewLines(settings, profile.value ?? const ReceiptProfile(storeName: PrintingStrings.defaultStoreName)),
              paperWidth: settings.paperWidth,
            ),
            const SizedBox(height: AppSizes.s14),
            Text(
              _preview == _PreviewKind.sale
                  ? PrintingStrings.salePreviewNote
                  : PrintingStrings.testPreviewNote,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text(PrintingStrings.printerScreenTitle)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 900) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.s24, AppSpacing.s8, AppSpacing.s12, AppSpacing.s32),
                    children: [Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: setup)],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.s12, AppSpacing.s8, AppSpacing.s24, AppSpacing.s32),
                    children: [Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: preview)],
                  ),
                ),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s8, AppSpacing.s16, AppSpacing.s32),
            children: [
              MaxWidth(
                width: 640,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [...setup, ...preview]),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s8, AppSpacing.s16, AppSpacing.s12),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r12)),
              ),
              onPressed: settings.isConfigured
                  ? () => runPrint(context, ref.read(printerServiceProvider).printTest, success: PrintingStrings.testPageSent)
                  : null,
              icon: const Icon(AppIcons.printer, size: AppSizes.s18),
              label: Text(settings.isConfigured ? PrintingStrings.printTestPageButton : PrintingStrings.selectPrinterFirst),
            ),
          ),
        ),
      ),
    );
  }

  Widget _devicesCollapsedCard(PrinterSettings settings) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.r14),
        border: Border.all(
          color: isDark ? AppColors.slate700 : AppColors.slate200,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.r14),
          onTap: () {
            setState(() => _devicesExpanded = true);
            if (_devices == null && !_scanning) {
              _scan();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.slate700 : AppColors.slate100,
                    borderRadius: BorderRadius.circular(AppRadius.r10),
                  ),
                  child: Icon(AppIcons.bluetooth, size: AppSizes.s18, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: AppSizes.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        PrintingStrings.bluetoothDevicesCount(_devices?.length ?? 0),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                      ),
                      const SizedBox(height: AppSizes.s2),
                      Text(
                        PrintingStrings.printerListHidden,
                        style: TextStyle(fontSize: 11.5, color: muted),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
                  ),
                  onPressed: () {
                    setState(() => _devicesExpanded = true);
                    if (_devices == null && !_scanning) {
                      _scan();
                    }
                  },
                  icon: const Icon(AppIcons.refreshCw, size: AppSizes.s14),
                  label: const Text(PrintingStrings.changePrinterButton),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _devicesSection(PrinterSettings settings) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final hint = Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s10),
      child: Text(
        PrintingStrings.pairPrinterHint,
        style: TextStyle(color: muted, fontSize: 12.5),
      ),
    );

    if (_error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          hint,
          Container(
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.r10)),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13)),
          ),
        ],
      );
    }
    if (_scanning && (_devices == null || _devices!.isEmpty)) {
      return AppShimmer(
        child: Column(
          children: [
            hint,
            for (var i = 0; i < 3; i++)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.s8),
                height: 60,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.slate800 : Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.r12),
                  border: Border.all(
                    color: isDark ? AppColors.slate700 : AppColors.slate200,
                  ),
                ),
              ),
          ],
        ),
      );
    }
    if (_devices == null) {
      return hint;
    }
    if (_devices!.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          hint,
          const EmptyState(
            icon: AppIcons.bluetoothOff,
            title: PrintingStrings.noPairedPrinterTitle,
            description: PrintingStrings.noPairedPrinterDescription,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        hint,
        for (final device in _devices!) _BluetoothDeviceCard(device: device, isSelected: device.macAdress == settings.address, onTap: () => _choose(device)),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.color, this.padding = const EdgeInsets.all(AppSpacing.s16)});

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: color ?? (isDark ? AppColors.slate800 : Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.r16),
        side: BorderSide(color: isDark ? AppColors.slate700 : AppColors.slate200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.settings,
    required this.testingConnection,
    required this.onTestConnection,
  });

  final PrinterSettings settings;
  final bool testingConnection;
  final VoidCallback onTestConnection;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final active = settings.isConfigured;
    final neutral = isDark ? AppColors.slate700 : AppColors.slate100;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        border: Border.all(
          color: active ? AppColors.emerald500.withValues(alpha: 0.4) : (isDark ? AppColors.slate700 : AppColors.slate200),
          width: active ? 1.2 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: active ? AppColors.emerald500.withValues(alpha: 0.15) : neutral,
                  borderRadius: BorderRadius.circular(AppRadius.r12),
                ),
                child: Icon(
                  active ? AppIcons.printerCheck : AppIcons.printer,
                  size: AppSizes.s22,
                  color: active ? AppColors.emerald600 : muted,
                ),
              ),
              const SizedBox(width: AppSizes.s14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            settings.name ?? PrintingStrings.noPrinterLabel,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSizes.s6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: AppSpacing.s1_5),
                          decoration: BoxDecoration(
                            color: active ? AppColors.emerald500.withValues(alpha: 0.12) : neutral,
                            borderRadius: BorderRadius.circular(AppRadius.r5),
                          ),
                          child: Text(
                            active ? PrintingStrings.activeStatus : PrintingStrings.inactiveStatus,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: active ? AppColors.emerald600 : muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.s3),
                    Text(
                      active ? PrintingStrings.printerDetail(settings.address!, settings.paperWidth) : PrintingStrings.selectPrinterHint,
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              if (active)
                Consumer(
                  builder: (context, ref, _) => IconButton.filledTonal(
                    tooltip: PrintingStrings.forgetPrinterTooltip,
                    icon: const Icon(AppIcons.trash2, size: AppSizes.s16),
                    onPressed: () async {
                      if (await confirmAction(
                        context,
                        title: PrintingStrings.forgetPrinterDialogTitle,
                        message: PrintingStrings.forgetPrinterDialogMessage,
                        confirmLabel: PrintingStrings.forgetPrinterConfirm,
                        danger: true,
                      )) {
                        await ref.read(printerSettingsProvider.notifier).forget();
                      }
                    },
                  ),
                ),
            ],
          ),
          if (active) ...[
            const SizedBox(height: AppSizes.s12),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
                backgroundColor: isDark ? AppColors.slate700 : AppColors.slate100,
                foregroundColor: isDark ? AppColors.slate100 : AppColors.slate800,
                side: BorderSide(
                  color: isDark ? AppColors.slate600 : AppColors.slate300,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r10)),
              ),
              onPressed: testingConnection ? null : onTestConnection,
              icon: testingConnection
                  ? const SizedBox.square(dimension: AppSizes.s15, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(AppIcons.radio, size: AppSizes.s16, color: isDark ? AppColors.emerald400 : AppColors.emerald600),
              label: Text(
                testingConnection ? PrintingStrings.checkingPrinter : PrintingStrings.testPrinterConnection,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PrintOptions extends ConsumerWidget {
  const _PrintOptions({required this.settings});

  final PrinterSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(printerSettingsProvider.notifier);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    Widget label(String text, String hint) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Text(hint, style: TextStyle(fontSize: 12, color: muted)),
        ],
      ),
    );
    const divider = Padding(padding: EdgeInsets.symmetric(vertical: AppSpacing.s12), child: Divider(height: 1));

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          label(PrintingStrings.paperWidthLabel, PrintingStrings.paperWidthHint('${charsPerLine(settings.paperWidth)}')),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '58', label: Text(PrintingStrings.paperWidth58)),
              ButtonSegment(value: '80', label: Text(PrintingStrings.paperWidth80)),
            ],
            selected: {settings.paperWidth},
            onSelectionChanged: (value) => notifier.setPaperWidth(value.first),
          ),
          divider,
          label(PrintingStrings.printCountLabel, PrintingStrings.printCountHint),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text(PrintingStrings.copiesOne)),
              ButtonSegment(value: 2, label: Text(PrintingStrings.copiesTwo)),
              ButtonSegment(value: 3, label: Text(PrintingStrings.copiesThree)),
            ],
            selected: {settings.copies},
            onSelectionChanged: (value) => notifier.setCopies(value.first),
          ),
          divider,
          label(PrintingStrings.feedLinesLabel, PrintingStrings.feedLinesHint),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 2, label: Text(PrintingStrings.feedTight)),
              ButtonSegment(value: 3, label: Text(PrintingStrings.feedNormal)),
              ButtonSegment(value: 5, label: Text(PrintingStrings.feedLoose)),
            ],
            selected: {settings.feedLines},
            onSelectionChanged: (value) => notifier.setFeedLines(value.first),
          ),
          const SizedBox(height: AppSizes.s4),
          AppSwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(PrintingStrings.autoCutLabel, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: const Text(PrintingStrings.autoCutHint, style: TextStyle(fontSize: 12)),
            value: settings.cut,
            onChanged: notifier.setCut,
          ),
          AppSwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(PrintingStrings.autoPrintLabel, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text(
              settings.isConfigured ? PrintingStrings.autoPrintEnabledHint : PrintingStrings.autoPrintDisabledHint,
              style: const TextStyle(fontSize: 12),
            ),
            value: settings.autoPrint && settings.isConfigured,
            onChanged: settings.isConfigured ? notifier.setAutoPrint : null,
          ),
        ],
      ),
    );
  }
}

class _ReceiptContent extends ConsumerWidget {
  const _ReceiptContent({required this.settings, required this.profile});

  final PrinterSettings settings;
  final AsyncValue<ReceiptProfile> profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final data = profile.value;
    String orDash(String value) => value.isEmpty ? '-' : value;

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(PrintingStrings.showStoreInfoLabel, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: const Text(PrintingStrings.showStoreInfoHint, style: TextStyle(fontSize: 12)),
            value: settings.showStoreInfo,
            onChanged: ref.read(printerSettingsProvider.notifier).setShowStoreInfo,
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: AppSpacing.s8), child: Divider(height: 1)),
          Row(
            children: [
              Expanded(
                child: Text(
                  PrintingStrings.fromStoreSettings,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: muted),
                ),
              ),
              IconButton(
                tooltip: PrintingStrings.reloadTooltip,
                visualDensity: VisualDensity.compact,
                onPressed: profile.isLoading ? null : () => ref.invalidate(receiptProfileProvider),
                icon: profile.isLoading
                    ? const SizedBox.square(dimension: AppSizes.s14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(AppIcons.refreshCw, size: AppSizes.s16),
              ),
            ],
          ),
          if (data != null) ...[
            InfoRow(PrintingStrings.storeNameLabel, data.storeName),
            InfoRow(PrintingStrings.addressLabel, orDash(data.address)),
            InfoRow(PrintingStrings.phoneLabel, orDash(data.phone)),
            InfoRow(PrintingStrings.receiptHeaderLabel, orDash(data.header)),
            InfoRow(PrintingStrings.receiptFooterLabel, orDash(data.footer)),
          ],
          const SizedBox(height: AppSizes.s8),
          Text(
            PrintingStrings.editOnWebHint,
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ],
      ),
    );
  }
}

class _BluetoothDeviceCard extends StatelessWidget {
  const _BluetoothDeviceCard({required this.device, required this.isSelected, required this.onTap});

  final BluetoothInfo device;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(
          color: isSelected ? AppColors.emerald500 : (isDark ? AppColors.slate700 : AppColors.slate200),
          width: isSelected ? 1.4 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.r12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.emerald500.withValues(alpha: 0.15) : (isDark ? AppColors.slate700 : AppColors.slate100),
                    borderRadius: BorderRadius.circular(AppRadius.r10),
                  ),
                  child: Icon(AppIcons.bluetooth, size: AppSizes.s18, color: isSelected ? AppColors.emerald600 : muted),
                ),
                const SizedBox(width: AppSizes.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(device.name.isEmpty ? PrintingStrings.unnamedDevice : device.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: AppSizes.s2),
                      Text(
                        device.macAdress,
                        style: TextStyle(fontSize: 12, color: muted, fontFamily: AppFonts.monospace),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s3),
                    decoration: BoxDecoration(color: AppColors.emerald500.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.r6)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(AppIcons.check, size: AppSizes.s13, color: AppColors.emerald600),
                        SizedBox(width: AppSizes.s4),
                        Text(
                          PrintingStrings.selectedDevice,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.emerald600),
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    PrintingStrings.selectDevice,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
