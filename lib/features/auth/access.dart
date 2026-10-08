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
  bool get usesSerials => hasFeature(FeatureKeys.serialNumber);
  bool get canManageOrders => _gate(FeatureKeys.preOrder, PermissionKeys.ordersManage);
  bool get usesDeliveryNotes => _gate(FeatureKeys.deliveryNote, PermissionKeys.posSell);
}
