import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/server_config.dart';
import 'api_exception.dart';

/// In-memory copy of the Bearer token; the persisted copy lives in secure storage.
final authTokenProvider = NotifierProvider<AuthTokenNotifier, String?>(AuthTokenNotifier.new);

class AuthTokenNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? token) => state = token;
}

/// Called when the server answers 401 so the app can drop the session.
final unauthorizedHandlerProvider = Provider<void Function()>((ref) => () {});

final dioProvider = Provider<Dio>((ref) {
  final serverUrl = ref.watch(serverUrlProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: '$serverUrl/api/v1/',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = ref.read(authTokenProvider);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        final hadToken = error.requestOptions.headers.containsKey('Authorization');
        if (error.response?.statusCode == 401 && hadToken) {
          ref.read(unauthorizedHandlerProvider)();
        }
        handler.next(error);
      },
    ),
  );

  return dio;
});

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(ref.watch(dioProvider)));

class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: _clean(query)));

  Future<dynamic> post(String path, {Object? data}) => _send(() => _dio.post<dynamic>(path, data: data));

  Future<dynamic> delete(String path) => _send(() => _dio.delete<dynamic>(path));

  Future<String> getText(String path, {Map<String, dynamic>? query}) async {
    final response = await _send(
      () => _dio.get<dynamic>(
        path,
        queryParameters: _clean(query),
        options: Options(responseType: ResponseType.plain, headers: {'Accept': 'text/html'}),
      ),
    );

    return '$response';
  }

  /// Unwraps the `data` envelope of Laravel API resources.
  static Map<String, dynamic> data(dynamic body) => (body as Map<String, dynamic>)['data'] as Map<String, dynamic>;

  static List<Map<String, dynamic>> list(dynamic body) =>
      ((body as Map<String, dynamic>)['data'] as List).cast<Map<String, dynamic>>();

  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      return response.data;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) {
      return null;
    }

    return Map.of(query)..removeWhere((key, value) => value == null || value == '');
  }
}

class Paginated<T> {
  const Paginated({required this.items, required this.currentPage, required this.lastPage, this.meta = const {}});

  factory Paginated.fromJson(dynamic body, T Function(Map<String, dynamic>) parse) {
    final json = body as Map<String, dynamic>;
    final meta = json['meta'] as Map<String, dynamic>? ?? const {};

    return Paginated(
      items: (json['data'] as List).cast<Map<String, dynamic>>().map(parse).toList(),
      currentPage: meta['current_page'] as int? ?? 1,
      lastPage: meta['last_page'] as int? ?? 1,
      meta: meta,
    );
  }

  final List<T> items;
  final int currentPage;
  final int lastPage;
  final Map<String, dynamic> meta;

  bool get hasMore => currentPage < lastPage;
}
