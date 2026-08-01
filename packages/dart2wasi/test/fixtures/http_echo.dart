import 'package:dart_wasi/dart_wasi.dart';

WasiHttpResponse fetch(WasiHttpRequest request) {
  if (request.headerCount == 1) {
    Wasi.stderr.writeBytes(request.method);
    Wasi.stderr.write('|');
    Wasi.stderr.writeBytes(request.path);
    Wasi.stderr.write('|');
    Wasi.stderr.writeBytes(request.query);
    Wasi.stderr.write('|');
    Wasi.stderr.writeBytes(request.headerNameAt(0));
    Wasi.stderr.write('|');
    Wasi.stderr.writeBytes(request.headerValueAt(0));
    return WasiHttpResponse.binary(
      201,
      request.body,
      'application/octet-stream',
    );
  }
  return WasiHttpResponse.text(400, 'expected one header');
}
