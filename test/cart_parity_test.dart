import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:web_pos_mobile/features/pos/cart_math.dart';

void main() {
  // Salinan tests/fixtures/cart-parity.json dari repo web; perbarui keduanya bersamaan.
  final fixture = jsonDecode(File('test/fixtures/cart-parity.json').readAsStringSync()) as Map<String, dynamic>;

  for (final c in (fixture['totals'] as List).cast<Map<String, dynamic>>()) {
    test('totals: ${c['name']}', () {
      final lines = (c['lines'] as List).cast<Map<String, dynamic>>().map(
        (line) => MathLine(
          price: (line['price'] as num).toInt(),
          quantity: (line['quantity'] as num).toDouble(),
          discount: (line['discount'] as num? ?? 0).toInt(),
          modifiers: (line['modifiers'] as num? ?? 0).toInt(),
        ),
      );
      final r = calculateCart(
        lines.toList(),
        c['discount_type'] as String?,
        (c['discount_value'] as num).toDouble(),
        (c['tax_rate'] as num).toDouble(),
        serviceRate: (c['service_rate'] as num).toDouble(),
      );
      final expected = c['expected'] as Map<String, dynamic>;

      expect(r.subtotal, expected['subtotal']);
      expect(r.discountAmount, expected['discount_amount']);
      expect(r.serviceAmount, expected['service_charge_amount']);
      expect(r.taxAmount, expected['tax_amount']);
      expect(r.total, expected['total']);
    });
  }

  for (final c in (fixture['tiers'] as List).cast<Map<String, dynamic>>()) {
    test('tier price ${c['base']} x ${c['quantity']}', () {
      final tiers = (c['tiers'] as List).cast<Map<String, dynamic>>().map(PriceTier.fromJson).toList();
      expect(tierPrice((c['base'] as num).toInt(), tiers, (c['quantity'] as num).toDouble()), c['expected']);
    });
  }

  for (final c in (fixture['signatures'] as List).cast<Map<String, dynamic>>()) {
    test('signature ${c['expected']}', () {
      final line = c['line'] as Map<String, dynamic>;
      expect(
        lineSignature(
          productId: (line['product_id'] as num).toInt(),
          unitId: (line['unit_id'] as num?)?.toInt(),
          modifierIds: (line['modifiers'] as List).cast<Map<String, dynamic>>().map((m) => (m['id'] as num).toInt()),
          note: line['note'] as String?,
        ),
        c['expected'],
      );
    });
  }

  for (final c in (fixture['near_expiry'] as List).cast<Map<String, dynamic>>()) {
    test('near-expiry discount ${c['price']} x ${c['quantity']}', () {
      expect(
        nearExpiryDiscount((c['price'] as num).toInt(), (c['quantity'] as num).toDouble(), (c['available'] as num).toDouble(), (c['percent'] as num).toDouble()),
        c['expected'],
      );
    });
  }
}
