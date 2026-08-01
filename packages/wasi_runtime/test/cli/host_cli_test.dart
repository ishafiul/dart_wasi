import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('inspects a valid WebAssembly artifact', () async {
    final directory = await Directory.systemTemp.createTemp('dart-wasi-host-');
    addTearDown(() => directory.delete(recursive: true));
    final artifact = File('${directory.path}/empty.wasm');
    await artifact.writeAsBytes(const [0, 0x61, 0x73, 0x6d, 1, 0, 0, 0]);

    final result = await Process.run(Platform.resolvedExecutable, [
      'run',
      'bin/dart_wasi_host.dart',
      'inspect',
      artifact.path,
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(result.stdout.toString(), contains('engine: wasd 0.3.0 (preview1)'));
    expect(result.stdout.toString(), contains('imports:\n  (none)'));
    expect(result.stdout.toString(), contains('exports:\n  (none)'));
  });

  test('reports usage for an unsupported host command', () async {
    final result = await Process.run(Platform.resolvedExecutable, [
      'run',
      'bin/dart_wasi_host.dart',
      'unknown',
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, 64);
    expect(result.stderr.toString(), contains('dart_wasi_host inspect'));
  });
}
