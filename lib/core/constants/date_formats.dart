/// Pola format tanggal/waktu dan locale yang dipakai aplikasi.
abstract final class AppDateFormat {
  static const locale = 'id_ID';

  static const dateTimeMinutes = 'd MMM yyyy, HH:mm';
  static const date = 'd MMM yyyy';
  static const dateShort = 'd MMM y';
  static const dateLong = 'd MMMM y';
  static const weekdayDate = 'EEEE, d MMM yyyy';
  static const time = 'HH:mm';

  /// Format tanggal untuk dikirim ke API.
  static const api = 'yyyy-MM-dd';
}
