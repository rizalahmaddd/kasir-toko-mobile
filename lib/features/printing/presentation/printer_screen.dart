import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/state_views.dart';
import '../printer.dart';

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

class _PrinterScreenState extends ConsumerState<PrinterScreen> {
  List<BluetoothInfo>? _devices;
  String? _error;
  bool _scanning = false;

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final devices = await ref.read(printerServiceProvider).pairedDevices();
      setState(() => _devices = devices);
    } on PrinterException catch (error) {
      setState(() => _error = error.message);
    } on PlatformException catch (error) {
      setState(() => _error = error.message ?? error.code);
    } finally {
      if (mounted) {
        setState(() => _scanning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(printerSettingsProvider);
    final notifier = ref.read(printerSettingsProvider.notifier);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: const Text('Printer struk')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          MaxWidth(
            width: 640,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: ListTile(
                    leading: Icon(settings.isConfigured ? LucideIcons.printerCheck : LucideIcons.printer, size: 22),
                    title: Text(settings.name ?? 'Belum ada printer'),
                    subtitle: Text(settings.address ?? 'Pilih printer Bluetooth thermal di bawah.'),
                    trailing: settings.isConfigured
                        ? IconButton(tooltip: 'Lupakan printer', icon: const Icon(LucideIcons.x, size: 18), onPressed: notifier.forget)
                        : null,
                  ),
                ),
                const SectionTitle('Lebar kertas'),
                SegmentedButton<String>(
                  segments: const [ButtonSegment(value: '58', label: Text('58 mm')), ButtonSegment(value: '80', label: Text('80 mm'))],
                  selected: {settings.paperWidth},
                  onSelectionChanged: (value) => notifier.setPaperWidth(value.first),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cetak otomatis setelah bayar'),
                  subtitle: const Text('Struk langsung keluar begitu transaksi selesai.'),
                  value: settings.autoPrint,
                  onChanged: settings.isConfigured ? notifier.setAutoPrint : null,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: settings.isConfigured ? () => runPrint(context, ref.read(printerServiceProvider).printTest, success: 'Halaman tes dikirim.') : null,
                  icon: const Icon(LucideIcons.fileText, size: 18),
                  label: const Text('Cetak Halaman Tes'),
                ),
                SectionTitle(
                  'Perangkat Bluetooth',
                  trailing: TextButton.icon(
                    onPressed: _scanning ? null : _scan,
                    icon: _scanning
                        ? const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(LucideIcons.refreshCw, size: 16),
                    label: const Text('Cari'),
                  ),
                ),
                Text(
                  'Di Android, pasangkan (pair) printer dulu lewat pengaturan Bluetooth HP. Di iPhone/iPad, printer BLE di dekat Anda akan muncul.',
                  style: TextStyle(color: muted, fontSize: 13),
                ),
                const SizedBox(height: 8),
                if (_error != null)
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))
                else if (_devices == null)
                  const SizedBox.shrink()
                else if (_devices!.isEmpty)
                  const EmptyState(icon: LucideIcons.bluetoothOff, title: 'Tidak ada perangkat', description: 'Nyalakan printer lalu cari lagi.')
                else
                  Card(
                    child: Column(
                      children: [
                        for (final device in _devices!)
                          ListTile(
                            leading: const Icon(LucideIcons.bluetooth, size: 20),
                            title: Text(device.name.isEmpty ? 'Tanpa nama' : device.name),
                            subtitle: Text(device.macAdress),
                            trailing: device.macAdress == settings.address ? const Icon(LucideIcons.check, size: 18) : null,
                            onTap: () async {
                              await notifier.choose(device.macAdress, device.name.isEmpty ? device.macAdress : device.name);
                              if (context.mounted) {
                                showMessage(context, '${device.name} dipilih sebagai printer struk.');
                              }
                            },
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
