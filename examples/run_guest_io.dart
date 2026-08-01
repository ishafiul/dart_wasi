import 'dart:convert';
import 'dart:io';

import 'package:dart2wasi/dart2wasi.dart';
import 'package:wasi_runtime/wasi_runtime.dart';

Future<void> main() async {
  final bytes = await const MinimalDartToWasiCompiler().compile(
    File('examples/guest_io.dart').absolute.uri,
  );
  final module = await const WasdEngine().compile(bytes);
  final result = await module.runWasi(
    WasiExecutionOptions(
      arguments: const ['worker', 'demo'],
      environment: const {'MODE': 'production'},
      stdin: utf8.encode('hello from the host\n'),
    ),
  );

  stdout.add(result.stdout);
  stderr.add(result.stderr);
  print('Guest exited with ${result.exitCode}.');
}
