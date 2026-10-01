import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/app_storage.dart';
import '../sales/data/sale_models.dart';
import '../sales/data/sales_repository.dart';
import '../shift/data/shift_models.dart';
import 'receipt_layout.dart';

class PrinterSettings {
  const PrinterSettings({this.address, this.name, this.paperWidth = '58', this.autoPrint = false});

  final String? address;
  final String? name;
  final String paperWidth;
  final bool autoPrint;

  bool get isConfigured => address != null;

  PrinterSettings copyWith({String? address, String? name, String? paperWidth, bool? autoPrint}) => PrinterSettings(
        address: address ?? this.address,
        name: name ?? this.name,
        paperWidth: paperWidth ?? this.paperWidth,
        autoPrint: autoPrint ?? this.autoPrint,
      );
}

final printerSettingsProvider = NotifierProvider<PrinterSettingsNotifier, PrinterSettings>(PrinterSettingsNotifier.new);

class PrinterSettingsNotifier extends Notifier<PrinterSettings> {
  static const _address = 'printer_address';
  static const _name = 'printer_name';
  static const _width = 'printer_width';
  static const _auto = 'printer_auto';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  PrinterSettings build() => PrinterSettings(
        address: _prefs.getString(_address),
        name: _prefs.getString(_name),
        paperWidth: _prefs.getString(_width) ?? '58',
        autoPrint: _prefs.getBool(_auto) ?? false,
      );

  Future<void> choose(String address, String name) async {
    await _prefs.setString(_address, address);
    await _prefs.setString(_name, name);
    state = state.copyWith(address: address, name: name);
  }

  Future<void> forget() async {
    await _prefs.remove(_address);
    await _prefs.remove(_name);
    state = PrinterSettings(paperWidth: state.paperWidth, autoPrint: state.autoPrint);
  }

  Future<void> setPaperWidth(String width) async {
    await _prefs.setString(_width, width);
    state = state.copyWith(paperWidth: width);
  }

  Future<void> setAutoPrint(bool value) async {
    await _prefs.setBool(_auto, value);
    state = state.copyWith(autoPrint: value);
  }
}

class PrinterException implements Exception {
  const PrinterException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Store name for receipt headers, cached so printing still works when /meta is slow.
final storeNameProvider = FutureProvider<String>((ref) async {
  final prefs = ref.read(sharedPreferencesProvider);
  try {
    final app = ApiClient.data(await ref.watch(apiClientProvider).get('meta'))['app'] as Map<String, dynamic>;
    final name = (app['company_name'] as String?)?.trim();
    final resolved = name == null || name.isEmpty ? app['name'] as String? ?? 'Toko' : name;
    await prefs.setString('store_name', resolved);
    return resolved;
  } on Object {
    return prefs.getString('store_name') ?? 'Toko';
  }
});

final printerServiceProvider = Provider<PrinterService>((ref) => PrinterService(ref));

class PrinterService {
  PrinterService(this._ref);

  final Ref _ref;

  Future<List<BluetoothInfo>> pairedDevices() async {
    if (!await PrintBluetoothThermal.isPermissionBluetoothGranted) {
      throw const PrinterException('Izin Bluetooth belum diberikan. Izinkan di pengaturan HP lalu coba lagi.');
    }
    if (!await PrintBluetoothThermal.bluetoothEnabled) {
      throw const PrinterException('Bluetooth mati. Nyalakan Bluetooth lalu coba lagi.');
    }

    return PrintBluetoothThermal.pairedBluetooths;
  }

  Future<void> printSale(int saleId) async {
    final settings = _ref.read(printerSettingsProvider);
    final repository = _ref.read(salesRepositoryProvider);
    final (sale, receipt, storeName) = await (repository.show(saleId), repository.receipt(saleId), _ref.read(storeNameProvider.future)).wait;

    await printLines(
      saleReceipt(sale, storeName: storeName, paperWidth: settings.paperWidth, footer: footerFromReceiptText(receipt.text)),
    );
  }

  Future<void> printDetail(SaleDetail sale) async {
    final settings = _ref.read(printerSettingsProvider);
    final storeName = await _ref.read(storeNameProvider.future);

    await printLines(saleReceipt(sale, storeName: storeName, paperWidth: settings.paperWidth));
  }

  Future<void> printShift(Shift shift) async {
    final settings = _ref.read(printerSettingsProvider);
    final storeName = await _ref.read(storeNameProvider.future);

    await printLines(shiftRecap(shift, storeName: storeName, paperWidth: settings.paperWidth));
  }

  Future<void> printTest() async {
    final settings = _ref.read(printerSettingsProvider);
    final storeName = await _ref.read(storeNameProvider.future);
    final width = charsPerLine(settings.paperWidth);

    await printLines([
      PrintLine(storeName, bold: true, align: LineAlign.center, large: true),
      const PrintLine('Tes printer berhasil', align: LineAlign.center),
      const PrintLine.rule(),
      for (final l in columns('Kertas', '${settings.paperWidth} mm', width)) PrintLine(l),
      for (final l in columns('Karakter per baris', '$width', width)) PrintLine(l),
    ]);
  }

  Future<void> printLines(List<PrintLine> lines) async {
    final settings = _ref.read(printerSettingsProvider);
    if (!settings.isConfigured) {
      throw const PrinterException('Printer belum dipilih. Atur di Menu → Printer struk.');
    }
    if (!await PrintBluetoothThermal.isPermissionBluetoothGranted) {
      throw const PrinterException('Izin Bluetooth belum diberikan.');
    }
    if (!await PrintBluetoothThermal.connectionStatus && !await PrintBluetoothThermal.connect(macPrinterAddress: settings.address!)) {
      throw PrinterException('Tidak bisa terhubung ke ${settings.name ?? 'printer'}. Pastikan printer menyala dan dekat.');
    }

    final bytes = await escPosBytes(lines, settings.paperWidth);
    if (!await PrintBluetoothThermal.writeBytes(bytes)) {
      throw const PrinterException('Gagal mengirim data ke printer. Coba lagi.');
    }
  }
}

/// Thermal printers here only speak Latin-1; anything else would make the encoder throw.
String _latin1(String text) => String.fromCharCodes(text.runes.map((r) => r < 256 ? r : 0x3F));

@visibleForTesting
Future<List<int>> escPosBytes(List<PrintLine> lines, String paperWidth) async {
  final profile = await CapabilityProfile.load();
  final generator = Generator(paperWidth == '80' ? PaperSize.mm80 : PaperSize.mm58, profile);
  final width = charsPerLine(paperWidth);
  final bytes = <int>[...generator.reset()];

  for (final line in lines) {
    if (line.isRule) {
      bytes.addAll(generator.text('-' * width));
      continue;
    }
    bytes.addAll(
      generator.text(
        _latin1(line.text),
        styles: PosStyles(
          bold: line.bold,
          align: line.align == LineAlign.center ? PosAlign.center : PosAlign.left,
          height: line.large ? PosTextSize.size2 : PosTextSize.size1,
          width: line.large ? PosTextSize.size2 : PosTextSize.size1,
        ),
      ),
    );
  }

  return bytes
    ..addAll(generator.feed(3))
    ..addAll(generator.cut());
}
