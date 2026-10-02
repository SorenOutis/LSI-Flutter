import 'dart:async';

import 'package:dio/dio.dart';

import '../config.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';
import 'fake/fake_api_adapter.dart';

typedef UnauthorizedHandler = void Function();

/// The single HTTP client for the app.
///
/// Two behaviours here are deliberate and load-bearing:
///
/// * **Redirects are disabled.** A handful of routes still answer with a 302
///   (a POST that submits an exam part, the NGL like toggle). If Dio followed
///   them, the POST would be replayed as a GET against an HTML page and the
///   client would see a 200 with no way to tell the write never happened.
///  Not following redirects turns those into a visible failure instead of a
///  silent no-op.
/// * **401 is handled once, centrally.** Any endpoint can invalidate the token
///  (revoked, user deleted), so the interceptor clears storage and notifies the
///  app rather than leaving each screen to guess.
class ApiClient {
  ApiClient({required this._tokenStorage, Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options = _dio.options.copyWith(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      responseType: ResponseType.json,
      headers: const {'Accept': 'application/json'},
      followRedirects: false,
      validateStatus: (int? status) => status != null && status < 400,
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) async {
          final String? token = await _tokenStorage.read();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          options.headers['Accept'] = 'application/json';
          handler.next(options);
        },
      ),
    );

    // Replacing the adapter rather than branching inside each request method
    // keeps the interceptors, error mapping and 401 handling on the same path
    // as production, so fake-mode UI exercises real client behaviour.
    if (AppConfig.useFakeApi) _dio.httpClientAdapter = FakeApiAdapter();
  }

  final Dio _dio;
  final TokenStorage _tokenStorage;

  UnauthorizedHandler? onUnauthorized;

  Dio get raw => _dio;

  Future<Map<String, dynamic>> getJson(String path, {Map<String, dynamic>? query}) async {
    return _unwrap(() => _dio.get<dynamic>(path, queryParameters: query));
  }

  Future<Map<String, dynamic>> postJson(String path, {Object? body}) async {
    return _unwrap(() => _dio.post<dynamic>(path, data: body));
  }

  Future<Map<String, dynamic>> putJson(String path, {Object? body}) async {
    return _unwrap(() => _dio.put<dynamic>(path, data: body));
  }

  Future<Map<String, dynamic>> patchJson(String path, {Object? body}) async {
    return _unwrap(() => _dio.patch<dynamic>(path, data: body));
  }

  Future<Map<String, dynamic>> deleteJson(String path) async {
    return _unwrap(() => _dio.delete<dynamic>(path));
  }

  /// Normalise every response to a JSON object.
  ///
  /// A bare list or `null` body becomes an empty map so callers can index
  /// without a null check; anything genuinely non-object is wrapped so no
  /// response shape can crash the app.
  Future<Map<String, dynamic>> _unwrap(Future<Response<dynamic>> Function() send) async {
    try {
      final Response<dynamic> response = await send();
      final Object? data = response.data;

      if (data is Map<String, dynamic>) return data;
      if (data is Map) return data.cast<String, dynamic>();
      if (data is List) return {'data': data};
      return const {};
    } on DioException catch (error) {
      final DioException normalized = _asDioException(error);
      final ApiException apiError = ApiException.fromDio(normalized);

      if (apiError.isUnauthorized) {
        await _tokenStorage.clear();
        onUnauthorized?.call();
      }

      throw apiError;
    }
  }

  /// An HTML error page (a redirect that leaked through, a 500 from the proxy)
  /// surfaces as a non-JSON body; force it through the same message extraction.
  DioException _asDioException(DioException error) {
    if (error.response?.data is String && error.response?.data != '') {
      return error.copyWith(
        response: Response<dynamic>(
          requestOptions: error.requestOptions,
          statusCode: error.response?.statusCode,
          data: <String, dynamic>{'message': 'The server returned an unexpected response.'},
        ),
      );
    }

    return error;
  }
}