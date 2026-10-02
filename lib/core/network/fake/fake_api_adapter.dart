import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'fake_backend.dart';

/// Swaps the socket for [FakeBackend] so every request is answered in-process.
///
/// Installed in place of Dio's default adapter, which means the rest of the
/// networking stack (interceptors, error mapping, `ApiException`) is exercised
/// exactly as it would be against a real server.
class FakeApiAdapter implements HttpClientAdapter {
  FakeApiAdapter({FakeBackend? backend}) : _backend = backend ?? FakeBackend();

  final FakeBackend _backend;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final String? rawBody = await _readBody(requestStream);
    final FakeResponse response = await _backend.handle(options, rawBody);

    return ResponseBody.fromString(
      jsonEncode(response.body),
      response.statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  /// Drains the outgoing stream so POST/PUT bodies reach the fake backend.
  Future<String?> _readBody(Stream<Uint8List>? requestStream) async {
    if (requestStream == null) return null;

    final List<int> bytes = await requestStream.expand((Uint8List chunk) => chunk).toList();
    if (bytes.isEmpty) return null;

    return utf8.decode(bytes);
  }

  @override
  void close({bool force = false}) {}
}