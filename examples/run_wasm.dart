import 'dart:convert';
import 'dart:io';

import 'package:wasi_runtime/wasi_runtime.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('Usage: dart run examples/run_wasm.dart <module.wasm>');
    exitCode = 64;
    return;
  }

  final bytes = await File(arguments.single).readAsBytes();
  final module = await const WasdEngine().compile(bytes);
  final result = await module.runWasi();
  stdout.write(utf8.decode(result.stdout, allowMalformed: true));
  stderr.write(utf8.decode(result.stderr, allowMalformed: true));
  print('Guest exited with ${result.exitCode}.');
}
