import 'package:intl/intl.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';
import 'package:web_pos_mobile/core/constants/date_formats.dart';

final _rupiah = NumberFormat.currency(locale: AppDateFormat.locale, symbol: 'Rp', decimalDigits: 0);
final _number = NumberFormat.decimalPattern(AppDateFormat.locale);
final _quantity = NumberFormat('#,##0.###', AppDateFormat.locale);
final _dateTime = DateFormat(AppDateFormat.dateTimeMinutes, AppDateFormat.locale);
final _date = DateFormat(AppDateFormat.date, AppDateFormat.locale);
final _weekdayDate = DateFormat(AppDateFormat.weekdayDate, AppDateFormat.locale);
final _time = DateFormat(AppDateFormat.time, AppDateFormat.locale);

String rupiah(num value) => _rupiah.format(value);

String thousands(num value) => _number.format(value);

String quantity(num value) => _quantity.format(value);

String dateTime(DateTime value) => _dateTime.format(value.toLocal());

String dateOnly(DateTime value) => _date.format(value.toLocal());

String weekdayDate(DateTime value) => _weekdayDate.format(value.toLocal());

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
    return '${_short.format(value / 1e9)} ${CoreStrings.compactBillionSuffix}';
  }
  if (abs >= 1e6) {
    return '${_short.format(value / 1e6)} ${CoreStrings.compactMillionSuffix}';
  }
  if (abs >= 1e3) {
    return '${_short.format(value / 1e3)} ${CoreStrings.compactThousandSuffix}';
  }

  return _short.format(value);
}

final _short = NumberFormat('#,##0.#', AppDateFormat.locale);

String percent(num value) => '${_short.format(value)}${CoreStrings.percentSuffix}';
