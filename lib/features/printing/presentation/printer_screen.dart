import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../printer.dart';
import '../receipt_layout.dart';
import 'receipt_preview.dart';

/// Runs a print job and reports the outcome in a snackbar.
Future<void> runPrint(BuildContext context, Future<void> Function() job, {String success = 'Struk dicetak.'}) async {
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
      showMessage(context, 'Printer bermasalah: ${error.message ?? error.code}', isError: true);
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
  _PreviewKind _preview = _PreviewKind.sale;
  late final _sample = sampleSale();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
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
        setState(() => _error = 'Printer Bluetooth tidak didukung di perangkat ini.');
      }
    } finally {
      if (mounted) {
        setState(() => _scanning = false);
      }
    }
  }

  Future<void> _choose(BluetoothInfo device) async {
    final name = device.name.isEmpty ? device.macAdress : device.name;
    await ref.read(printerSettingsProvider.notifier).choose(device.macAdress, name);
    if (mounted) {
      showMessage(context, '$name dipilih sebagai printer struk.');
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
      _StatusCard(settings: settings),
      const SizedBox(height: 4),
      SectionTitle(
        'Perangkat Bluetooth',
        trailing: TextButton.icon(
          onPressed: _scanning ? null : _scan,
          icon: _scanning
              ? const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(LucideIcons.refreshCw, size: 16),
          label: const Text('Pindai'),
        ),
      ),
      _devicesSection(settings),
      const SectionTitle('Kertas & cetak'),
      _PrintOptions(settings: settings),
      const SectionTitle('Isi struk'),
      _ReceiptContent(settings: settings, profile: profile),
    ];

    final preview = [
      const SectionTitle('Pratinjau'),
      SegmentedButton<_PreviewKind>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: _PreviewKind.sale, label: Text('Struk penjualan')),
          ButtonSegment(value: _PreviewKind.test, label: Text('Halaman tes')),
        ],
        selected: {_preview},
        onSelectionChanged: (value) => setState(() => _preview = value.first),
      ),
      const SizedBox(height: 10),
      _Panel(
        color: Theme.of(context).brightness == Brightness.dark ? AppColors.slate950 : AppColors.slate100,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        child: Column(
          children: [
            ReceiptPreview(
              lines: _previewLines(settings, profile.value ?? const ReceiptProfile(storeName: 'Toko')),
              paperWidth: settings.paperWidth,
            ),
            const SizedBox(height: 14),
            Text(
              _preview == _PreviewKind.sale
                  ? 'Contoh transaksi. Isi struk asli mengikuti data penjualan.'
                  : 'Baris angka harus pas satu baris penuh. Kalau terpotong, ganti lebar kertas.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Printer struk')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 900) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 12, 32),
                    children: [Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: setup)],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 24, 32),
                    children: [Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: preview)],
                  ),
                ),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: settings.isConfigured
                  ? () => runPrint(context, ref.read(printerServiceProvider).printTest, success: 'Halaman tes dikirim ke printer.')
                  : null,
              icon: const Icon(LucideIcons.printer, size: 18),
              label: Text(settings.isConfigured ? 'Cetak halaman tes' : 'Pilih printer dulu untuk tes cetak'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _devicesSection(PrinterSettings settings) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final hint = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        'Nyalakan printer dan pair dulu di pengaturan Bluetooth HP/tablet, lalu pilih dari daftar ini.',
        style: TextStyle(color: muted, fontSize: 12.5),
      ),
    );

    if (_error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          hint,
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13)),
          ),
        ],
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
            icon: LucideIcons.bluetoothOff,
            title: 'Belum ada printer yang di-pair',
            description: 'Pair printer di pengaturan Bluetooth, lalu tekan Pindai.',
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
  const _Panel({required this.child, this.color, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: color ?? (isDark ? AppColors.slate800 : Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? AppColors.slate700 : AppColors.slate200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

class _StatusCard extends ConsumerWidget {
  const _StatusCard({required this.settings});

  final PrinterSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final active = settings.isConfigured;
    final neutral = isDark ? AppColors.slate700 : AppColors.slate100;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? AppColors.emerald500.withValues(alpha: 0.4) : (isDark ? AppColors.slate700 : AppColors.slate200),
          width: active ? 1.2 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: active ? AppColors.emerald500.withValues(alpha: 0.15) : neutral, borderRadius: BorderRadius.circular(12)),
            child: Icon(active ? LucideIcons.printerCheck : LucideIcons.printer, size: 22, color: active ? AppColors.emerald600 : muted),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        settings.name ?? 'Belum ada printer',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(color: active ? AppColors.emerald500.withValues(alpha: 0.12) : neutral, borderRadius: BorderRadius.circular(5)),
                      child: Text(
                        active ? 'Aktif' : 'Nonaktif',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: active ? AppColors.emerald600 : muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  active ? '${settings.address} · ${settings.paperWidth} mm' : 'Pilih printer Bluetooth thermal di bawah.',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
          if (active)
            IconButton.filledTonal(
              tooltip: 'Lupakan printer',
              icon: const Icon(LucideIcons.x, size: 16),
              onPressed: () async {
                if (await confirmAction(
                  context,
                  title: 'Lupakan printer?',
                  message: 'Struk tidak bisa dicetak sampai printer dipilih lagi.',
                  confirmLabel: 'Lupakan',
                )) {
                  await ref.read(printerSettingsProvider.notifier).forget();
                }
              },
            ),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Text(hint, style: TextStyle(fontSize: 12, color: muted)),
        ],
      ),
    );
    const divider = Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1));

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          label('Lebar kertas', '${charsPerLine(settings.paperWidth)} karakter per baris. Kebanyakan printer kasir kecil memakai 58 mm.'),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '58', label: Text('58 mm')),
              ButtonSegment(value: '80', label: Text('80 mm')),
            ],
            selected: {settings.paperWidth},
            onSelectionChanged: (value) => notifier.setPaperWidth(value.first),
          ),
          divider,
          label('Jumlah cetak', 'Berapa lembar struk penjualan yang keluar tiap kali cetak.'),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('1')),
              ButtonSegment(value: 2, label: Text('2')),
              ButtonSegment(value: 3, label: Text('3')),
            ],
            selected: {settings.copies},
            onSelectionChanged: (value) => notifier.setCopies(value.first),
          ),
          divider,
          label('Jarak akhir struk', 'Baris kosong sebelum kertas dipotong atau disobek.'),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 2, label: Text('Rapat')),
              ButtonSegment(value: 3, label: Text('Normal')),
              ButtonSegment(value: 5, label: Text('Longgar')),
            ],
            selected: {settings.feedLines},
            onSelectionChanged: (value) => notifier.setFeedLines(value.first),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Potong kertas otomatis', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: const Text('Matikan kalau printer tidak punya pemotong.', style: TextStyle(fontSize: 12)),
            value: settings.cut,
            onChanged: notifier.setCut,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Cetak otomatis setelah bayar', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text(
              settings.isConfigured ? 'Struk langsung keluar saat transaksi selesai.' : 'Pilih printer dulu untuk mengaktifkan.',
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tampilkan alamat & telepon toko', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: const Text('Matikan supaya struk lebih pendek dan hemat kertas.', style: TextStyle(fontSize: 12)),
            value: settings.showStoreInfo,
            onChanged: ref.read(printerSettingsProvider.notifier).setShowStoreInfo,
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
          Row(
            children: [
              Expanded(
                child: Text(
                  'DARI PENGATURAN TOKO',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: muted),
                ),
              ),
              IconButton(
                tooltip: 'Muat ulang',
                visualDensity: VisualDensity.compact,
                onPressed: profile.isLoading ? null : () => ref.invalidate(receiptProfileProvider),
                icon: profile.isLoading
                    ? const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(LucideIcons.refreshCw, size: 16),
              ),
            ],
          ),
          if (data != null) ...[
            InfoRow('Nama toko', data.storeName),
            InfoRow('Alamat', orDash(data.address)),
            InfoRow('Telepon', orDash(data.phone)),
            InfoRow('Kepala struk', orDash(data.header)),
            InfoRow('Kaki struk', orDash(data.footer)),
          ],
          const SizedBox(height: 8),
          Text(
            'Ubah lewat web: Pengaturan → Profil Perusahaan (nama, alamat, telepon) dan Pengaturan Kasir (kepala & kaki struk).',
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
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFF10B981) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: isSelected ? 1.4 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF10B981).withValues(alpha: 0.15) : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(LucideIcons.bluetooth, size: 18, color: isSelected ? const Color(0xFF059669) : muted),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(device.name.isEmpty ? 'Tanpa nama' : device.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(
                        device.macAdress,
                        style: TextStyle(fontSize: 12, color: muted, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.check, size: 13, color: Color(0xFF059669)),
                        SizedBox(width: 4),
                        Text(
                          'Terpilih',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    'Pilih',
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
