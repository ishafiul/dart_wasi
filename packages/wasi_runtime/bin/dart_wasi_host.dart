import 'dart:io';

import 'package:wasi_runtime/wasi_runtime.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await const DartWasiHostCli().run(arguments);
}
