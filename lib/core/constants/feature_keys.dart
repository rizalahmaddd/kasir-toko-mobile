/// Nama fitur (feature flag) yang dipakai aturan akses.
abstract final class FeatureKeys {
  static const posCashier = 'pos.cashier';
  static const posSales = 'pos.sales';
  static const posShifts = 'pos.shifts';
  static const posReceivables = 'pos.receivables';
  static const masterDataProducts = 'master-data.products';
  static const masterDataCategories = 'master-data.categories';
  static const masterDataCustomers = 'master-data.customers';
  static const inventoryStock = 'inventory.stock';
  static const reportsSales = 'reports.sales';
  static const reportsActivityLog = 'reports.activity-log';
}

/// Nama izin (permission) yang dipakai aturan akses.
abstract final class PermissionKeys {
  static const posSell = 'pos.sell';
  static const shiftsManage = 'shifts.manage';
  static const receivablesManage = 'receivables.manage';
  static const masterDataView = 'master-data.view';
  static const masterDataManage = 'master-data.manage';
  static const inventoryManage = 'inventory.manage';
  static const reportsSalesView = 'reports.sales.view';
  static const reportsActivityView = 'reports.activity.view';
  static const settingsPosManage = 'settings.pos.manage';
}
