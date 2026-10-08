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
  bool get canCountStock => _gate(FeatureKeys.inventoryOpname, PermissionKeys.opnameCount) && hasFeature(FeatureKeys.inventoryStock);
  bool get canManageStockCount => canCountStock && can(PermissionKeys.opnameManage);

  bool get canViewSalesReport => _gate(FeatureKeys.reportsSales, PermissionKeys.reportsSalesView);
  bool get canViewActivityLog => _gate(FeatureKeys.reportsActivityLog, PermissionKeys.reportsActivityView);

  bool get canViewOutlets => _gate(FeatureKeys.settingsOutlets, PermissionKeys.outletsView);
  bool get canManageOutlets => canViewOutlets && can(PermissionKeys.outletsManage);

  bool get canManagePosSettings => can(PermissionKeys.settingsPosManage) || canManageMasterData;

  bool get usesMultiUnit => hasFeature(FeatureKeys.multiUnit);
  bool get usesBatches => hasFeature(FeatureKeys.batchExpiry);
  bool get usesTieredPrice => hasFeature(FeatureKeys.tieredPrice);
  bool get usesProductAttributes => hasFeature(FeatureKeys.productAttributes);
  bool get usesPrescriptions => hasFeature(FeatureKeys.prescription);
  bool get canViewPrescriptions => _gate(FeatureKeys.prescription, PermissionKeys.prescriptionView);
  bool get canManagePrescriptions => _gate(FeatureKeys.prescription, PermissionKeys.prescriptionManage);
  bool get canVerifyPrescriptions => _gate(FeatureKeys.prescription, PermissionKeys.prescriptionVerify);
  bool get usesVariants => hasFeature(FeatureKeys.variants);
  bool get usesModifiers => hasFeature(FeatureKeys.modifiers);
  bool get canViewKitchen => _gate(FeatureKeys.orderType, PermissionKeys.kitchenView);
  bool get usesSerials => hasFeature(FeatureKeys.serialNumber);
  bool get canManageOrders => _gate(FeatureKeys.preOrder, PermissionKeys.ordersManage);
  bool get usesDeliveryNotes => _gate(FeatureKeys.deliveryNote, PermissionKeys.posSell);
}

/// Operational checks that follow the outlet the app works in: the cashier and the menus for
/// kitchen, orders, and prescriptions. Master data and history screens stay on the shop-wide getters
/// above, so a product edited at one outlet keeps the fields another outlet uses.
extension OutletAccess on CurrentUser {
  bool _gateAt(String feature, String permission, int? outletId) => hasFeatureAt(feature, outletId) && can(permission);

  bool usesMultiUnitAt(int? outletId) => hasFeatureAt(FeatureKeys.multiUnit, outletId);
  bool usesPrescriptionsAt(int? outletId) => hasFeatureAt(FeatureKeys.prescription, outletId);
  bool canViewPrescriptionsAt(int? outletId) => _gateAt(FeatureKeys.prescription, PermissionKeys.prescriptionView, outletId);
  bool canViewKitchenAt(int? outletId) => _gateAt(FeatureKeys.orderType, PermissionKeys.kitchenView, outletId);
  bool canManageOrdersAt(int? outletId) => _gateAt(FeatureKeys.preOrder, PermissionKeys.ordersManage, outletId);
  bool usesDeliveryNotesAt(int? outletId) => _gateAt(FeatureKeys.deliveryNote, PermissionKeys.posSell, outletId);
}
