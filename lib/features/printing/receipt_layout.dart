import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';
import 'package:web_pos_mobile/core/constants/status_values.dart';

import '../../core/storage/app_storage.dart';
import '../../core/utils/formatters.dart';
import '../kitchen/data/kitchen_models.dart';
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
    this.outletName = '',
    this.address = '',
    this.phone = '',
    this.header = '',
    this.footer = '',
    this.taxLabel = PrintingStrings.defaultTaxLabel,
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
      storeName: text('store_name').isEmpty ? PrintingStrings.defaultStoreName : text('store_name'),
      outletName: text('outlet_name'),
      address: text('address'),
      phone: text('phone'),
      header: text('header'),
      footer: text('footer'),
      taxLabel: text('tax_label').isEmpty ? PrintingStrings.defaultTaxLabel : text('tax_label'),
      paperWidth: width == '58' || width == '80' ? width : null,
    );
  }

  static const cacheKey = StorageKeys.receiptProfile;

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

  /// Outlet printed under the store name; empty for single-outlet shops.
  final String outletName;
  final String address;
  final String phone;
  final String header;
  final String footer;
  final String taxLabel;
  final String? paperWidth;

  Map<String, dynamic> toJson() => {
        'store_name': storeName,
        'outlet_name': outletName,
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
      if (profile.outletName.isNotEmpty) for (final line in wrap(profile.outletName, width)) PrintLine(line, bold: true, align: LineAlign.center),
      if (showStoreInfo && profile.address.isNotEmpty) ..._centered(profile.address, width),
      if (showStoreInfo && profile.phone.isNotEmpty) ..._centered(PrintingStrings.receiptPhoneLine(profile.phone), width),
      if (showHeader && profile.header.isNotEmpty) ..._centered(profile.header, width),
    ];

/// Mirrors the web's thermal receipt (resources/views/print/receipt.blade.php) in plain columns.
List<PrintLine> saleReceipt(SaleDetail sale, {required ReceiptProfile profile, required String paperWidth, bool showStoreInfo = true}) {
  final width = charsPerLine(paperWidth);
  final lines = <PrintLine>[
    ...storeHeader(profile, width, showStoreInfo: showStoreInfo),
    const PrintLine.rule(),
    for (final l in columns(PrintingStrings.receiptNoLabel, sale.number, width)) PrintLine(l),
    for (final l in columns(PrintingStrings.receiptDateLabel, dateTime(sale.soldAt), width)) PrintLine(l),
    for (final l in columns(PrintingStrings.receiptCashierLabel, sale.cashierName, width)) PrintLine(l),
    if (sale.customer != null) for (final l in columns(PrintingStrings.receiptCustomerLabel, sale.customer!.name, width)) PrintLine(l),
    if (sale.orderLabel != null) for (final l in columns(SalesStrings.orderLabel, sale.orderLabel!, width)) PrintLine(l),
    if (sale.isVoided) const PrintLine(PrintingStrings.receiptVoided, bold: true, align: LineAlign.center),
    const PrintLine.rule(),
  ];

  for (final item in sale.items) {
    lines.addAll(wrap(item.productName, width).map(PrintLine.new));
    lines.addAll(columns('  ${quantity(item.quantity)} x ${_money(item.price)}', _money(item.total + item.discountAmount), width).map(PrintLine.new));
    for (final modifier in item.modifiers) {
      lines.addAll(wrap('  + $modifier', width).map(PrintLine.new));
    }
    if (item.serials.isNotEmpty) {
      lines.addAll(wrap('  SN: ${item.serials.join(', ')}', width).map(PrintLine.new));
    }
    if (item.discountAmount > 0) {
      lines.addAll(columns(PrintingStrings.receiptItemDiscountLabel, '-${_money(item.discountAmount)}', width).map(PrintLine.new));
    }
    if (item.note != null && item.note!.isNotEmpty) {
      lines.addAll(wrap('  ${item.note}', width).map(PrintLine.new));
    }
  }

  lines
    ..add(const PrintLine.rule())
    ..addAll(columns(SalesStrings.subtotal, _money(sale.subtotal), width).map(PrintLine.new));
  if (sale.discountAmount > 0) {
    final label = sale.discountType == DiscountTypes.percent ? PrintingStrings.receiptPercentDiscount(quantity(sale.discountValue)) : PrintingStrings.receiptDiscountLabel;
    lines.addAll(columns(label, '-${_money(sale.discountAmount)}', width).map(PrintLine.new));
  }
  if (sale.serviceChargeAmount > 0) {
    lines.addAll(columns(PosStrings.serviceLabel(quantity(sale.serviceChargeRate)), _money(sale.serviceChargeAmount), width).map(PrintLine.new));
  }
  if (sale.taxAmount > 0) {
    lines.addAll(columns(PrintingStrings.receiptTaxLine(profile.taxLabel, quantity(sale.taxRate)), _money(sale.taxAmount), width).map(PrintLine.new));
  }
  lines
    ..addAll(columns(PrintingStrings.receiptTotalLabel, rupiah(sale.total), width).map((l) => PrintLine(l, bold: true)))
    ..add(const PrintLine.rule());

  for (final payment in sale.payments.where((p) => p.kind == 'deposit')) {
    lines.addAll(columns('DP ${payment.reference ?? ''}'.trim(), _money(payment.amount), width).map(PrintLine.new));
  }
  for (final payment in sale.payments.where((p) => p.kind == PaymentKinds.sale)) {
    final amount = payment.method == PaymentMethods.cash && sale.cashReceived > 0 ? sale.cashReceived : payment.amount;
    lines.addAll(columns(payment.methodLabel, _money(amount), width).map(PrintLine.new));
  }
  if (sale.changeAmount > 0) {
    lines.addAll(columns(PrintingStrings.receiptChangeLabel, _money(sale.changeAmount), width).map((l) => PrintLine(l, bold: true)));
  }
  for (final payment in sale.payments.where((p) => p.kind == PaymentKinds.receivable)) {
    lines.addAll(columns(PrintingStrings.receiptReceivablePayment(dateOnly(payment.paidAt)), _money(payment.amount), width).map(PrintLine.new));
  }
  if (sale.dueAmount > 0 && !sale.isVoided) {
    lines.addAll(columns(PrintingStrings.receiptDueLabel, _money(sale.dueAmount), width).map((l) => PrintLine(l, bold: true)));
  }
  if (sale.note != null && sale.note!.trim().isNotEmpty) {
    lines
      ..add(const PrintLine.rule())
      ..addAll(wrap(PrintingStrings.receiptNote(sale.note!.trim()), width).map(PrintLine.new));
  }
  if (profile.footer.isNotEmpty) {
    lines
      ..add(const PrintLine.rule())
      ..addAll(_centered(profile.footer, width));
  }

  return lines;
}

/// Tiket dapur tanpa harga, nama menu dicetak tebal supaya terbaca dari jauh.
List<PrintLine> kitchenTicketLines(KitchenTicket ticket, {required String paperWidth}) {
  final width = charsPerLine(paperWidth);

  return [
    const PrintLine(PrintingStrings.kitchenTicketTitle, bold: true, align: LineAlign.center),
    for (final line in wrap(ticket.label, width ~/ 2)) PrintLine(line, bold: true, align: LineAlign.center, large: true),
    if (ticket.orderTypeLabel != null) PrintLine(ticket.orderTypeLabel!.toUpperCase(), bold: true, align: LineAlign.center),
    const PrintLine.rule(),
    for (final l in columns(PrintingStrings.receiptDateLabel, dateTime(ticket.createdAt), width)) PrintLine(l),
    if (ticket.saleNumber != null) for (final l in columns(PrintingStrings.receiptNoLabel, ticket.saleNumber!, width)) PrintLine(l),
    if (ticket.cashier != null) for (final l in columns(PrintingStrings.receiptCashierLabel, ticket.cashier!, width)) PrintLine(l),
    const PrintLine.rule(),
    for (final item in ticket.items) ...[
      for (final line in wrap('${quantity(item.quantity)}x ${item.name}', width)) PrintLine(line, bold: true),
      for (final modifier in item.modifiers) ...wrap('  + $modifier', width).map(PrintLine.new),
      if (item.note != null && item.note!.isNotEmpty) ...wrap('  ! ${item.note}', width).map((l) => PrintLine(l, bold: true)),
    ],
  ];
}

/// Surat jalan: penerima, alamat, dan barang tanpa harga, ditutup kolom tanda tangan.
List<PrintLine> deliveryNoteLines(SaleDetail sale, DeliveryNoteInfo note, {required ReceiptProfile profile, required String paperWidth}) {
  final width = charsPerLine(paperWidth);

  return [
    ...storeHeader(profile, width, showHeader: false),
    const PrintLine.rule(),
    const PrintLine(PrintingStrings.deliveryNoteTitle, bold: true, align: LineAlign.center),
    for (final l in columns(PrintingStrings.receiptNoLabel, note.number, width)) PrintLine(l),
    for (final l in columns(PrintingStrings.deliveryNoteSale, sale.number, width)) PrintLine(l),
    for (final l in columns(PrintingStrings.receiptDateLabel, dateOnly(sale.soldAt), width)) PrintLine(l),
    const PrintLine.rule(),
    ...wrap('${PrintingStrings.deliveryNoteTo}: ${note.recipient}', width).map((l) => PrintLine(l, bold: true)),
    if (note.phone != null && note.phone!.isNotEmpty) ...wrap('Telp: ${note.phone}', width).map(PrintLine.new),
    ...wrap(note.address, width).map(PrintLine.new),
    if (note.project != null && note.project!.isNotEmpty) ...wrap('${PrintingStrings.deliveryNoteProject}: ${note.project}', width).map(PrintLine.new),
    if ((note.driver ?? '').isNotEmpty || (note.vehicle ?? '').isNotEmpty)
      ...wrap('${PrintingStrings.deliveryNoteDriver}: ${[note.driver, note.vehicle].whereType<String>().where((s) => s.isNotEmpty).join(' / ')}', width).map(PrintLine.new),
    const PrintLine.rule(),
    for (final item in sale.items) ...[
      ...columns(item.productName, '${quantity(item.quantity)} ${item.unit}', width).map(PrintLine.new),
      if (item.serials.isNotEmpty) ...wrap('  SN: ${item.serials.join(', ')}', width).map(PrintLine.new),
    ],
    const PrintLine.rule(),
    ...columns(PrintingStrings.deliveryNoteSender, PrintingStrings.deliveryNoteReceiver, width).map(PrintLine.new),
    const PrintLine(''),
    const PrintLine(''),
    ...columns('(..........)', '(..........)', width).map(PrintLine.new),
  ];
}

const _methodLabels = {PaymentMethods.qris: PrintingStrings.methodQris, PaymentMethods.transfer: PrintingStrings.methodTransfer, PaymentMethods.card: PrintingStrings.methodCard};

List<PrintLine> shiftRecap(Shift shift, {required ReceiptProfile profile, required String paperWidth}) {
  final width = charsPerLine(paperWidth);
  final summary = shift.summary;
  List<PrintLine> row(String left, String right, {bool bold = false}) => columns(left, right, width).map((l) => PrintLine(l, bold: bold)).toList();

  return [
    ...storeHeader(profile, width, showStoreInfo: false, showHeader: false),
    const PrintLine(PrintingStrings.shiftRecapTitle, bold: true, align: LineAlign.center),
    const PrintLine.rule(),
    ...row(PrintingStrings.receiptNoLabel, shift.number),
    ...row(PrintingStrings.receiptCashierLabel, shift.cashierName),
    ...row(PrintingStrings.receiptOpenedLabel, dateTime(shift.openedAt)),
    if (shift.closedAt != null) ...row(PrintingStrings.receiptClosedLabel, dateTime(shift.closedAt!)),
    const PrintLine.rule(),
    if (summary != null) ...[
      ...row(PrintingStrings.summaryOpening, _money(summary.opening)),
      ...row(PrintingStrings.summaryCashSales, _money(summary.cashSales)),
      if (summary.cashReceivables > 0) ...row(PrintingStrings.summaryCashReceivableSettlement, _money(summary.cashReceivables)),
      ...row(PrintingStrings.summaryCashIn, _money(summary.cashIn)),
      ...row(PrintingStrings.summaryCashOut, summary.cashOut > 0 ? '-${_money(summary.cashOut)}' : '0'),
      ...row(PrintingStrings.summaryExpected, _money(summary.expected), bold: true),
      if (!shift.isOpen) ...[
        ...row(PrintingStrings.summaryCounted, _money(shift.countedCash ?? 0)),
        ...row(PrintingStrings.summaryDifference, _money(shift.cashDifference ?? 0), bold: true),
      ],
      const PrintLine.rule(),
      ...row(PrintingStrings.summaryTransactions, '${summary.salesCount}'),
      ...row(PrintingStrings.summaryTotalSales, _money(summary.salesTotal), bold: true),
      if (summary.voidedCount > 0) ...row(PrintingStrings.summaryVoided, '${summary.voidedCount}'),
      for (final entry in summary.nonCash.entries)
        if (entry.value > 0) ...row(_methodLabels[entry.key] ?? entry.key, _money(entry.value)),
    ],
    if (shift.cashMovements.isNotEmpty) ...[
      const PrintLine.rule(),
      for (final m in shift.cashMovements) ...row('${m.isIn ? '+' : '-'} ${m.reason}', _money(m.amount)),
    ],
    const PrintLine(''),
    PrintLine(PrintingStrings.printedAtLabel(dateTime(DateTime.now())), align: LineAlign.center),
  ];
}

List<PrintLine> testPage(ReceiptProfile profile, {required String paperWidth, bool showStoreInfo = true}) {
  final width = charsPerLine(paperWidth);
  List<PrintLine> row(String left, String right) => columns(left, right, width).map(PrintLine.new).toList();

  return [
    ...storeHeader(profile, width, showStoreInfo: showStoreInfo),
    const PrintLine.rule(),
    const PrintLine(PrintingStrings.testSuccess, bold: true, align: LineAlign.center),
    const PrintLine.rule(),
    ...row(PrintingStrings.testPaperLabel, '$paperWidth mm'),
    ...row(PrintingStrings.testCharsPerLineLabel, '$width'),
    ...row(PrintingStrings.testPrintedLabel, dateTime(DateTime.now())),
    const PrintLine.rule(),
    PrintLine('1234567890' * (width ~/ 10) + '1234567890'.substring(0, width % 10)),
    const PrintLine(PrintingStrings.testBoldText, bold: true),
    const PrintLine(PrintingStrings.testCenteredText, align: LineAlign.center),
    const PrintLine(PrintingStrings.testLargeText, large: true, align: LineAlign.center),
  ];
}

/// A believable sale for previewing the layout before anything has been sold.
SaleDetail sampleSale() => SaleDetail.fromJson({
      'id': 0,
      'number': 'TRX-${DateTime.now().year}-000123',
      'status': SaleStatuses.completed,
      'status_label': 'Selesai',
      'sold_at': DateTime.now().toIso8601String(),
      'cashier': {'id': 0, 'name': 'Kasir'},
      'customer': {'id': 0, 'name': 'Bu Sri', 'phone': null},
      'subtotal': 110000,
      'discount_type': DiscountTypes.percent,
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
        {'kind': PaymentKinds.sale, 'method': PaymentMethods.cash, 'method_label': 'Tunai', 'amount': 104500, 'paid_at': DateTime.now().toIso8601String()},
      ],
      'abilities': const {'void': false, 'collect_payment': false},
    });
