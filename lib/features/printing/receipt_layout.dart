import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/formatters.dart';
import '../sales/data/sale_models.dart';
import '../shift/data/shift_models.dart';

enum LineAlign { left, center }

class PrintLine {
  const PrintLine(this.text, {this.bold = false, this.align = LineAlign.left, this.large = false});

  const PrintLine.rule() : text = '\u0000rule', bold = false, align = LineAlign.left, large = false;

  final String text;
  final bool bold;
  final LineAlign align;
  final bool large;

  bool get isRule => text == '\u0000rule';
}

int charsPerLine(String paperWidth) => paperWidth == '80' ? 48 : 32;

/// What the web prints above and below every receipt (Profil Perusahaan + Pengaturan Kasir).
class ReceiptProfile {
  const ReceiptProfile({
    required this.storeName,
    this.address = '',
    this.phone = '',
    this.header = '',
    this.footer = '',
    this.taxLabel = 'Pajak',
    this.paperWidth,
  });

  /// Servers without the `receipt` block still send the store name under `app`.
  factory ReceiptProfile.fromMeta(Map<String, dynamic> meta) {
    final app = meta['app'] as Map<String, dynamic>? ?? const {};
    final receipt = meta['receipt'] as Map<String, dynamic>? ?? const {};
    final company = (app['company_name'] as String?)?.trim();

    return ReceiptProfile.fromJson({
      ...receipt,
      'store_name': receipt['store_name'] ?? (company == null || company.isEmpty ? app['name'] : company),
    });
  }

  factory ReceiptProfile.fromJson(Map<String, dynamic> json) {
    String text(String key) => (json[key] as String? ?? '').trim();
    final width = '${json['paper_width'] ?? ''}';

    return ReceiptProfile(
      storeName: text('store_name').isEmpty ? 'Toko' : text('store_name'),
      address: text('address'),
      phone: text('phone'),
      header: text('header'),
      footer: text('footer'),
      taxLabel: text('tax_label').isEmpty ? 'Pajak' : text('tax_label'),
      paperWidth: width == '58' || width == '80' ? width : null,
    );
  }

  static const cacheKey = 'receipt_profile';

  static ReceiptProfile? cached(SharedPreferences prefs) {
    final raw = prefs.getString(cacheKey);
    if (raw == null) {
      return null;
    }
    try {
      return ReceiptProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return null;
    }
  }

  final String storeName;
  final String address;
  final String phone;
  final String header;
  final String footer;
  final String taxLabel;
  final String? paperWidth;

  Map<String, dynamic> toJson() => {
        'store_name': storeName,
        'address': address,
        'phone': phone,
        'header': header,
        'footer': footer,
        'tax_label': taxLabel,
        'paper_width': paperWidth,
      };
}

String _money(num value) => thousands(value);

/// "Subtotal          156.000" padded to the paper width; long labels wrap onto their own line.
List<String> columns(String left, String right, int width) {
  if (left.length + right.length + 1 <= width) {
    return [left + ' ' * (width - left.length - right.length) + right];
  }

  return [...wrap(left, width), right.padLeft(width)];
}

List<String> wrap(String text, int width) {
  final indent = text.substring(0, text.length - text.trimLeft().length);
  if (indent.isNotEmpty && indent.length < width) {
    return [for (final line in wrap(text.trimLeft(), width - indent.length)) '$indent$line'];
  }

  final lines = <String>[];
  var current = '';
  for (final word in text.split(' ').where((word) => word.isNotEmpty)) {
    if (current.isEmpty) {
      current = word;
    } else if (current.length + 1 + word.length <= width) {
      current += ' $word';
    } else {
      lines.add(current);
      current = word;
    }
    while (current.length > width) {
      lines.add(current.substring(0, width));
      current = current.substring(width);
    }
  }
  if (current.isNotEmpty) {
    lines.add(current);
  }

  return lines;
}

List<PrintLine> _centered(String text, int width) =>
    text.split('\n').expand((line) => wrap(line, width)).map((line) => PrintLine(line, align: LineAlign.center)).toList();

/// Double-size text takes two columns per character, so the store name wraps at half the width.
List<PrintLine> storeHeader(ReceiptProfile profile, int width, {bool showStoreInfo = true, bool showHeader = true}) => [
      for (final line in wrap(profile.storeName, width ~/ 2)) PrintLine(line, bold: true, align: LineAlign.center, large: true),
      if (showStoreInfo && profile.address.isNotEmpty) ..._centered(profile.address, width),
      if (showStoreInfo && profile.phone.isNotEmpty) ..._centered('Telp ${profile.phone}', width),
      if (showHeader && profile.header.isNotEmpty) ..._centered(profile.header, width),
    ];

/// Mirrors the web's thermal receipt (resources/views/print/receipt.blade.php) in plain columns.
List<PrintLine> saleReceipt(SaleDetail sale, {required ReceiptProfile profile, required String paperWidth, bool showStoreInfo = true}) {
  final width = charsPerLine(paperWidth);
  final lines = <PrintLine>[
    ...storeHeader(profile, width, showStoreInfo: showStoreInfo),
    const PrintLine.rule(),
    for (final l in columns('No', sale.number, width)) PrintLine(l),
    for (final l in columns('Tanggal', dateTime(sale.soldAt), width)) PrintLine(l),
    for (final l in columns('Kasir', sale.cashierName, width)) PrintLine(l),
    if (sale.customer != null) for (final l in columns('Pelanggan', sale.customer!.name, width)) PrintLine(l),
    if (sale.isVoided) const PrintLine('*** DIBATALKAN ***', bold: true, align: LineAlign.center),
    const PrintLine.rule(),
  ];

  for (final item in sale.items) {
    lines.addAll(wrap(item.productName, width).map(PrintLine.new));
    lines.addAll(columns('  ${quantity(item.quantity)} x ${_money(item.price)}', _money(item.total + item.discountAmount), width).map(PrintLine.new));
    if (item.discountAmount > 0) {
      lines.addAll(columns('  Diskon', '-${_money(item.discountAmount)}', width).map(PrintLine.new));
    }
    if (item.note != null && item.note!.isNotEmpty) {
      lines.addAll(wrap('  ${item.note}', width).map(PrintLine.new));
    }
  }

  lines
    ..add(const PrintLine.rule())
    ..addAll(columns('Subtotal', _money(sale.subtotal), width).map(PrintLine.new));
  if (sale.discountAmount > 0) {
    final label = sale.discountType == 'percent' ? 'Diskon ${quantity(sale.discountValue)}%' : 'Diskon';
    lines.addAll(columns(label, '-${_money(sale.discountAmount)}', width).map(PrintLine.new));
  }
  if (sale.taxAmount > 0) {
    lines.addAll(columns('${profile.taxLabel} ${quantity(sale.taxRate)}%', _money(sale.taxAmount), width).map(PrintLine.new));
  }
  lines
    ..addAll(columns('TOTAL', rupiah(sale.total), width).map((l) => PrintLine(l, bold: true)))
    ..add(const PrintLine.rule());

  for (final payment in sale.payments.where((p) => p.kind == 'sale')) {
    final amount = payment.method == 'cash' && sale.cashReceived > 0 ? sale.cashReceived : payment.amount;
    lines.addAll(columns(payment.methodLabel, _money(amount), width).map(PrintLine.new));
  }
  if (sale.changeAmount > 0) {
    lines.addAll(columns('Kembali', _money(sale.changeAmount), width).map((l) => PrintLine(l, bold: true)));
  }
  for (final payment in sale.payments.where((p) => p.kind == 'receivable')) {
    lines.addAll(columns('Pelunasan ${dateOnly(payment.paidAt)}', _money(payment.amount), width).map(PrintLine.new));
  }
  if (sale.dueAmount > 0 && !sale.isVoided) {
    lines.addAll(columns('Sisa kasbon', _money(sale.dueAmount), width).map((l) => PrintLine(l, bold: true)));
  }
  if (sale.note != null && sale.note!.trim().isNotEmpty) {
    lines
      ..add(const PrintLine.rule())
      ..addAll(wrap('Catatan: ${sale.note!.trim()}', width).map(PrintLine.new));
  }
  if (profile.footer.isNotEmpty) {
    lines
      ..add(const PrintLine.rule())
      ..addAll(_centered(profile.footer, width));
  }

  return lines;
}

const _methodLabels = {'qris': 'QRIS', 'transfer': 'Transfer', 'card': 'Kartu'};

List<PrintLine> shiftRecap(Shift shift, {required ReceiptProfile profile, required String paperWidth}) {
  final width = charsPerLine(paperWidth);
  final summary = shift.summary;
  List<PrintLine> row(String left, String right, {bool bold = false}) => columns(left, right, width).map((l) => PrintLine(l, bold: bold)).toList();

  return [
    ...storeHeader(profile, width, showStoreInfo: false, showHeader: false),
    const PrintLine('REKAP SHIFT', bold: true, align: LineAlign.center),
    const PrintLine.rule(),
    ...row('No', shift.number),
    ...row('Kasir', shift.cashierName),
    ...row('Buka', dateTime(shift.openedAt)),
    if (shift.closedAt != null) ...row('Tutup', dateTime(shift.closedAt!)),
    const PrintLine.rule(),
    if (summary != null) ...[
      ...row('Modal awal', _money(summary.opening)),
      ...row('Penjualan tunai', _money(summary.cashSales)),
      if (summary.cashReceivables > 0) ...row('Pelunasan tunai', _money(summary.cashReceivables)),
      ...row('Kas masuk', _money(summary.cashIn)),
      ...row('Kas keluar', summary.cashOut > 0 ? '-${_money(summary.cashOut)}' : '0'),
      ...row('Seharusnya', _money(summary.expected), bold: true),
      if (!shift.isOpen) ...[
        ...row('Dihitung', _money(shift.countedCash ?? 0)),
        ...row('Selisih', _money(shift.cashDifference ?? 0), bold: true),
      ],
      const PrintLine.rule(),
      ...row('Transaksi', '${summary.salesCount}'),
      ...row('Total penjualan', _money(summary.salesTotal), bold: true),
      if (summary.voidedCount > 0) ...row('Dibatalkan', '${summary.voidedCount}'),
      for (final entry in summary.nonCash.entries)
        if (entry.value > 0) ...row(_methodLabels[entry.key] ?? entry.key, _money(entry.value)),
    ],
    if (shift.cashMovements.isNotEmpty) ...[
      const PrintLine.rule(),
      for (final m in shift.cashMovements) ...row('${m.isIn ? '+' : '-'} ${m.reason}', _money(m.amount)),
    ],
    const PrintLine(''),
    PrintLine('Dicetak ${dateTime(DateTime.now())}', align: LineAlign.center),
  ];
}

List<PrintLine> testPage(ReceiptProfile profile, {required String paperWidth, bool showStoreInfo = true}) {
  final width = charsPerLine(paperWidth);
  List<PrintLine> row(String left, String right) => columns(left, right, width).map(PrintLine.new).toList();

  return [
    ...storeHeader(profile, width, showStoreInfo: showStoreInfo),
    const PrintLine.rule(),
    const PrintLine('TES PRINTER BERHASIL', bold: true, align: LineAlign.center),
    const PrintLine.rule(),
    ...row('Kertas', '$paperWidth mm'),
    ...row('Karakter per baris', '$width'),
    ...row('Dicetak', dateTime(DateTime.now())),
    const PrintLine.rule(),
    PrintLine('1234567890' * (width ~/ 10) + '1234567890'.substring(0, width % 10)),
    const PrintLine('Teks tebal', bold: true),
    const PrintLine('Rata tengah', align: LineAlign.center),
    const PrintLine('BESAR', large: true, align: LineAlign.center),
  ];
}

/// A believable sale for previewing the layout before anything has been sold.
SaleDetail sampleSale() => SaleDetail.fromJson({
      'id': 0,
      'number': 'TRX-${DateTime.now().year}-000123',
      'status': 'completed',
      'status_label': 'Selesai',
      'sold_at': DateTime.now().toIso8601String(),
      'cashier': {'id': 0, 'name': 'Kasir'},
      'customer': {'id': 0, 'name': 'Bu Sri', 'phone': null},
      'subtotal': 110000,
      'discount_type': 'percent',
      'discount_value': '5',
      'discount_amount': 5500,
      'tax_rate': '0',
      'tax_amount': 0,
      'total': 104500,
      'paid_amount': 104500,
      'cash_received': 110000,
      'change_amount': 5500,
      'due_amount': 0,
      'note': 'Antar ke rumah sore',
      'items': [
        {'product_name': 'Beras Premium 5kg', 'unit': 'karung', 'quantity': '1', 'price': 76000, 'discount_amount': 0, 'total': 76000},
        {'product_name': 'Minyak Goreng 1L', 'unit': 'btl', 'quantity': '2', 'price': 18000, 'discount_amount': 2000, 'total': 34000, 'note': 'merek apa saja'},
      ],
      'payments': [
        {'kind': 'sale', 'method': 'cash', 'method_label': 'Tunai', 'amount': 104500, 'paid_at': DateTime.now().toIso8601String()},
      ],
      'abilities': const {'void': false, 'collect_payment': false},
    });
