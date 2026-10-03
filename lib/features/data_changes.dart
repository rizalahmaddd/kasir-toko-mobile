import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../core/network/api_exception.dart';
import 'customers/customers_providers.dart';
import 'dashboard/dashboard.dart';
import 'notifications/notifications.dart';
import 'offline/catalog_snapshot.dart';
import 'offline/offline_queue.dart';
import 'pos/cart_controller.dart';
import 'pos/pos_providers.dart';
import 'printing/printer.dart';
import 'products/products_providers.dart';
import 'receivables/receivables.dart';
import 'reports/reports.dart';
import 'sales/presentation/receipt_sheet.dart';
import 'sales/sales_controller.dart';
import 'shift/shift_controller.dart';
import 'shift/shifts_providers.dart';

enum DataChange { sales, products, customers, shifts }

final dataChangesProvider = Provider<DataChanges>(DataChanges.new);

/// The one place that knows which screens show what, so a write anywhere refreshes every list,
/// detail and total that depends on it. Riverpod pauses providers whose screens are out of view
/// and reloads them only when shown again, so listing them all here costs nothing extra.
class DataChanges {
  DataChanges(this._ref);

  final Ref _ref;

  static final Map<DataChange, List<ProviderOrFamily>> _dependents = {
    DataChange.sales: [
      salesProvider,
      saleDetailProvider,
      receiptProvider,
      currentShiftProvider,
      shiftsProvider,
      shiftDetailProvider,
      shiftSalesProvider,
      receivablesProvider,
      customerReceivablesProvider,
      customersProvider,
      customerProvider,
      customerSalesProvider,
      salesSummaryProvider,
      dailyReportProvider,
      productReportProvider,
      ..._stock,
    ],
    DataChange.products: [..._stock, posCategoriesProvider, categoriesProvider, allCategoriesProvider],
    DataChange.customers: [customersProvider, customerProvider, customerSalesProvider, customerReceivablesProvider, receivablesProvider],
    DataChange.shifts: [currentShiftProvider, posConfigProvider, shiftsProvider, shiftDetailProvider, shiftSalesProvider],
  };

  static final List<ProviderOrFamily> _stock = [
    catalogProvider,
    productsProvider,
    productDetailProvider,
    stockProvider,
    stockSummaryProvider,
    movementsProvider,
  ];

  void after(Set<DataChange> changes) {
    final providers = <ProviderOrFamily>{
      dashboardProvider,
      activityProvider,
      notificationsProvider,
      unreadCountProvider,
      for (final change in changes) ..._dependents[change]!,
    };
    for (final provider in providers) {
      _ref.invalidate(provider);
    }
    if (changes.contains(DataChange.products)) {
      unawaited(_refreshSnapshot());
    }
  }

  /// A sale the server just stored: the offline catalog loses the sold stock right away rather
  /// than at its next download, so it is still right if the connection drops in between.
  Future<void> saleRecorded(Map<int, double> quantities) async {
    final deducting = _ref.read(catalogSnapshotProvider.notifier).deduct(quantities);
    after({DataChange.sales});
    await deducting;
  }

  /// A sale kept on the device: nothing changed on the server yet, but the stock screens that
  /// fall back to the offline catalog must show what is left.
  Future<void> saleQueued(Map<int, double> quantities) async {
    final deducting = _ref.read(catalogSnapshotProvider.notifier).deduct(quantities);
    for (final provider in _stock) {
      _ref.invalidate(provider);
    }
    await deducting;
  }

  Future<void> _refreshSnapshot() async {
    if (await _ref.read(catalogSnapshotProvider.future) == null) {
      return;
    }
    try {
      await _ref.read(catalogSnapshotProvider.notifier).download();
    } on ApiException {
      // Offline: the periodic refresh in the syncer picks it up later.
    }
  }

  /// Completely resets all in-memory feature providers and active queries/filters.
  /// Called on logout or switching accounts/tenants so no data from a previous
  /// session leaks into another session.
  void resetAllSessionData() {
    final providers = <ProviderOrFamily>{
      // POS & Catalog
      catalogProvider,
      catalogQueryProvider,
      cartProvider,
      heldOrderPreviewsProvider,
      posConfigProvider,
      posCategoriesProvider,

      // Products & Stock
      productsProvider,
      productsQueryProvider,
      productDetailProvider,
      allCategoriesProvider,
      categoriesProvider,
      categoriesSearchProvider,
      stockProvider,
      stockQueryProvider,
      stockSummaryProvider,
      movementsProvider,

      // Sales
      salesProvider,
      salesFilterProvider,
      saleDetailProvider,
      receiptProvider,

      // Shifts
      currentShiftProvider,
      shiftsProvider,
      shiftsStatusProvider,
      shiftDetailProvider,
      shiftSalesProvider,

      // Customers & Receivables
      customersProvider,
      customersQueryProvider,
      customerProvider,
      customerSalesProvider,
      receivablesProvider,
      receivablesSearchProvider,
      customerReceivablesProvider,

      // Dashboard & Reports
      dashboardProvider,
      activityProvider,
      activityQueryProvider,
      salesSummaryProvider,
      dailyReportProvider,
      productReportProvider,
      productReportQueryProvider,
      reportRangeProvider,

      // Notifications
      unreadCountProvider,
      notificationsProvider,

      // Offline
      catalogSnapshotProvider,
      syncStateProvider,

      // Printing
      receiptProfileProvider,
    };

    for (final provider in providers) {
      _ref.invalidate(provider);
    }
  }
}

