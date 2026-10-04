import '../../core/constants/feature_keys.dart';
import 'data/current_user.dart';

/// Mirrors the menu rules in the web app's App\Support\Navigation so both clients show the same modules.
extension Access on CurrentUser {
  bool _gate(String feature, String permission) => hasFeature(feature) && can(permission);

  bool get canSell => _gate(FeatureKeys.posCashier, PermissionKeys.posSell);
  bool get canViewSales => _gate(FeatureKeys.posSales, PermissionKeys.posSell);
  bool get canViewShifts => _gate(FeatureKeys.posShifts, PermissionKeys.posSell);
  bool get canManageShifts => canViewShifts && can(PermissionKeys.shiftsManage);
  bool get canManageReceivables => hasFeature(FeatureKeys.posCashier) && _gate(FeatureKeys.posReceivables, PermissionKeys.receivablesManage);

  bool get canViewProducts => _gate(FeatureKeys.masterDataProducts, PermissionKeys.masterDataView);
  bool get canViewCategories => _gate(FeatureKeys.masterDataCategories, PermissionKeys.masterDataView);
  bool get canViewCustomers => _gate(FeatureKeys.masterDataCustomers, PermissionKeys.masterDataView);
  bool get canViewStock => canViewProducts && _gate(FeatureKeys.inventoryStock, PermissionKeys.masterDataView);
  bool get canManageMasterData => can(PermissionKeys.masterDataManage);
  bool get canAdjustStock => canViewStock && can(PermissionKeys.inventoryManage);

  bool get canViewSalesReport => _gate(FeatureKeys.reportsSales, PermissionKeys.reportsSalesView);
  bool get canViewActivityLog => _gate(FeatureKeys.reportsActivityLog, PermissionKeys.reportsActivityView);

  bool get canManagePosSettings => can(PermissionKeys.settingsPosManage) || canManageMasterData;
}
