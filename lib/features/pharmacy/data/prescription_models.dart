import '../../../core/utils/json.dart';

class PrescriptionLine {
  const PrescriptionLine({
    required this.id,
    this.productId,
    required this.productName,
    this.unit,
    required this.prescribed,
    required this.dispensed,
    required this.remaining,
    this.iteration = 0,
    this.dosage,
  });

  factory PrescriptionLine.fromJson(Map<String, dynamic> json) => PrescriptionLine(
        id: asInt(json['id']),
        productId: json['product_id'] == null ? null : asInt(json['product_id']),
        productName: json['product_name'] as String? ?? '',
        unit: json['unit'] as String?,
        prescribed: asDouble(json['quantity_prescribed']),
        dispensed: asDouble(json['quantity_dispensed']),
        remaining: asDouble(json['remaining']),
        iteration: asInt(json['iteration']),
        dosage: json['dosage_instructions'] as String?,
      );

  final int id;
  final int? productId;
  final String productName;
  final String? unit;
  final double prescribed;
  final double dispensed;
  final double remaining;
  final int iteration;
  final String? dosage;
}

class Prescription {
  const Prescription({
    required this.id,
    required this.number,
    required this.date,
    required this.doctorName,
    this.doctorSip,
    this.clinicName,
    required this.patientName,
    this.patientAge,
    this.patientPhone,
    required this.status,
    required this.statusLabel,
    required this.isVerified,
    this.verifiedBy,
    this.notes,
    this.imageUrl,
    this.items = const [],
  });

  factory Prescription.fromJson(Map<String, dynamic> json) => Prescription(
        id: asInt(json['id']),
        number: json['number'] as String? ?? '',
        date: asDate(json['prescription_date']) ?? DateTime.now(),
        doctorName: json['doctor_name'] as String? ?? '',
        doctorSip: json['doctor_sip'] as String?,
        clinicName: json['clinic_name'] as String?,
        patientName: json['patient_name'] as String? ?? '',
        patientAge: json['patient_age'] == null ? null : asInt(json['patient_age']),
        patientPhone: json['patient_phone'] as String?,
        status: json['status'] as String? ?? 'pending',
        statusLabel: json['status_label'] as String? ?? '',
        isVerified: json['is_verified'] as bool? ?? false,
        verifiedBy: json['verified_by'] as String?,
        notes: json['notes'] as String?,
        imageUrl: json['image_url'] as String?,
        items: asList(json['items']).map(PrescriptionLine.fromJson).toList(),
      );

  final int id;
  final String number;
  final DateTime date;
  final String doctorName;
  final String? doctorSip;
  final String? clinicName;
  final String patientName;
  final int? patientAge;
  final String? patientPhone;
  final String status;
  final String statusLabel;
  final bool isVerified;
  final String? verifiedBy;
  final String? notes;
  final String? imageUrl;
  final List<PrescriptionLine> items;

  bool get isOpen => status == 'pending' || status == 'partially_dispensed';

  bool get isPending => status == 'pending';
}

/// Satu obat di form resep. Jumlah dalam satuan dasar produk, sudah termasuk iter.
class PrescriptionInputLine {
  PrescriptionInputLine({this.productId, this.productName = '', this.unit, this.quantity = '', this.iteration = '0', this.dosage = ''});

  int? productId;
  String productName;
  String? unit;
  String quantity;
  String iteration;
  String dosage;

  Map<String, dynamic> toJson() => {
        'product_id': ?productId,
        'product_name': productName.trim(),
        'quantity': double.tryParse(quantity.replaceAll(',', '.')) ?? 0,
        'iteration': int.tryParse(iteration) ?? 0,
        'dosage_instructions': dosage.trim().isEmpty ? null : dosage.trim(),
      };
}
