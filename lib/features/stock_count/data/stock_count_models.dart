import '../../../core/utils/json.dart';

abstract final class StockCountStatuses {
  static const counting = 'counting';
  static const review = 'review';
  static const posting = 'posting';
  static const posted = 'posted';
  static const cancelled = 'cancelled';
}

class StockCountDoc {
  const StockCountDoc({
    required this.id,
    required this.number,
    required this.status,
    required this.statusLabel,
    required this.scope,
    required this.scopeLabel,
    required this.canSeeSystem,
    required this.canManage,
    required this.holdAdjustments,
    this.outletId,
    this.outletName,
    this.note,
    this.itemsCount = 0,
    this.countedCount = 0,
    this.startedAt,
    this.summary = const {},
  });

  factory StockCountDoc.fromJson(Map<String, dynamic> json) => StockCountDoc(
        id: asInt(json['id']),
        number: json['number'] as String? ?? '',
        status: json['status'] as String? ?? StockCountStatuses.counting,
        statusLabel: json['status_label'] as String? ?? '',
        scope: json['scope'] as String? ?? 'all',
        scopeLabel: json['scope_label'] as String? ?? '',
        canSeeSystem: json['can_see_system'] == true,
        canManage: json['can_manage'] == true,
        holdAdjustments: json['hold_adjustments'] == true,
        outletId: json['outlet'] is Map ? asInt(asMap(json['outlet'])['id']) : null,
        outletName: asMap(json['outlet'])['name'] as String?,
        note: json['note'] as String?,
        itemsCount: asInt(json['items_count']),
        countedCount: asInt(json['counted_items_count']),
        startedAt: asDate(json['started_at']),
        summary: asMap(json['summary']),
      );

  final int id;
  final String number;
  final String status;
  final String statusLabel;
  final String scope;
  final String scopeLabel;
  final bool canSeeSystem;
  final bool canManage;
  final bool holdAdjustments;
  final int? outletId;
  final String? outletName;
  final String? note;
  final int itemsCount;
  final int countedCount;
  final DateTime? startedAt;
  final Map<String, dynamic> summary;

  bool get isEditable => status == StockCountStatuses.counting || status == StockCountStatuses.review;

  /// Opname hanya bisa diubah dari outlet dokumennya.
  bool belongsTo(int? activeOutletId) => outletId == null || activeOutletId == null || outletId == activeOutletId;
  bool get isOpen => isEditable || status == StockCountStatuses.posting;
  double get progress => itemsCount == 0 ? 0 : countedCount / itemsCount;
}

class CountUnit {
  const CountUnit({required this.id, required this.name, required this.factor, this.barcode});

  factory CountUnit.fromJson(Map<String, dynamic> json) =>
      CountUnit(id: asInt(json['id']), name: json['name'] as String? ?? '', factor: asDouble(json['factor']), barcode: json['barcode'] as String?);

  final int id;
  final String name;
  final double factor;
  final String? barcode;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'factor': factor, 'barcode': barcode};
}

class CountBatch {
  const CountBatch({required this.id, this.number, this.expiresAt, this.expired = false, this.quantity});

  factory CountBatch.fromJson(Map<String, dynamic> json) => CountBatch(
        id: asInt(json['id']),
        number: json['number'] as String?,
        expiresAt: json['expires_at'] as String?,
        expired: json['expired'] == true,
        quantity: json['quantity'] == null ? null : asDouble(json['quantity']),
      );

  final int id;
  final String? number;
  final String? expiresAt;
  final bool expired;
  final double? quantity;

  String get label => [number ?? 'Tanpa nomor', if (expiresAt != null) 'ED $expiresAt'].join(' · ');
}

/// Satu barang di opname, ringkas untuk daftar di HP dan disimpan lokal untuk scan offline.
class CountCatalogItem {
  const CountCatalogItem({
    required this.itemId,
    required this.productId,
    required this.name,
    required this.unit,
    this.sku,
    this.barcode,
    this.trackBatch = false,
    this.trackSerial = false,
    this.units = const [],
  });

  factory CountCatalogItem.fromJson(Map<String, dynamic> json) => CountCatalogItem(
        itemId: asInt(json['item_id']),
        productId: asInt(json['product_id']),
        name: json['name'] as String? ?? '',
        unit: json['unit'] as String? ?? 'pcs',
        sku: json['sku'] as String?,
        barcode: json['barcode'] as String?,
        trackBatch: json['track_batch'] == true,
        trackSerial: json['track_serial'] == true,
        units: asList(json['units']).map(CountUnit.fromJson).toList(),
      );

  final int itemId;
  final int productId;
  final String name;
  final String unit;
  final String? sku;
  final String? barcode;
  final bool trackBatch;
  final bool trackSerial;
  final List<CountUnit> units;

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'product_id': productId,
        'name': name,
        'unit': unit,
        'sku': sku,
        'barcode': barcode,
        'track_batch': trackBatch,
        'track_serial': trackSerial,
        'units': units.map((unit) => unit.toJson()).toList(),
      };
}

class CountCatalog {
  CountCatalog(this.items, {this.scopeAll = false}) {
    for (final item in items) {
      if (item.barcode != null && item.barcode!.isNotEmpty) {
        _byCode[item.barcode!] = (item, null);
      }
      for (final unit in item.units) {
        if (unit.barcode != null && unit.barcode!.isNotEmpty) {
          _byCode[unit.barcode!] = (item, unit);
        }
      }
      if (item.sku != null && item.sku!.isNotEmpty) {
        _byCode.putIfAbsent(item.sku!, () => (item, null));
      }
    }
  }

  final List<CountCatalogItem> items;
  final bool scopeAll;
  final Map<String, (CountCatalogItem, CountUnit?)> _byCode = {};

  (CountCatalogItem, CountUnit?)? find(String code) => _byCode[code.trim()];

  List<CountCatalogItem> search(String term, {int limit = 30}) {
    final query = term.trim().toLowerCase();
    if (query.isEmpty) {
      return items.take(limit).toList();
    }
    return items
        .where((item) => item.name.toLowerCase().contains(query) || (item.sku ?? '').toLowerCase().contains(query) || item.barcode == term.trim())
        .take(limit)
        .toList();
  }
}

class CountItem {
  const CountItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.unit,
    this.sku,
    this.variant,
    this.trackBatch = false,
    this.trackSerial = false,
    this.units = const [],
    this.batches = const [],
    this.countedQty,
    this.systemQty,
    this.varianceQty,
    this.varianceValue,
    this.reason,
    this.needsRecount = false,
    this.flags = const [],
  });

  factory CountItem.fromJson(Map<String, dynamic> json) {
    final product = asMap(json['product']);

    return CountItem(
      id: asInt(json['id']),
      productId: asInt(product['id']),
      name: product['name'] as String? ?? '',
      unit: product['unit'] as String? ?? 'pcs',
      sku: product['sku'] as String?,
      variant: product['variant'] as String?,
      trackBatch: product['track_batch'] == true,
      trackSerial: product['track_serial'] == true,
      units: asList(product['units']).map(CountUnit.fromJson).toList(),
      batches: asList(json['batches']).map(CountBatch.fromJson).toList(),
      countedQty: json['counted_qty'] == null ? null : asDouble(json['counted_qty']),
      systemQty: json['reference_system_qty'] != null
          ? asDouble(json['reference_system_qty'])
          : (json['expected_qty'] == null ? null : asDouble(json['expected_qty'])),
      varianceQty: json['variance_qty'] == null ? null : asDouble(json['variance_qty']),
      varianceValue: json['variance_value'] == null ? null : asInt(json['variance_value']),
      reason: json['reason'] as String?,
      needsRecount: json['needs_recount'] == true,
      flags: (json['flags'] as List? ?? const []).map((flag) => '$flag').toList(),
    );
  }

  final int id;
  final int productId;
  final String name;
  final String unit;
  final String? sku;
  final String? variant;
  final bool trackBatch;
  final bool trackSerial;
  final List<CountUnit> units;
  final List<CountBatch> batches;
  final double? countedQty;
  final double? systemQty;
  final double? varianceQty;
  final int? varianceValue;
  final String? reason;
  final bool needsRecount;
  final List<String> flags;

  String get displayName => variant == null ? name : '$name — $variant';

  CountCatalogItem toCatalog() => CountCatalogItem(
        itemId: id,
        productId: productId,
        name: displayName,
        unit: unit,
        sku: sku,
        trackBatch: trackBatch,
        trackSerial: trackSerial,
        units: units,
      );
}

class CountPreview {
  const CountPreview(this.data);

  factory CountPreview.fromJson(Map<String, dynamic> json) => CountPreview(json);

  final Map<String, dynamic> data;

  int get changed => asInt(data['changed']);
  int get shortageValue => asInt(data['shortage_value']);
  int get surplusValue => asInt(data['surplus_value']);
  double get shortageQty => asDouble(data['shortage_qty']);
  double get surplusQty => asDouble(data['surplus_qty']);
  int get uncounted => asInt(data['uncounted']);
  int get uncountedValue => asInt(data['uncounted_value']);
}

/// Hasil scan/ketik yang dikenali server: barang, satuan dari barcode-nya, atau nomor seri.
class CountLookup {
  const CountLookup({required this.kind, this.serial, this.unitId, this.productId, this.productName, this.trackStock = true, this.trackSerial = false, this.item});

  factory CountLookup.fromJson(Map<String, dynamic> json) {
    final product = asMap(json['product']);
    final item = json['item'];

    return CountLookup(
      kind: json['kind'] as String? ?? 'unknown',
      serial: json['serial'] as String?,
      unitId: json['unit_id'] == null ? null : asInt(json['unit_id']),
      productId: product.isEmpty ? null : asInt(product['id']),
      productName: product['name'] as String?,
      trackStock: product['track_stock'] != false,
      trackSerial: product['track_serial'] == true,
      item: item is Map<String, dynamic> ? CountItem.fromJson(item) : null,
    );
  }

  final String kind;
  final String? serial;
  final int? unitId;
  final int? productId;
  final String? productName;
  final bool trackStock;
  final bool trackSerial;
  final CountItem? item;
}
