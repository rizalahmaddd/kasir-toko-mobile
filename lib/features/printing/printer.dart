import 'dart:convert';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_pos_mobile/core/constants/api_endpoints.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/app_storage.dart';
import '../sales/data/sale_models.dart';
import '../sales/data/sales_repository.dart';
import '../shift/data/shift_models.dart';
import 'receipt_layout.dart';
import '../kitchen/data/kitchen_models.dart';


class PrinterSettings {
  const PrinterSettings({
    this.address,
    this.name,
    this.paperWidth = '58',
    this.autoPrint = false,
    this.copies = 1,
    this.showStoreInfo = true,
    this.cut = true,
    this.feedLines = 3,
  });

  final String? address;
  final String? name;
  final String paperWidth;
  final bool autoPrint;
  final int copies;
  final bool showStoreInfo;
  final bool cut;
  final int feedLines;

  bool get isConfigured => address != null;

  PrinterSettings copyWith({
    String? address,
    String? name,
    String? paperWidth,
    bool? autoPrint,
    int? copies,
    bool? showStoreInfo,
    bool? cut,
    int? feedLines,
  }) =>
      PrinterSettings(
        address: address ?? this.address,
        name: name ?? this.name,
        paperWidth: paperWidth ?? this.paperWidth,
        autoPrint: autoPrint ?? this.autoPrint,
        copies: copies ?? this.copies,
        showStoreInfo: showStoreInfo ?? this.showStoreInfo,
        cut: cut ?? this.cut,
        feedLines: feedLines ?? this.feedLines,
      );

  PrinterSettings withoutDevice() => PrinterSettings(
        paperWidth: paperWidth,
        autoPrint: autoPrint,
        copies: copies,
        showStoreInfo: showStoreInfo,
        cut: cut,
        feedLines: feedLines,
      );
}

final printerSettingsProvider = NotifierProvider<PrinterSettingsNotifier, PrinterSettings>(PrinterSettingsNotifier.new);

class PrinterSettingsNotifier extends Notifier<PrinterSettings> {
  static const _address = 'printer_address';
  static const _name = 'printer_name';
  static const _width = 'printer_width';
  static const _auto = 'printer_auto';
  static const _copies = 'printer_copies';
  static const _storeInfo = 'printer_store_info';
  static const _cut = 'printer_cut';
  static const _feed = 'printer_feed';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  /// Until the cashier picks a width on this device, follow the store's setting from the web.
  @override
  PrinterSettings build() => PrinterSettings(
        address: _prefs.getString(_address),
        name: _prefs.getString(_name),
        paperWidth: _prefs.getString(_width) ?? ReceiptProfile.cached(_prefs)?.paperWidth ?? '58',
        autoPrint: _prefs.getBool(_auto) ?? false,
        copies: _prefs.getInt(_copies) ?? 1,
        showStoreInfo: _prefs.getBool(_storeInfo) ?? true,
        cut: _prefs.getBool(_cut) ?? true,
        feedLines: _prefs.getInt(_feed) ?? 3,
      );

  Future<void> choose(String address, String name) async {
    if (state.address != address) {
      await PrintBluetoothThermal.disconnect.catchError((_) => false);
    }
    await _prefs.setString(_address, address);
    await _prefs.setString(_name, name);
    state = state.copyWith(address: address, name: name);
  }

  Future<void> forget() async {
    await PrintBluetoothThermal.disconnect.catchError((_) => false);
    await _prefs.remove(_address);
    await _prefs.remove(_name);
    state = state.withoutDevice();
  }

  Future<void> setPaperWidth(String width) async {
    await _prefs.setString(_width, width);
    state = state.copyWith(paperWidth: width);
  }

  Future<void> setAutoPrint(bool value) async {
    await _prefs.setBool(_auto, value);
    state = state.copyWith(autoPrint: value);
  }

  Future<void> setCopies(int value) async {
    await _prefs.setInt(_copies, value);
    state = state.copyWith(copies: value);
  }

  Future<void> setShowStoreInfo(bool value) async {
    await _prefs.setBool(_storeInfo, value);
    state = state.copyWith(showStoreInfo: value);
  }

  Future<void> setCut(bool value) async {
    await _prefs.setBool(_cut, value);
    state = state.copyWith(cut: value);
  }

  Future<void> setFeedLines(int value) async {
    await _prefs.setInt(_feed, value);
    state = state.copyWith(feedLines: value);
  }
}

class PrinterException implements Exception {
  const PrinterException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Store identity printed on every receipt, cached so printing still works offline or when /meta is slow.
final receiptProfileProvider = FutureProvider<ReceiptProfile>((ref) async {
  final prefs = ref.read(sharedPreferencesProvider);
  try {
    final data = ApiClient.data(await ref.watch(apiClientProvider).get(ApiEndpoints.meta));
    final profile = ReceiptProfile.fromMeta(data);
    await prefs.setString(ReceiptProfile.cacheKey, jsonEncode(profile.toJson()));
    return profile;
  } on Object {
    return ReceiptProfile.cached(prefs) ?? ReceiptProfile(storeName: prefs.getString(StorageKeys.storeName) ?? PrintingStrings.defaultStoreName);
  }
});

final printerServiceProvider = Provider<PrinterService>((ref) => PrinterService(ref));

class PrinterService {
  PrinterService(this._ref);

  final Ref _ref;

  Future<List<BluetoothInfo>> pairedDevices() async {
    if (!await PrintBluetoothThermal.isPermissionBluetoothGranted) {
      throw const PrinterException(PrintingStrings.permissionNotGranted);
    }
    if (!await PrintBluetoothThermal.bluetoothEnabled) {
      throw const PrinterException(PrintingStrings.bluetoothOff);
    }

    return PrintBluetoothThermal.pairedBluetooths;
  }

  Future<void> printSale(int saleId) async {
    final (sale, profile) = await (_ref.read(salesRepositoryProvider).show(saleId), _ref.read(receiptProfileProvider.future)).wait;

    await printLines(_saleLines(sale, profile));
  }

  Future<void> printDetail(SaleDetail sale) async {
    await printLines(_saleLines(sale, await _ref.read(receiptProfileProvider.future)));
  }

  List<PrintLine> _saleLines(SaleDetail sale, ReceiptProfile profile) {
    final settings = _ref.read(printerSettingsProvider);

    return saleReceipt(sale, profile: profile, paperWidth: settings.paperWidth, showStoreInfo: settings.showStoreInfo);
  }

  Future<void> printKitchenTicket(KitchenTicket ticket) async {
    await printLines(kitchenTicketLines(ticket, paperWidth: _ref.read(printerSettingsProvider).paperWidth), copies: 1);
  }

  Future<void> printDeliveryNote(SaleDetail sale, DeliveryNoteInfo note) async {
    final settings = _ref.read(printerSettingsProvider);
    final profile = await _ref.read(receiptProfileProvider.future);

    await printLines(deliveryNoteLines(sale, note, profile: profile, paperWidth: settings.paperWidth), copies: 2);
  }

  Future<void> printShift(Shift shift) async {
    final settings = _ref.read(printerSettingsProvider);
    final profile = await _ref.read(receiptProfileProvider.future);

    await printLines(shiftRecap(shift, profile: profile, paperWidth: settings.paperWidth), copies: 1);
  }

  Future<void> printTest() async {
    final settings = _ref.read(printerSettingsProvider);
    final profile = await _ref.read(receiptProfileProvider.future);

    await printLines(testPage(profile, paperWidth: settings.paperWidth, showStoreInfo: settings.showStoreInfo), copies: 1);
  }

  Future<void> printLines(List<PrintLine> lines, {int? copies}) async {
    final settings = _ref.read(printerSettingsProvider);
    if (!settings.isConfigured) {
      throw const PrinterException(PrintingStrings.printerNotSelected);
    }
    if (!await PrintBluetoothThermal.isPermissionBluetoothGranted) {
      throw const PrinterException(PrintingStrings.permissionNotGrantedShort);
    }
    if (!await PrintBluetoothThermal.bluetoothEnabled) {
      throw const PrinterException(PrintingStrings.bluetoothOff);
    }
    if (!await PrintBluetoothThermal.connectionStatus && !await PrintBluetoothThermal.connect(macPrinterAddress: settings.address!)) {
      throw PrinterException(PrintingStrings.cannotConnectToPrinter(settings.name ?? 'printer'));
    }

    final bytes = await escPosBytes(lines, settings.paperWidth, feedLines: settings.feedLines, cut: settings.cut);
    for (var copy = 0; copy < (copies ?? settings.copies); copy++) {
      if (!await PrintBluetoothThermal.writeBytes(bytes)) {
        throw const PrinterException(PrintingStrings.sendToPrinterFailed);
      }
    }
  }
}

/// Thermal printers here only speak Latin-1; anything else would make the encoder throw.
String _latin1(String text) => String.fromCharCodes(text.runes.map((r) => r < 256 ? r : 0x3F));

@visibleForTesting
Future<List<int>> escPosBytes(List<PrintLine> lines, String paperWidth, {int feedLines = 3, bool cut = true}) async {
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

  bytes.addAll(generator.feed(feedLines));
  if (cut) {
    bytes.addAll(generator.cut());
  }

  return bytes;
}
