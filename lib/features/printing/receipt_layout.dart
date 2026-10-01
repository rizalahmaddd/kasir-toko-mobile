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

/// Mirrors the web's thermal receipt (resources/views/print/receipt.blade.php) in plain columns.
List<PrintLine> saleReceipt(SaleDetail sale, {required String storeName, required String paperWidth, String? footer}) {
  final width = charsPerLine(paperWidth);
  final lines = <PrintLine>[
    PrintLine(storeName, bold: true, align: LineAlign.center, large: true),
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
    lines.addAll(columns('Pajak ${quantity(sale.taxRate)}%', _money(sale.taxAmount), width).map(PrintLine.new));
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
  if (sale.dueAmount > 0) {
    lines.addAll(columns('Sisa kasbon', _money(sale.dueAmount), width).map((l) => PrintLine(l, bold: true)));
  }
  if (footer != null && footer.trim().isNotEmpty) {
    lines
      ..add(const PrintLine(''))
      ..addAll(footer.trim().split('\n').expand((l) => wrap(l, width)).map((l) => PrintLine(l, align: LineAlign.center)));
  }

  return lines;
}

const _methodLabels = {'qris': 'QRIS', 'transfer': 'Transfer', 'card': 'Kartu'};

List<PrintLine> shiftRecap(Shift shift, {required String storeName, required String paperWidth}) {
  final width = charsPerLine(paperWidth);
  final summary = shift.summary;
  List<PrintLine> row(String left, String right, {bool bold = false}) => columns(left, right, width).map((l) => PrintLine(l, bold: bold)).toList();

  return [
    PrintLine(storeName, bold: true, align: LineAlign.center, large: true),
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

/// The footer is the last paragraph of the server's receipt text, present only when the store set one.
String? footerFromReceiptText(String text) {
  final blocks = text.split('\n\n');
  return blocks.length >= 4 ? blocks.last.trim() : null;
}
