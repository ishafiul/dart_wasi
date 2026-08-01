import 'dart:async';
import 'dart:io';

import 'dispatcher.dart';
import 'models.dart';

/// Adapts a [WasiHttpDispatcher] to a Dart [HttpServer].
final class WasiHttpServer {
  const WasiHttpServer(this._dispatcher);

  final WasiHttpDispatcher _dispatcher;

  /// Handles one incoming request and always closes its response.
  Future<void> handle(HttpRequest request) async {
    final response = await _dispatcher.dispatch(
      hostname: _hostname(request),
      request: WasiHttpRequest(
        method: request.method,
        path: request.uri.path,
        query: request.uri.query,
        headers: _headers(request.headers),
        body: await request.fold(<int>[], (body, chunk) => body..addAll(chunk)),
      ),
    );
    request.response.statusCode = response.status;
    for (final header in response.headers) {
      request.response.headers.add(header.name, header.value);
    }
    request.response.add(response.body);
    await request.response.close();
  }

  /// Begins serving requests from [server] until its subscription is cancelled.
  StreamSubscription<HttpRequest> serve(HttpServer server) =>
      server.listen(handle);
}

String _hostname(HttpRequest request) {
  final host = request.headers.host;
  if (host == null) {
    return '';
  }
  return host.startsWith('[') ? host : host.split(':').first;
}

List<WasiHttpHeader> _headers(HttpHeaders headers) {
  final result = <WasiHttpHeader>[];
  headers.forEach((name, values) {
    for (final value in values) {
      result.add(WasiHttpHeader(name, value));
    }
  });
  return result;
}
