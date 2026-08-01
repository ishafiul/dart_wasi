import 'dart:io';

import 'package:dart2wasi/dart2wasi.dart';
import 'package:test/test.dart';

Future<void> main() async {
  final wasmtimeAvailable = await _isWasmtimeAvailable();

  test(
    'generated command runs in the independent Wasmtime runtime',
    () async {
      final outputDirectory = await Directory.systemTemp.createTemp(
        'dart2wasi-wasmtime-',
      );
      addTearDown(() => outputDirectory.delete(recursive: true));

      final wasmFile = File('${outputDirectory.path}/hello.wasm');
      final bytes = const MinimalDartToWasiCompiler().compileSource('''
import 'package:dart_wasi/dart_wasi.dart';

void main() {
  Wasi.stdout.write('Hello from Dart!\\n');
}
''');
      await wasmFile.writeAsBytes(bytes);

      final result = await Process.run('wasmtime', [wasmFile.path]);

      expect(result.exitCode, 0);
      expect(result.stdout, 'Hello from Dart!\n');
      expect(result.stderr, isEmpty);
    },
    skip: wasmtimeAvailable
        ? false
        : 'Wasmtime is not installed locally; CI installs and runs it.',
  );
}

Future<bool> _isWasmtimeAvailable() async {
  try {
    final result = await Process.run('wasmtime', ['--version']);
    return result.exitCode == 0;
  } on ProcessException {
    return false;
  }
}
