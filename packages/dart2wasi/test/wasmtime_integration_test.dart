import 'dart:io';

import 'package:dart2wasi/dart2wasi.dart';
import 'package:test/test.dart';

import 'support/guest_fixture.dart';

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

  test(
    'runtime stdin bytes round-trip through independent Wasmtime',
    () async {
      final outputDirectory = await Directory.systemTemp.createTemp(
        'dart2wasi-wasmtime-echo-',
      );
      addTearDown(() => outputDirectory.delete(recursive: true));

      final wasmFile = File('${outputDirectory.path}/echo.wasm');
      final bytes = await const MinimalDartToWasiCompiler().compile(
        guestFixtureUri('echo'),
      );
      await wasmFile.writeAsBytes(bytes);

      final process = await Process.start('wasmtime', [wasmFile.path]);
      final stdoutFuture = process.stdout.fold<List<int>>(
        <int>[],
        (bytes, chunk) => bytes..addAll(chunk),
      );
      final stderrFuture = process.stderr.fold<List<int>>(
        <int>[],
        (bytes, chunk) => bytes..addAll(chunk),
      );
      const input = [0, 1, 2, 127, 128, 255];
      process.stdin.add(input);
      await process.stdin.close();

      final exitCode = await process.exitCode;
      final stdout = await stdoutFuture;
      final stderr = await stderrFuture;

      expect(exitCode, 0);
      expect(stdout, input);
      expect(stderr, isEmpty);
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
