import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('compiles a guest with the documented compile command', () async {
    final directory = await Directory.systemTemp.createTemp('dart2wasi-cli-');
    addTearDown(() => directory.delete(recursive: true));
    final output = File('${directory.path}/hello.wasm');

    final result = await Process.run(Platform.resolvedExecutable, [
      'run',
      'bin/dart2wasi.dart',
      'compile',
      'test/fixtures/hello.dart',
      '-o',
      output.path,
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(
      (await output.readAsBytes()).take(4),
      orderedEquals([0, 0x61, 0x73, 0x6d]),
    );
  });

  test('reports usage for an incomplete command', () async {
    final result = await Process.run(Platform.resolvedExecutable, [
      'run',
      'bin/dart2wasi.dart',
      'compile',
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, 64);
    expect(result.stderr.toString(), contains('Usage: dart2wasi compile'));
  });
}
