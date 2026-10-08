import '../../../core/utils/json.dart';

/// A branch of the shop. Locked outlets (`isOperational` false) are still readable but cannot sell,
/// open shifts, or change stock until the plan limit allows them again.
class OutletInfo {
  const OutletInfo({
    required this.id,
    required this.name,
    required this.code,
    this.address,
    this.phone,
    this.isPrimary = false,
    this.isActive = true,
    this.isOperational = true,
    this.priority = 0,
    this.usersCount,
    this.userIds,
    this.storeType,
    this.effectiveStoreType,
    this.effectiveStoreTypeLabel,
    this.capabilities,
    this.disabledFeatures = const [],
  });

  factory OutletInfo.fromJson(Map<String, dynamic> json) => OutletInfo(
        id: asInt(json['id']),
        name: json['name'] as String? ?? '',
        code: json['code'] as String? ?? '',
        address: json['address'] as String?,
        phone: json['phone'] as String?,
        isPrimary: json['is_primary'] as bool? ?? false,
        isActive: json['is_active'] as bool? ?? true,
        isOperational: json['is_operational'] as bool? ?? true,
        priority: asInt(json['priority']),
        usersCount: json['users_count'] == null ? null : asInt(json['users_count']),
        userIds: json['user_ids'] is List ? (json['user_ids'] as List).map(asInt).toList() : null,
        storeType: json['store_type'] as String?,
        effectiveStoreType: json['effective_store_type'] as String?,
        effectiveStoreTypeLabel: json['effective_store_type_label'] as String?,
        capabilities: json['capabilities'] is List ? (json['capabilities'] as List).cast<String>() : null,
        disabledFeatures: (json['disabled_features'] as List? ?? const []).cast<String>(),
      );

  final int id;
  final String name;
  final String code;
  final String? address;
  final String? phone;
  final bool isPrimary;
  final bool isActive;
  final bool isOperational;
  final int priority;
  final int? usersCount;
  final List<int>? userIds;

  /// Null when the outlet follows the shop's store type ([effectiveStoreType]).
  final String? storeType;
  final String? effectiveStoreType;
  final String? effectiveStoreTypeLabel;

  /// Business capabilities switched on at this outlet; null on servers older than per-outlet features.
  final List<String>? capabilities;

  /// Cashier features the outlet switched off on its own, e.g. `pos.receivables`.
  final List<String> disabledFeatures;

  /// Active but over the plan limit.
  bool get isLocked => isActive && !isOperational;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'address': address,
        'phone': phone,
        'is_primary': isPrimary,
        'is_active': isActive,
        'is_operational': isOperational,
        'priority': priority,
        'users_count': usersCount,
        'user_ids': userIds,
        'store_type': storeType,
        'effective_store_type': effectiveStoreType,
        'effective_store_type_label': effectiveStoreTypeLabel,
        'capabilities': capabilities,
        'disabled_features': disabledFeatures,
      };
}

/// Tax, payment methods, receipt and QRIS of one outlet. A section with `inherit` true follows the
/// shop setting and its values are the shop's.
class OutletSettingsData {
  const OutletSettingsData({
    this.taxInherit = true,
    this.taxEnabled = false,
    this.taxRate = '0',
    this.taxLabel = 'PPN',
    this.paymentsInherit = true,
    this.paymentMethods = const ['cash'],
    this.receiptInherit = true,
    this.receiptWidth = '58',
    this.receiptHeader = '',
    this.receiptFooter = '',
    this.autoPrint = false,
    this.qrisInherit = true,
    this.qrisPayload = '',
    this.hasRules = false,
    this.rulesInherit = true,
    this.allowCredit = false,
    this.allowNegativeStock = false,
    this.quickCash = const [],
    this.pharmacyInherit = true,
    this.prescriptionMode = 'strict',
    this.allowControlledDrugs = false,
    this.blockExpiredSale = true,
    this.nearExpiryPercent = '0',
    this.nearExpiryDays = '2',
  });

  factory OutletSettingsData.fromJson(Map<String, dynamic> json) {
    final tax = asMap(json['tax']);
    final payments = asMap(json['payments']);
    final receipt = asMap(json['receipt']);
    final qris = asMap(json['qris']);
    final rules = asMap(json['rules']);
    final pharmacy = asMap(json['pharmacy']);

    return OutletSettingsData(
      taxInherit: tax['inherit'] as bool? ?? true,
      taxEnabled: tax['enabled'] as bool? ?? false,
      taxRate: '${tax['rate'] ?? '0'}',
      taxLabel: tax['label'] as String? ?? 'PPN',
      paymentsInherit: payments['inherit'] as bool? ?? true,
      paymentMethods: (payments['methods'] as List? ?? const ['cash']).cast<String>(),
      receiptInherit: receipt['inherit'] as bool? ?? true,
      receiptWidth: '${receipt['width'] ?? '58'}',
      receiptHeader: receipt['header'] as String? ?? '',
      receiptFooter: receipt['footer'] as String? ?? '',
      autoPrint: receipt['auto_print'] as bool? ?? false,
      qrisInherit: qris['inherit'] as bool? ?? true,
      qrisPayload: qris['payload'] as String? ?? '',
      hasRules: json['rules'] is Map,
      rulesInherit: rules['inherit'] as bool? ?? true,
      allowCredit: rules['allow_credit'] as bool? ?? false,
      allowNegativeStock: rules['allow_negative_stock'] as bool? ?? false,
      quickCash: (rules['quick_cash'] as List? ?? const []).map(asInt).toList(),
      pharmacyInherit: pharmacy['inherit'] as bool? ?? true,
      prescriptionMode: pharmacy['prescription_mode'] as String? ?? 'strict',
      allowControlledDrugs: pharmacy['allow_controlled_drugs'] as bool? ?? false,
      blockExpiredSale: pharmacy['block_expired_sale'] as bool? ?? true,
      nearExpiryPercent: '${pharmacy['near_expiry_discount_percent'] ?? '0'}',
      nearExpiryDays: '${pharmacy['near_expiry_discount_days'] ?? '2'}',
    );
  }

  final bool taxInherit;
  final bool taxEnabled;
  final String taxRate;
  final String taxLabel;
  final bool paymentsInherit;
  final List<String> paymentMethods;
  final bool receiptInherit;
  final String receiptWidth;
  final String receiptHeader;
  final String receiptFooter;
  final bool autoPrint;
  final bool qrisInherit;
  final String qrisPayload;

  /// False on servers that cannot override cashier and pharmacy rules per outlet; those sections are
  /// then neither shown nor sent.
  final bool hasRules;
  final bool rulesInherit;
  final bool allowCredit;
  final bool allowNegativeStock;
  final List<int> quickCash;
  final bool pharmacyInherit;
  final String prescriptionMode;
  final bool allowControlledDrugs;
  final bool blockExpiredSale;
  final String nearExpiryPercent;
  final String nearExpiryDays;

  Map<String, dynamic> toJson() => {
        'tax': {'inherit': taxInherit, 'enabled': taxEnabled, 'rate': taxRate, 'label': taxLabel},
        'payments': {'inherit': paymentsInherit, 'methods': paymentMethods},
        'receipt': {'inherit': receiptInherit, 'width': receiptWidth, 'header': receiptHeader, 'footer': receiptFooter, 'auto_print': autoPrint},
        'qris': {'inherit': qrisInherit, 'payload': qrisPayload},
        if (hasRules) ...{
          'rules': {'inherit': rulesInherit, 'allow_credit': allowCredit, 'allow_negative_stock': allowNegativeStock, 'quick_cash': quickCash},
          'pharmacy': {
            'inherit': pharmacyInherit,
            'prescription_mode': prescriptionMode,
            'allow_controlled_drugs': allowControlledDrugs,
            'block_expired_sale': blockExpiredSale,
            'near_expiry_discount_percent': nearExpiryPercent,
            'near_expiry_discount_days': nearExpiryDays,
          },
        },
      };
}

/// An account listed on the outlet access sheet.
class OutletUser {
  const OutletUser({required this.id, required this.name, this.username = '', this.hasAllOutlets = false, this.assigned = false});

  factory OutletUser.fromJson(Map<String, dynamic> json) => OutletUser(
        id: asInt(json['id']),
        name: json['name'] as String? ?? '',
        username: json['username'] as String? ?? '',
        hasAllOutlets: json['has_all_outlets'] as bool? ?? false,
        assigned: json['assigned'] as bool? ?? false,
      );

  final int id;
  final String name;
  final String username;

  /// Owners and accounts marked "all outlets" always have access and cannot be (un)assigned here.
  final bool hasAllOutlets;
  final bool assigned;
}
