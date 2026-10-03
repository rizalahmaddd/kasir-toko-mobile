import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_pos_mobile/core/config/server_config.dart';
import 'package:web_pos_mobile/core/network/api_client.dart';
import 'package:web_pos_mobile/core/network/api_exception.dart';
import 'package:web_pos_mobile/core/offline/offline_cache.dart';

class _MemoryCache extends OfflineCache {
  _MemoryCache(SharedPreferences prefs) : super(prefs, 'test');

  final saved = <String, Object?>{};

  @override
  Future<void> putResponse(String key, Object? body) async => saved[key] = body;

  @override
  Future<dynamic> getResponse(String key) async => saved[key];
}

/// Answers every request with [body], or fails without a response while [offline] is true.
class _FakeServer extends Interceptor {
  bool offline = false;
  Object? body = const {'data': 'fresh'};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) => offline
      ? handler.reject(DioException(requestOptions: options, type: DioExceptionType.connectionError))
      : handler.resolve(Response(requestOptions: options, statusCode: 200, data: body));
}

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

  group('offline copies of GET responses', () {
    late _FakeServer server;
    late _MemoryCache cache;
    late ApiClient api;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      server = _FakeServer();
      cache = _MemoryCache(await SharedPreferences.getInstance());
      api = ApiClient(Dio()..interceptors.add(server), () => cache);
    });

    test('the last answer is replayed when the server is unreachable, whatever the query order', () async {
      await api.get('sales', query: {'to': '2026-10-03', 'from': '2026-10-01', 'search': ''});
      server.offline = true;

      expect(await api.get('sales', query: {'from': '2026-10-01', 'to': '2026-10-03'}), {'data': 'fresh'});
    });

    test('a request never answered before says it is not on the device', () async {
      server.offline = true;

      await expectLater(
        api.get('dashboard'),
        throwsA(isA<ApiException>().having((e) => e.isNetworkError, 'network', isTrue).having((e) => e.message, 'message', contains('belum pernah dibuka'))),
      );
    });

    test('shift and login state are never replayed', () async {
      await api.get('pos/shift');
      await api.get('auth/me');
      server.offline = true;

      expect(cache.saved, isEmpty);
      await expectLater(api.get('pos/shift'), throwsA(isA<ApiException>()));
    });
  });
}
