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
  static const inventoryOpname = 'inventory.opname';
  static const reportsSales = 'reports.sales';
  static const reportsActivityLog = 'reports.activity-log';
  static const settingsOutlets = 'settings.outlets';
  static const productAttributes = 'business.product-attributes';
  static const multiUnit = 'business.multi-unit';
  static const tieredPrice = 'business.tiered-price';
  static const modifiers = 'business.modifiers';
  static const orderType = 'business.order-type';
  static const batchExpiry = 'business.batch-expiry';
  static const prescription = 'business.prescription';
  static const variants = 'business.variants';
  static const serialNumber = 'business.serial-number';
  static const preOrder = 'business.pre-order';
  static const deliveryNote = 'business.delivery-note';
}

/// Nama izin (permission) yang dipakai aturan akses.
abstract final class PermissionKeys {
  static const posSell = 'pos.sell';
  static const shiftsManage = 'shifts.manage';
  static const receivablesManage = 'receivables.manage';
  static const masterDataView = 'master-data.view';
  static const masterDataManage = 'master-data.manage';
  static const inventoryManage = 'inventory.manage';
  static const opnameCount = 'inventory.opname.count';
  static const opnameManage = 'inventory.opname.manage';
  static const reportsSalesView = 'reports.sales.view';
  static const reportsActivityView = 'reports.activity.view';
  static const settingsPosManage = 'settings.pos.manage';
  static const outletsView = 'outlets.view';
  static const outletsManage = 'outlets.manage';
  static const prescriptionView = 'pharmacy.prescription.view';
  static const prescriptionManage = 'pharmacy.prescription.manage';
  static const prescriptionVerify = 'pharmacy.prescription.verify';
  static const ordersManage = 'orders.manage';
  static const kitchenView = 'kitchen.view';
}
