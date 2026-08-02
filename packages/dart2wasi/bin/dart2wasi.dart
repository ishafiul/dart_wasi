import 'dart:io';

import 'package:dart2wasi/dart2wasi.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await const Dart2WasiCli().run(arguments);
}
