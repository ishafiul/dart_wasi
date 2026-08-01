import 'package:dart_wasi/dart_wasi.dart';

WasiHttpResponse fetch(WasiHttpRequest request) {
  Wasi.stderr.write('Dart Worker handled a request.\n');
  return WasiHttpResponse.json(200, '{"message":"Hello from Dart"}');
}
