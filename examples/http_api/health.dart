import 'package:dart_wasi/dart_wasi.dart';

WasiHttpResponse fetch(WasiHttpRequest request) {
  return WasiHttpResponse.json(200, '{"status":"ok"}');
}
