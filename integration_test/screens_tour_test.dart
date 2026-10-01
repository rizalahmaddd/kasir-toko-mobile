// Walks the main cashier screens against a live server and saves screenshots:
//   flutter drive --driver test_driver/integration_test.dart --target integration_test/screens_tour_test.dart \
//     --dart-define=API_BASE_URL=http://127.0.0.1:8000 -d <device>
// It opens a shift and records a sale, so point it at a throwaway database.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:web_pos_mobile/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  var shot = 0;

  Future<void> settle(WidgetTester tester, [Duration duration = const Duration(seconds: 2)]) async {
    final end = DateTime.now().add(duration);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> waitFor(WidgetTester tester, Finder finder, {int seconds = 15}) async {
    final end = DateTime.now().add(Duration(seconds: seconds));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
      if (finder.evaluate().isNotEmpty) {
        return;
      }
    }
    throw TestFailure('Timed out waiting for $finder');
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await settle(tester, const Duration(milliseconds: 800));
    shot++;
    await binding.takeScreenshot('${shot.toString().padLeft(2, '0')}_$name');
  }

  testWidgets('tour', (tester) async {
    unawaited(app.main());
    await settle(tester, const Duration(seconds: 3));

    if (find.text('Masuk ke kasir').evaluate().isNotEmpty) {
      await capture(tester, 'login');
      await tester.enterText(find.widgetWithText(TextFormField, 'Username, email, atau nomor HP'), 'kasir');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'password');
      await tester.tap(find.text('Masuk'));
    }

    await waitFor(tester, find.text('Menu'));
    await settle(tester, const Duration(seconds: 3));

    if (find.text('Buka shift dulu').evaluate().isNotEmpty) {
      await capture(tester, 'open_shift');
      await tester.enterText(find.byType(TextField).first, '200000');
      await tester.tap(find.text('Buka Shift'));
      await settle(tester, const Duration(seconds: 3));
    }

    await waitFor(tester, find.text('Semua'));
    await capture(tester, 'catalog');

    await tester.tap(find.text('Air Mineral 600ml'));
    await settle(tester);
    await tester.tap(find.text('Isi Ulang Galon'));
    await settle(tester);
    await tester.tap(find.text('Isi Ulang Galon'));
    await settle(tester);
    await capture(tester, 'cart');

    final payButton = find.textContaining('Bayar Rp');
    if (payButton.evaluate().isEmpty) {
      await tester.tap(find.textContaining(' barang').last);
      await settle(tester);
      await capture(tester, 'cart_sheet');
    }
    await tester.tap(find.textContaining('Bayar Rp').last);
    await settle(tester);
    await capture(tester, 'payment');

    await tester.tap(find.text('Uang pas'));
    await settle(tester);
    await capture(tester, 'payment_filled');
    await tester.tap(find.text('Selesaikan Pembayaran'));
    await waitFor(tester, find.text('Transaksi berhasil'));
    await capture(tester, 'success');

    await tester.tap(find.text('Lihat Struk'));
    await settle(tester, const Duration(seconds: 3));
    await capture(tester, 'receipt');
    await tester.tapAt(const Offset(10, 10));
    await settle(tester);
    if (find.text('Transaksi Baru').evaluate().isNotEmpty) {
      await tester.tap(find.text('Transaksi Baru'));
      await settle(tester);
    }

    await tester.tap(find.text('Transaksi').last);
    await settle(tester, const Duration(seconds: 3));
    await capture(tester, 'sales');

    await tester.tap(find.textContaining('TRX').first);
    await settle(tester, const Duration(seconds: 3));
    await capture(tester, 'sale_detail');

    await tester.tap(find.byType(BackButton));
    await settle(tester);
    await tester.tap(find.text('Beranda').last);
    await settle(tester, const Duration(seconds: 3));
    await capture(tester, 'dashboard');

    await tester.tap(find.text('Menu').last);
    await settle(tester);
    await capture(tester, 'menu');

    await tester.tap(find.text('Shift saya'));
    await settle(tester, const Duration(seconds: 3));
    await capture(tester, 'shift');
  });
}
