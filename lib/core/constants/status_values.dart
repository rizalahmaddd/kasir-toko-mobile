/// Nilai status/tipe yang dipakai domain dan pertukaran data.
/// Sengaja berupa konstanta string agar kontrak JSON tidak berubah.
library;

abstract final class PaymentMethods {
  static const cash = 'cash';
  static const qris = 'qris';
  static const transfer = 'transfer';
  static const card = 'card';
}

abstract final class PaymentKinds {
  static const sale = 'sale';
  static const receivable = 'receivable';
}

abstract final class SaleStatuses {
  static const completed = 'completed';
  static const credit = 'credit';
  static const voided = 'voided';
}

abstract final class QueuedStatusValues {
  static const pending = 'pending';
  static const failed = 'failed';
}

abstract final class MovementTypes {
  static const sale = 'sale';
  static const saleVoid = 'sale_void';
  static const stockIn = 'stock_in';
  static const stockOut = 'stock_out';
  static const opname = 'opname';
  static const initial = 'initial';
}

abstract final class CashMovementTypes {
  static const cashIn = 'in';
  static const cashOut = 'out';
}

abstract final class DiscountTypes {
  static const percent = 'percent';
  static const amount = 'amount';
}

abstract final class ProductStatuses {
  static const active = 'active';
  static const inactive = 'inactive';
}

abstract final class StockLevels {
  static const low = 'low';
  static const out = 'out';
}

abstract final class NotificationTargets {
  static const sale = 'sale';
  static const customer = 'customer';
  static const shift = 'shift';
}

abstract final class ThemePreferences {
  static const light = 'light';
  static const dark = 'dark';
  static const system = 'system';
}

abstract final class AuthProviders {
  static const google = 'google';
  static const apple = 'apple';
}

abstract final class PlanKinds {
  static const trial = 'trial';
}

abstract final class ProductSortKeys {
  static const name = 'name';
  static const nameDesc = '-name';
  static const price = 'price';
  static const priceDesc = '-price';
  static const stock = 'stock';
  static const stockDesc = '-stock';
  static const sku = 'sku';
}

abstract final class ReportProductSortKeys {
  static const revenue = 'revenue';
  static const profit = 'profit';
  static const qty = 'qty';
  static const margin = 'margin';
}

abstract final class ActivityLogNames {
  static const audit = 'audit';
  static const auth = 'auth';
  static const settings = 'settings';
  static const roles = 'roles';
  static const export = 'export';
}

abstract final class DateRangePresets {
  static const today = 'today';
  static const last7Days = '7days';
  static const month = 'month';
  static const custom = 'custom';
}
