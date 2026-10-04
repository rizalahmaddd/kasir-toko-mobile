import 'package:flutter_test/flutter_test.dart';
import 'package:web_pos_mobile/features/pos/data/pos_models.dart';

CartItem _item({required int price, required double quantity, int discount = 0}) => CartItem(
      productId: price,
      name: 'Item',
      unit: 'pcs',
      price: price,
      quantity: quantity,
      discount: discount,
      trackStock: false,
      stock: 0,
    );

void main() {
  // Same fixtures as tests/Unit/CartCalculatorTest.php on the server, so a drift shows up here first.
  test('line and transaction discounts are applied before tax', () {
    final totals = CartTotals.calculate(
      [_item(price: 12500, quantity: 2, discount: 1000), _item(price: 18000, quantity: 0.5)],
      DiscountType.percent,
      10,
      11,
    );

    expect(totals.subtotal, 33000);
    expect(totals.discountAmount, 3300);
    expect(totals.taxAmount, 3267);
    expect(totals.total, 32967);
  });

  test('discounts never exceed what they discount', () {
    final item = _item(price: 5000, quantity: 1, discount: 9000);
    final totals = CartTotals.calculate([item], DiscountType.amount, 99999, 0);

    expect(item.total, 0);
    expect(totals.total, 0);
  });

  test('fractional quantities round half away from zero like PHP round()', () {
    expect(_item(price: 3, quantity: 0.5).gross, 2);
    expect(_item(price: 18333, quantity: 1.5).gross, 27500);
  });
}
