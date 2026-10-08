// Sama persis dengan App\Services\Pos\CartCalculator di server dan cart-math.js kasir web;
// test/fixtures/cart-parity.json menguji ketiganya.

class MathLine {
  const MathLine({required this.price, required this.quantity, this.discount = 0, this.modifiers = 0});

  final int price;
  final double quantity;
  final int discount;
  final int modifiers;
}

class MathTotals {
  const MathTotals({
    required this.lines,
    required this.subtotal,
    required this.discountAmount,
    required this.serviceAmount,
    required this.taxAmount,
    required this.total,
  });

  final List<int> lines;
  final int subtotal;
  final int discountAmount;
  final int serviceAmount;
  final int taxAmount;
  final int total;
}

MathTotals calculateCart(List<MathLine> lines, String? discountType, double discountValue, double taxRate, {double serviceRate = 0}) {
  final totals = <int>[];
  var subtotal = 0;

  for (final line in lines) {
    final gross = ((line.price + line.modifiers) * line.quantity).round();
    final discount = line.discount.clamp(0, gross < 0 ? 0 : gross);
    totals.add(gross - discount);
    subtotal += gross - discount;
  }

  final discountAmount = switch (discountType) {
    'percent' => (subtotal * discountValue.clamp(0, 100) / 100).round(),
    'amount' => discountValue.round().clamp(0, subtotal),
    _ => 0,
  };

  final base = subtotal - discountAmount;
  final serviceAmount = (base * serviceRate.clamp(0, 100) / 100).round();
  final taxAmount = ((base + serviceAmount) * taxRate / 100).round();

  return MathTotals(
    lines: totals,
    subtotal: subtotal,
    discountAmount: discountAmount,
    serviceAmount: serviceAmount,
    taxAmount: taxAmount,
    total: base + serviceAmount + taxAmount,
  );
}

class PriceTier {
  const PriceTier({required this.min, required this.price});

  factory PriceTier.fromJson(Map<String, dynamic> json) =>
      PriceTier(min: double.tryParse('${json['min_quantity'] ?? json['min']}') ?? 0, price: (json['price'] as num?)?.toInt() ?? 0);

  final double min;
  final int price;

  Map<String, dynamic> toJson() => {'min': min, 'price': price};
}

/// Potongan ED dekat satu baris; [available] = sisa unit ED dekat produk itu setelah baris sebelumnya.
int nearExpiryDiscount(int price, double quantity, double available, double percent) {
  if (percent <= 0 || available <= 0) {
    return 0;
  }

  return (price * (quantity < available ? quantity : available) * percent / 100).round();
}

int tierPrice(int basePrice, List<PriceTier> tiers, double quantity) {
  var price = basePrice;
  var reached = -1.0;

  for (final tier in tiers) {
    if (quantity + 0.0001 >= tier.min && tier.min > reached) {
      reached = tier.min;
      price = tier.price < basePrice ? tier.price : basePrice;
    }
  }

  return price;
}

/// Penanda baris untuk tiket dapur; sama dengan KitchenTicketService::signature di server.
String lineSignature({required int productId, int? unitId, Iterable<int> modifierIds = const [], String? note}) {
  final ids = modifierIds.toList()..sort();

  return [productId, unitId ?? 0, ids.join('-'), (note ?? '').trim()].join(':');
}
