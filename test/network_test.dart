import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_pos_mobile/core/config/server_config.dart';
import 'package:web_pos_mobile/core/network/api_exception.dart';

DioException _response(int status, Map<String, dynamic> body) {
  final options = RequestOptions(path: 'pos/checkout');

  return DioException(
    requestOptions: options,
    response: Response(requestOptions: options, statusCode: status, data: body),
    type: DioExceptionType.badResponse,
  );
}

void main() {
  test('server address is normalized to the app root', () {
    expect(ServerUrlNotifier.normalize(' 192.168.1.10:8000/ '), 'http://192.168.1.10:8000');
    expect(ServerUrlNotifier.normalize('https://kasir.toko.id/api/v1'), 'https://kasir.toko.id');
    expect(ServerUrlNotifier.normalize('https://kasir.toko.id/api'), 'https://kasir.toko.id');
  });

  test('POS rejections keep reason and context', () {
    final error = ApiException.fromDio(_response(422, {
      'message': 'Harga Sabun sudah berubah.',
      'errors': {
        'message': ['Harga Sabun sudah berubah.'],
      },
      'reason': 'price_changed',
      'context': {
        'prices': {
          '2': {'price': 4500, 'name': 'Sabun'},
        },
      },
    }));

    expect(error.statusCode, 422);
    expect(error.reason, 'price_changed');
    expect(error.context['prices'], isA<Map<String, dynamic>>());
    expect(error.message, 'Harga Sabun sudah berubah.');
  });

  test('validation errors are exposed per field', () {
    final error = ApiException.fromDio(_response(422, {
      'message': 'Username atau password salah.',
      'errors': {
        'login': ['Username atau password salah.'],
      },
    }));

    expect(error.fieldError('login'), 'Username atau password salah.');
    expect(error.fieldError('password'), isNull);
  });

  test('no response is reported as a network error', () {
    final error = ApiException.fromDio(
      DioException(requestOptions: RequestOptions(path: 'x'), type: DioExceptionType.connectionError),
    );

    expect(error.isNetworkError, isTrue);
    expect(error.statusCode, isNull);
  });
}
