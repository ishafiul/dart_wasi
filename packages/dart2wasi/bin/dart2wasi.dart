import 'dart:io';

import 'package:dart2wasi/dart2wasi.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    stderr.writeln('Usage: dart2wasi <entrypoint.dart> <output.wasm>');
    exitCode = 64;
    return;
  }

  try {
    final output = await const MinimalDartToWasiCompiler().compile(
      File(arguments[0]).absolute.uri,
    );
    await File(arguments[1]).writeAsBytes(output, flush: true);
  } on UnsupportedDartFeatureException catch (error) {
    stderr.writeln(error.message);
    exitCode = 65;
  }
}
