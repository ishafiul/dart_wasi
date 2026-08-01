import 'dart:convert';
import 'dart:io';

import 'package:dart2wasi/dart2wasi.dart';
import 'package:wasi_runtime/wasi_runtime.dart';

Future<void> main() async {
  final artifact = await const MinimalDartToWasiCompiler().compile(
    File('examples/http_worker.dart').absolute.uri,
  );
  final module = await const WasdEngine().compile(artifact);
  final execution = await module.runHttp(
    WasiHttpRequest(
      method: 'POST',
      path: '/hello',
      query: 'source=example',
      headers: const [WasiHttpHeader('x-request-id', 'demo-1')],
      body: utf8.encode('request body'),
    ),
  );

  final response = execution.response;
  print('HTTP ${response.status}');
  for (final header in response.headers) {
    print('${header.name}: ${header.value}');
  }
  print(utf8.decode(response.body));
  stderr.add(execution.stderr);
}
