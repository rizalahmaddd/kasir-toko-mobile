import 'package:web_pos_mobile/core/constants/status_values.dart';

int _int(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

class CashMovement {
  const CashMovement({required this.id, required this.type, required this.typeLabel, required this.amount, required this.reason, required this.createdAt});

  factory CashMovement.fromJson(Map<String, dynamic> json) => CashMovement(
        id: json['id'] as int,
        type: json['type'] as String,
        typeLabel: json['type_label'] as String,
        amount: _int(json['amount']),
        reason: json['reason'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  final int id;
  final String type;
  final String typeLabel;
  final int amount;
  final String reason;
  final DateTime createdAt;

  bool get isIn => type == CashMovementTypes.cashIn;
}

class ShiftSummary {
  const ShiftSummary({
    required this.opening,
    required this.cashSales,
    required this.cashReceivables,
    required this.cashIn,
    required this.cashOut,
    required this.expected,
    required this.salesCount,
    required this.salesTotal,
    required this.voidedCount,
    required this.nonCash,
  });

  factory ShiftSummary.fromJson(Map<String, dynamic> json) => ShiftSummary(
        opening: _int(json['opening']),
        cashSales: _int(json['cash_sales']),
        cashReceivables: _int(json['cash_receivables']),
        cashIn: _int(json['cash_in']),
        cashOut: _int(json['cash_out']),
        expected: _int(json['expected']),
        salesCount: _int(json['sales_count']),
        salesTotal: _int(json['sales_total']),
        voidedCount: _int(json['voided_count']),
        nonCash: (json['non_cash'] as Map<String, dynamic>? ?? const {}).map((key, value) => MapEntry(key, _int(value))),
      );

  final int opening;
  final int cashSales;
  final int cashReceivables;
  final int cashIn;
  final int cashOut;
  final int expected;
  final int salesCount;
  final int salesTotal;
  final int voidedCount;
  final Map<String, int> nonCash;
}

class Shift {
  const Shift({
    required this.id,
    required this.number,
    required this.isOpen,
    required this.cashierName,
    required this.openedAt,
    required this.openingCash,
    this.closedAt,
    this.expectedCash,
    this.countedCash,
    this.cashDifference,
    this.closingNote,
    this.summary,
    this.cashMovements = const [],
    this.canClose = false,
    this.canRecordCash = false,
    this.closedByName,
    this.salesCount,
    this.salesTotal,
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    final abilities = json['abilities'] as Map<String, dynamic>? ?? const {};

    return Shift(
      id: json['id'] as int,
      number: json['number'] as String,
      isOpen: json['is_open'] as bool? ?? false,
      cashierName: (json['cashier'] as Map<String, dynamic>?)?['name'] as String? ?? '-',
      openedAt: DateTime.parse(json['opened_at'] as String),
      openingCash: _int(json['opening_cash']),
      closedAt: json['closed_at'] == null ? null : DateTime.parse(json['closed_at'] as String),
      expectedCash: json['expected_cash'] == null ? null : _int(json['expected_cash']),
      countedCash: json['counted_cash'] == null ? null : _int(json['counted_cash']),
      cashDifference: json['cash_difference'] == null ? null : _int(json['cash_difference']),
      closingNote: json['closing_note'] as String?,
      summary: json['summary'] == null ? null : ShiftSummary.fromJson(json['summary'] as Map<String, dynamic>),
      cashMovements: (json['cash_movements'] as List? ?? const []).cast<Map<String, dynamic>>().map(CashMovement.fromJson).toList(),
      canClose: abilities['close'] as bool? ?? false,
      canRecordCash: abilities['record_cash'] as bool? ?? false,
      closedByName: (json['closed_by'] as Map<String, dynamic>?)?['name'] as String?,
      salesCount: json['sales_count'] == null ? null : _int(json['sales_count']),
      salesTotal: json['sales_total'] == null ? null : _int(json['sales_total']),
    );
  }

  final int id;
  final String number;
  final bool isOpen;
  final String cashierName;
  final DateTime openedAt;
  final int openingCash;
  final DateTime? closedAt;
  final int? expectedCash;
  final int? countedCash;
  final int? cashDifference;
  final String? closingNote;
  final ShiftSummary? summary;
  final List<CashMovement> cashMovements;
  final bool canClose;
  final bool canRecordCash;
  final String? closedByName;
  final int? salesCount;
  final int? salesTotal;
}
