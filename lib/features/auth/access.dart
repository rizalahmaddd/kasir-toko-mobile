import 'data/current_user.dart';

/// Mirrors the menu rules in the web app's App\Support\Navigation so both clients show the same modules.
extension Access on CurrentUser {
  bool _gate(String feature, String permission) => hasFeature(feature) && can(permission);

  bool get canSell => _gate('pos.cashier', 'pos.sell');
  bool get canViewSales => _gate('pos.sales', 'pos.sell');
  bool get canViewShifts => _gate('pos.shifts', 'pos.sell');
  bool get canManageShifts => canViewShifts && can('shifts.manage');
  bool get canManageReceivables => hasFeature('pos.cashier') && _gate('pos.receivables', 'receivables.manage');

  bool get canViewProducts => _gate('master-data.products', 'master-data.view');
  bool get canViewCategories => _gate('master-data.categories', 'master-data.view');
  bool get canViewCustomers => _gate('master-data.customers', 'master-data.view');
  bool get canViewStock => canViewProducts && _gate('inventory.stock', 'master-data.view');
  bool get canManageMasterData => can('master-data.manage');
  bool get canAdjustStock => canViewStock && can('inventory.manage');

  bool get canViewSalesReport => _gate('reports.sales', 'reports.sales.view');
  bool get canViewActivityLog => _gate('reports.activity-log', 'reports.activity.view');

  bool get canManagePosSettings => can('settings.pos.manage') || canManageMasterData;
}
