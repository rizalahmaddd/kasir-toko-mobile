import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:web_pos_mobile/features/printing/printer.dart';
import 'package:web_pos_mobile/features/printing/receipt_layout.dart';
import 'package:web_pos_mobile/features/sales/data/sale_models.dart';

Map<String, dynamic> _json({int due = 0, int change = 4000}) => {
      'id': 1,
      'number': 'TRX-2026-000001',
      'status': due > 0 ? 'completed' : 'completed',
      'status_label': 'Selesai',
      'sold_at': '2026-10-01T10:15:00+07:00',
      'cashier': {'id': 1, 'name': 'Kasir Demo'},
      'customer': due > 0 ? {'id': 9, 'name': 'Bu Sri', 'phone': null} : null,
      'subtotal': 156000,
      'discount_type': 'percent',
      'discount_value': '5',
      'discount_amount': 7800,
      'tax_rate': '0',
      'tax_amount': 0,
      'total': 148200,
      'paid_amount': 148200 - due,
      'cash_received': 152200 - due,
      'change_amount': change,
      'due_amount': due,
      'items': [
        {'product_name': 'Beras Premium 5kg Kualitas Super Pulen Wangi', 'unit': 'karung', 'quantity': '2', 'price': 76000, 'discount_amount': 0, 'total': 152000},
        {'product_name': 'Air Mineral', 'unit': 'btl', 'quantity': '1', 'price': 4000, 'discount_amount': 0, 'total': 4000, 'note': 'dingin'},
      ],
      'payments': [
        {'kind': 'sale', 'method': 'cash', 'method_label': 'Tunai', 'amount': 148200 - due, 'paid_at': '2026-10-01T10:15:00+07:00'},
      ],
      'abilities': {'void': false, 'collect_payment': due > 0},
    };

SaleDetail _sale({int due = 0, int change = 4000}) => SaleDetail.fromJson(_json(due: due, change: change));

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test('columns pad to the paper width and wrap long labels', () {
    expect(columns('Total', '148.200', 32), ['Total${' ' * 20}148.200']);
    expect(columns('Total', '148.200', 32).single.length, 32);

    final wrapped = columns('Pelunasan tunai kasbon pelanggan lama', '1.000.000', 32);
    expect(wrapped.last, '1.000.000'.padLeft(32));
    expect(wrapped.every((line) => line.length <= 32), isTrue);
  });

  test('wrap splits words and hard-breaks words longer than the line', () {
    expect(wrap('Beras Premium 5kg Kualitas Super', 16), ['Beras Premium', '5kg Kualitas', 'Super']);
    expect(wrap('ABCDEFGHIJKLMNOPQRST', 8), ['ABCDEFGH', 'IJKLMNOP', 'QRST']);
  });

  test('sale receipt fits 58 mm paper and carries totals, change and footer', () {
    final lines = saleReceipt(_sale(), profile: const ReceiptProfile(storeName: 'Toko Sumber Rejeki', footer: 'Terima kasih'), paperWidth: '58');
    final text = lines.where((l) => !l.isRule).map((l) => l.text).toList();

    expect(lines.where((l) => !l.isRule && !l.large).every((l) => l.text.length <= 32), isTrue);
    expect(lines.where((l) => l.large).every((l) => l.text.length <= 16), isTrue);
    expect(text, contains('Diskon 5%${' ' * 17}-7.800'));
    expect(text.any((l) => l.startsWith('TOTAL') && l.endsWith('Rp148.200')), isTrue);
    expect(text.any((l) => l.startsWith('Kembali') && l.endsWith('4.000')), isTrue);
    expect(text, contains('  dingin'));
    expect(text.last, 'Terima kasih');
  });

  test('credit sale shows the customer and remaining debt', () {
    final text = saleReceipt(_sale(due: 50000, change: 0), profile: const ReceiptProfile(storeName: 'Toko'), paperWidth: '80').map((l) => l.text).toList();

    expect(text.any((l) => l.startsWith('Pelanggan') && l.endsWith('Bu Sri')), isTrue);
    expect(text.any((l) => l.startsWith('Sisa kasbon') && l.endsWith('50.000')), isTrue);
    expect(text.any((l) => l.startsWith('Kembali')), isFalse);
  });

  test('store header carries address, phone and the web receipt header', () {
    const profile = ReceiptProfile(
      storeName: 'Toko Sumber Rejeki',
      address: 'Jl. Merdeka 10, Malang',
      phone: '0341-123456',
      header: 'Buka 07.00 - 21.00',
      taxLabel: 'PPN',
    );
    final text = storeHeader(profile, 32).map((l) => l.text).toList();

    expect(text, ['Toko Sumber', 'Rejeki', 'Jl. Merdeka 10, Malang', 'Telp 0341-123456', 'Buka 07.00 - 21.00']);
    expect(storeHeader(profile, 32, showStoreInfo: false).map((l) => l.text), ['Toko Sumber', 'Rejeki', 'Buka 07.00 - 21.00']);
  });

  test('sale note is printed and voided sales drop the remaining debt', () {
    final sale = SaleDetail.fromJson({..._json(due: 50000, change: 0), 'status': 'voided', 'note': 'Antar sore'});
    final text = saleReceipt(sale, profile: const ReceiptProfile(storeName: 'Toko'), paperWidth: '58').map((l) => l.text).toList();

    expect(text, contains('Catatan: Antar sore'));
    expect(text, contains('*** DIBATALKAN ***'));
    expect(text.any((l) => l.startsWith('Sisa kasbon')), isFalse);
  });

  test('receipt profile falls back to the app block on older servers', () {
    final profile = ReceiptProfile.fromMeta({
      'app': {'name': 'Kasir Toko', 'company_name': ' '},
    });

    expect(profile.storeName, 'Kasir Toko');
    expect(profile.taxLabel, 'Pajak');
    expect(profile.paperWidth, isNull);

    final full = ReceiptProfile.fromMeta({
      'app': {'name': 'Kasir Toko', 'company_name': 'Toko Rejeki'},
      'receipt': {'store_name': 'Toko Rejeki', 'footer': 'Terima kasih', 'tax_label': 'PPN', 'paper_width': '80'},
    });
    expect(ReceiptProfile.fromJson(full.toJson()).toJson(), full.toJson());
    expect(full.paperWidth, '80');
  });

  test('sample sale preview balances like a real receipt', () {
    final sale = sampleSale();

    expect(sale.items.fold<int>(0, (sum, item) => sum + item.total), sale.subtotal);
    expect(sale.subtotal - sale.discountAmount, sale.total);
    expect(sale.cashReceived - sale.total, sale.changeAmount);
  });

  test('test page fills exactly one line with the ruler', () {
    for (final width in ['58', '80']) {
      final ruler = testPage(const ReceiptProfile(storeName: 'Toko'), paperWidth: width).firstWhere((l) => l.text.startsWith('1234'));
      expect(ruler.text.length, charsPerLine(width));
    }
  });

  testWidgets('ESC/POS bytes start with init, end with cut, and survive non-Latin text', (tester) async {
    final bytes = (await tester.runAsync(() => escPosBytes([const PrintLine('Kopi ☕ susu', bold: true), const PrintLine.rule()], '58')))!;

    expect(bytes.take(2), [0x1B, 0x40]);
    expect(bytes.sublist(bytes.length - 3), [0x1D, 0x56, 0x30]);
    expect(String.fromCharCodes(bytes).contains('Kopi ? susu'), isTrue);

    final uncut = (await tester.runAsync(() => escPosBytes([const PrintLine('Tes')], '58', cut: false)))!;
    expect(uncut.sublist(uncut.length - 3), isNot([0x1D, 0x56, 0x30]));
  });
}
