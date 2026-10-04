// Sells while the server is unreachable, then reconnects and checks the sale reaches the server:
//   flutter drive --driver test_driver/integration_test.dart --target integration_test/offline_flow_test.dart \
//     --dart-define=API_BASE_URL=http://127.0.0.1:8000 -d <device>
// It records a sale on the cashier's open shift, so point it at a throwaway database.
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:web_pos_mobile/core/network/api_client.dart';
import 'package:web_pos_mobile/features/auth/auth_controller.dart';
import 'package:web_pos_mobile/features/offline/catalog_snapshot.dart';
import 'package:web_pos_mobile/features/offline/offline_queue.dart';
import 'package:web_pos_mobile/features/pos/pos_providers.dart';
import 'package:web_pos_mobile/features/sales/data/sales_repository.dart';
import 'package:web_pos_mobile/features/shift/shift_controller.dart';
import 'package:web_pos_mobile/main.dart' as app;
import 'package:web_pos_mobile/router.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  var shot = 0;
  var offline = false;

  Future<void> settle(WidgetTester tester, [Duration duration = const Duration(seconds: 2)]) async {
    final end = DateTime.now().add(duration);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await settle(tester, const Duration(milliseconds: 800));
    shot++;
    await binding.takeScreenshot('${shot.toString().padLeft(2, '0')}_$name');
  }

  testWidgets('sell offline, sync when back online', (tester) async {
    unawaited(app.main());
    await settle(tester, const Duration(seconds: 3));

    final container = ProviderScope.containerOf(tester.element(find.byType(app.KasirApp)));
    final router = container.read(routerProvider);

    if (container.read(currentUserProvider)?.username != 'kasir') {
      if (container.read(currentUserProvider) != null) {
        await container.read(authControllerProvider.notifier).logout();
        await settle(tester);
      }
      await tester.enterText(find.widgetWithText(TextFormField, 'Username, email, atau nomor HP'), 'kasir');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'password');
      await tester.tap(find.text('Masuk'));
      await settle(tester, const Duration(seconds: 4));
    }

    router.go('/pos');
    await settle(tester, const Duration(seconds: 3));
    expect(container.read(currentShiftProvider).value, isNotNull, reason: 'kasir needs an open shift on the test database');

    await container.read(catalogSnapshotProvider.notifier).download();
    await container.read(posConfigProvider.future);
    final salesBefore = (await container.read(salesRepositoryProvider).list(from: DateTime.now(), to: DateTime.now())).count;

    container.read(dioProvider).interceptors.insert(
          0,
          InterceptorsWrapper(
            onRequest: (options, handler) => offline
                ? handler.reject(DioException(requestOptions: options, type: DioExceptionType.connectionError), true)
                : handler.next(options),
          ),
        );
    offline = true;
    container
      ..invalidate(posConfigProvider)
      ..invalidate(posCategoriesProvider)
      ..invalidate(catalogProvider)
      ..invalidate(currentShiftProvider);
    await settle(tester, const Duration(seconds: 3));
    await capture(tester, 'pos_offline');

    await tester.tap(find.text('Air Mineral 600ml'));
    await settle(tester);
    final payButton = find.textContaining('Bayar Rp');
    if (payButton.evaluate().isEmpty) {
      await tester.tap(find.textContaining(' barang').last);
      await settle(tester);
    }
    await tester.tap(find.textContaining('Bayar Rp').last);
    await settle(tester);
    await tester.tap(find.text('Uang pas'));
    await settle(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('Selesaikan Pembayaran'));
    await settle(tester, const Duration(seconds: 3));
    expect(find.text('Tersimpan di perangkat'), findsOneWidget);
    await capture(tester, 'offline_saved');
    await tester.tap(find.text('Transaksi Baru'));
    await settle(tester);

    expect(container.read(myQueueProvider), hasLength(1));
    unawaited(router.push('/offline'));
    await capture(tester, 'offline_queue');

    offline = false;
    final sent = await container.read(offlineQueueProvider.notifier).sync();
    await settle(tester);
    await capture(tester, 'synced');

    expect(sent, 1);
    expect(container.read(myQueueProvider), isEmpty);
    final salesAfter = (await container.read(salesRepositoryProvider).list(from: DateTime.now(), to: DateTime.now())).count;
    expect(salesAfter, salesBefore + 1);

    final resent = await container.read(offlineQueueProvider.notifier).sync();
    expect(resent, 0);
  });
}
