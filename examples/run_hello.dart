import 'dart:convert';
import 'dart:io';

import 'package:dart2wasi/dart2wasi.dart';
import 'package:wasi_runtime/wasi_runtime.dart';

Future<void> main() async {
  final bytes = await const MinimalDartToWasiCompiler().compile(
    File('examples/hello.dart').absolute.uri,
  );
  final module = await const WasdEngine().compile(bytes);
  final result = await module.runWasi();
  stdout.write(utf8.decode(result.stdout, allowMalformed: true));
  stderr.write(utf8.decode(result.stderr, allowMalformed: true));
  print('Guest exited with ${result.exitCode}.');
}
