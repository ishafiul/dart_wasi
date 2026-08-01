import 'dart:typed_data';

/// One HTTP header field preserved in wire order.
final class WasiHttpHeader {
  const WasiHttpHeader(this.name, this.value);

  final String name;
  final String value;
}

/// Engine-neutral HTTP request passed to a WASI guest.
final class WasiHttpRequest {
  WasiHttpRequest({
    required this.method,
    required this.path,
    this.query = '',
    List<WasiHttpHeader> headers = const [],
    List<int> body = const [],
  }) : headers = List.unmodifiable(headers),
       body = Uint8List.fromList(body).asUnmodifiableView();

  final String method;
  final String path;
  final String query;
  final List<WasiHttpHeader> headers;
  final Uint8List body;
}

/// HTTP response decoded from a WASI guest's stdout.
final class WasiHttpResponse {
  WasiHttpResponse({
    required this.status,
    List<WasiHttpHeader> headers = const [],
    List<int> body = const [],
  }) : headers = List.unmodifiable(headers),
       body = Uint8List.fromList(body).asUnmodifiableView();

  final int status;
  final List<WasiHttpHeader> headers;
  final Uint8List body;

  /// Returns the first header value with a case-insensitive [name].
  String? header(String name) {
    final normalizedName = name.toLowerCase();
    for (final header in headers) {
      if (header.name.toLowerCase() == normalizedName) {
        return header.value;
      }
    }
    return null;
  }
}
