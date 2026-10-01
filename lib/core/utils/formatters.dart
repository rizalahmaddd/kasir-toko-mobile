import 'package:intl/intl.dart';

final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
final _number = NumberFormat.decimalPattern('id_ID');
final _quantity = NumberFormat('#,##0.###', 'id_ID');
final _dateTime = DateFormat('d MMM yyyy, HH:mm', 'id_ID');
final _date = DateFormat('d MMM yyyy', 'id_ID');
final _time = DateFormat('HH:mm', 'id_ID');

String rupiah(num value) => _rupiah.format(value);

String thousands(num value) => _number.format(value);

String quantity(num value) => _quantity.format(value);

String dateTime(DateTime value) => _dateTime.format(value.toLocal());

String dateOnly(DateTime value) => _date.format(value.toLocal());

String timeOnly(DateTime value) => _time.format(value.toLocal());

/// Reads "50.000", "50000" or "Rp 50.000" as 50000. Rupiah has no decimals in this app.
int parseRupiah(String input) => int.tryParse(input.replaceAll(RegExp('[^0-9]'), '')) ?? 0;

/// Ungrouped form for editable fields; `quantity()` would turn 1000 into "1.000", which reads back as 1.
String editableQuantity(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toString().replaceAll('.', ',');

/// Accepts both "1,5" and "1.5" since cashiers type weights either way.
double? parseQuantity(String input) => double.tryParse(input.trim().replaceAll(',', '.'));

/// Short axis labels: 1.250.000 → "1,3 jt", 25.000 → "25 rb".
String compactNumber(num value) {
  final abs = value.abs();
  if (abs >= 1e9) {
    return '${_short.format(value / 1e9)} M';
  }
  if (abs >= 1e6) {
    return '${_short.format(value / 1e6)} jt';
  }
  if (abs >= 1e3) {
    return '${_short.format(value / 1e3)} rb';
  }

  return _short.format(value);
}

final _short = NumberFormat('#,##0.#', 'id_ID');

String percent(num value) => '${_short.format(value)}%';
