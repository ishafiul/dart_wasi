import 'dart:convert';
import 'dart:io';

import 'package:dart2wasi/dart2wasi.dart';
import 'package:test/test.dart';
import 'package:wasi_runtime/wasi_runtime.dart';

void main() {
  group('HTTP API example', () {
    test('health endpoint returns a JSON health response', () async {
      final result = await _runWorker('health');

      expect(result.response.status, 200);
      expect(result.response.header('content-type'), 'application/json');
      expect(utf8.decode(result.response.body), '{"status":"ok"}');
    });

    test('echo endpoint preserves binary request bodies', () async {
      final result = await _runWorker('echo', body: [0, 1, 127, 128, 255]);

      expect(result.response.status, 200);
      expect(
        result.response.header('content-type'),
        'application/octet-stream',
      );
      expect(result.response.body, orderedEquals([0, 1, 127, 128, 255]));
    });

    test('info endpoint returns service metadata', () async {
      final result = await _runWorker('info');

      expect(result.response.status, 200);
      expect(
        utf8.decode(result.response.body),
        '{"service":"dart-wasi-http-api","version":1}',
      );
    });
  });
}

Future<WasiHttpExecutionResult> _runWorker(
  String worker, {
  List<int> body = const [],
}) async {
  final root = Directory.current.uri.resolve('../../');
  final bytes = await const MinimalDartToWasiCompiler().compile(
    root.resolve('examples/http_api/$worker.dart'),
  );
  final module = await const WasdEngine().compile(bytes);
  return module.runHttp(
    WasiHttpRequest(method: 'POST', path: '/api/$worker', body: body),
  );
}
