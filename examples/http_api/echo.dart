import 'package:dart_wasi/dart_wasi.dart';

WasiHttpResponse fetch(WasiHttpRequest request) {
  return WasiHttpResponse.binary(200, request.body, 'application/octet-stream');
}
