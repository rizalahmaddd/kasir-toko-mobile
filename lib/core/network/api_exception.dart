import 'package:dio/dio.dart';

class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.reason,
    this.context = const {},
    this.fieldErrors = const {},
    this.isNetworkError = false,
  });

  factory ApiException.fromDio(DioException error) {
    final response = error.response;

    if (response == null) {
      final timedOut = error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout;

      return ApiException(
        message: timedOut
            ? 'Server tidak merespons. Periksa koneksi lalu coba lagi.'
            : 'Tidak bisa terhubung ke server. Periksa koneksi dan alamat server.',
        isNetworkError: true,
      );
    }

    final data = response.data;
    final body = data is Map<String, dynamic> ? data : const <String, dynamic>{};
    final errors = <String, List<String>>{};

    if (body['errors'] is Map) {
      (body['errors'] as Map).forEach((key, value) {
        errors['$key'] = value is List ? value.map((e) => '$e').toList() : ['$value'];
      });
    }

    return ApiException(
      message: body['message'] as String? ?? _fallbackMessage(response.statusCode),
      statusCode: response.statusCode,
      reason: body['reason'] as String?,
      context: body['context'] is Map<String, dynamic>
          ? body['context'] as Map<String, dynamic>
          : const {},
      fieldErrors: errors,
    );
  }

  final String message;
  final int? statusCode;

  /// Business rejection code from the POS endpoints, e.g. `price_changed` or `no_shift`.
  final String? reason;
  final Map<String, dynamic> context;
  final Map<String, List<String>> fieldErrors;
  final bool isNetworkError;

  bool get isUnauthenticated => statusCode == 401;

  String? fieldError(String field) => fieldErrors[field]?.first;

  static String _fallbackMessage(int? status) => switch (status) {
        402 => 'Masa aktif toko sudah berakhir. Hubungi admin layanan.',
        403 => 'Akun Anda tidak punya izin untuk aksi ini.',
        404 => 'Data tidak ditemukan.',
        429 => 'Terlalu banyak permintaan. Tunggu sebentar lalu coba lagi.',
        _ => 'Terjadi kesalahan di server ($status).',
      };

  @override
  String toString() => message;
}
