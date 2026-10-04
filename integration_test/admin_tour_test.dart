// Visits every back-office screen as an admin and saves screenshots:
//   flutter drive --driver test_driver/integration_test.dart --target integration_test/admin_tour_test.dart \
//     --dart-define=API_BASE_URL=http://127.0.0.1:8000 -d <device>
// Read-only apart from logging in, but still point it at a throwaway database.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:web_pos_mobile/features/auth/auth_controller.dart';
import 'package:web_pos_mobile/main.dart' as app;
import 'package:web_pos_mobile/router.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  var shot = 0;

  Future<void> settle(WidgetTester tester, [Duration duration = const Duration(seconds: 2)]) async {
    final end = DateTime.now().add(duration);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await settle(tester);
    shot++;
    await binding.takeScreenshot('${shot.toString().padLeft(2, '0')}_$name');
  }

  testWidgets('admin tour', (tester) async {
    unawaited(app.main());
    await settle(tester, const Duration(seconds: 3));

    final container = ProviderScope.containerOf(tester.element(find.byType(app.KasirApp)));
    final router = container.read(routerProvider);

    if (find.text('Masuk ke kasir').evaluate().isEmpty) {
      await container.read(authControllerProvider.notifier).logout();
      await settle(tester);
    }

    await tester.enterText(find.widgetWithText(TextFormField, 'Username, email, atau nomor HP'), 'admin');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'password');
    await tester.tap(find.text('Masuk'));
    await settle(tester, const Duration(seconds: 4));

    Future<void> visit(String path, String name, {bool push = true}) async {
      push ? unawaited(router.push(path)) : router.go(path);
      await capture(tester, name);
    }

    await visit('/dashboard', 'dashboard', push: false);
    await visit('/products', 'products', push: false);
    await visit('/product/12', 'product_detail');
    router.pop();
    await visit('/product/12/edit', 'product_edit');
    router.pop();
    await visit('/menu', 'menu', push: false);
    await visit('/categories', 'categories');
    router.pop();
    await visit('/stock', 'stock');
    router.pop();
    await visit('/stock/movements', 'movements');
    router.pop();
    await visit('/customers', 'customers');
    router.pop();
    await visit('/customer/1', 'customer_detail');
    router.pop();
    await visit('/receivables', 'receivables');
    router.pop();
    await visit('/shifts', 'shifts');
    router.pop();
    await visit('/shift/1', 'shift_detail');
    router.pop();
    await visit('/reports/sales', 'report_overview');
    await tester.tap(find.text('Harian'));
    await capture(tester, 'report_daily');
    await tester.tap(find.text('Produk').last);
    await capture(tester, 'report_products');
    router.pop();
    await visit('/activity', 'activity');
    router.pop();
    await visit('/notifications', 'notifications');
    router.pop();
    await visit('/search', 'search');
    await tester.enterText(find.byType(TextField).first, 'beras');
    await capture(tester, 'search_results');
    router.pop();
    await visit('/account', 'account');
    router.pop();
    await visit('/printer', 'printer');
    router.pop();
    await settle(tester);
  });
}
