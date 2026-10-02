import 'package:dio/dio.dart';

/// A failure that already carries a message worth showing a student.
///
/// Wrapping transport and HTTP errors means the UI never has to reason about
/// DioException, and a Laravel `ValidationException` (422) surfaces its field
/// messages instead of a generic "something went wrong".
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.fieldErrors = const {}});

  final String message;

  final int? statusCode;

  /// Laravel validation errors keyed by field, e.g. `{"email": ["..."]}`.
  final Map<String, List<String>> fieldErrors;

  /// The token is gone or revoked: the session must be cleared and the user
  /// sent back to login.
  bool get isUnauthorized => statusCode == 401;

  /// The submission already exists (single attempt per part) or the request
  /// conflicts with current server state. Not retryable.
  bool get isConflict => statusCode == 409;

  bool get isForbidden => statusCode == 403;

  bool get isValidation => statusCode == 422;

  String? fieldError(String field) => _firstOrNull(fieldErrors[field]);

  static String? _firstOrNull(List<String>? values) =>
      (values == null || values.isEmpty) ? null : values.first;

  factory ApiException.fromDio(DioException error) {
    final int? statusCode = error.response?.statusCode;
    final Object? data = error.response?.data;

    if (data is Map<String, dynamic>) {
      return ApiException(
        _messageFrom(data, statusCode),
        statusCode: statusCode,
        fieldErrors: _errorsFrom(data),
      );
    }

    if (statusCode == null) {
      return ApiException(
        'Cannot reach the server. Check your connection and try again.',
        statusCode: statusCode,
      );
    }

    return ApiException(_fallbackFor(error, statusCode), statusCode: statusCode);
  }

  /// Turn a response body into something worth showing.
  ///
  /// Prefers a server-supplied message, falls back to a transport-aware one.
  static String _messageFrom(Map<String, dynamic> data, int? statusCode) {
    final Object? message = data['message'];
    if (message is String && message.trim().isNotEmpty) return message.trim();

    // A bare `{"response": "..."}` envelope: the chat endpoints return their
    // errors in this shape, sometimes alongside a 200.
    final Object? response = data['response'];
    if (response is String && response.trim().isNotEmpty) return response.trim();

    if (data['errors'] is Map) {
      final Map<String, List<String>> errors = _errorsFrom(data);
      if (errors.isNotEmpty) return errors.values.first.first;
    }

    if (statusCode == null) return _transportMessage();
    return _fallbackMessage(statusCode);
  }

  static String _transportMessage() =>
      'Cannot reach the server. Check your connection and try again.';

  static String _fallbackFor(DioException error, int? statusCode) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'The server took too long to respond.';
    }

    return _transportMessage();
  }

  static String _fallbackMessage(int? statusCode) {
    if (statusCode == null) return 'Something went wrong. Please try again.';
    if (statusCode >= 500) return 'The server hit an error. Please try again shortly.';

    return switch (statusCode) {
      401 => 'Your session has expired. Please sign in again.',
      403 => 'You do not have access to this.',
      404 => 'Not found.',
      409 => 'That conflicts with something that already exists.',
      422 => 'Please check the highlighted fields.',
      429 => 'Too many requests. Please wait a moment.',
      503 => 'This feature is temporarily unavailable.',
      _ => 'Something went wrong. Please try again.',
    };
  }

  static Map<String, List<String>> _errorsFrom(Map<String, dynamic> data) {
    final Object? errors = data['errors'];
    if (errors is! Map) return const {};

    return {
      for (final MapEntry<Object?, Object?> entry in errors.entries)
        '${entry.key}': switch (entry.value) {
          final List<dynamic> list => list.map((dynamic e) => '$e').toList(growable: false),
          null => const <String>[],
          final Object other => ['$other'],
        },
    };
  }

  @override
  String toString() => message;
}