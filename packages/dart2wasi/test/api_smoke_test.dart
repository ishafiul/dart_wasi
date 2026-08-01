import 'dart:convert';
import 'dart:typed_data';

import 'package:dart2wasi/dart2wasi.dart';
import 'package:test/test.dart';
import 'package:wasi_runtime/wasi_runtime.dart';

void main() {
  test('compiler contract is public', () {
    const error = UnsupportedDartFeatureException('unsupported');
    expect(error.message, 'unsupported');
    expect(supportedDartWasiGuestApiVersion, 1);
  });

  test(
    'compiles a Dart stdout intrinsic into a WASI Preview 1 command',
    () async {
      final bytes = const MinimalDartToWasiCompiler().compileSource('''
import 'package:dart_wasi/dart_wasi.dart';

void main() {
  Wasi.stdout.write('Hello from Dart!\n');
}
''');
      final engine = WasdEngine();
      final module = await engine.compile(bytes);
      const expectedImports = <String>[
        'wasi_snapshot_preview1.fd_write',
        'wasi_snapshot_preview1.proc_exit',
      ];

      expect(bytes.take(8), [0, 0x61, 0x73, 0x6d, 1, 0, 0, 0]);
      expect(bytes, containsAll(utf8.encode('dart_wasi.sdk')));
      expect(
        module.imports.map((value) => '${value.module}.${value.name}'),
        expectedImports,
      );
      expect(
        module.exports,
        contains(
          isA<WasmExport>()
              .having((value) => value.name, 'name', '_start')
              .having((value) => value.kind, 'kind', WasmExternalKind.function),
        ),
      );
      expect(
        bytes,
        containsAll(Uint8List.fromList('Hello from Dart!\n'.codeUnits)),
      );

      final result = await module.runWasi();
      expect(result.exitCode, 0);
      expect(utf8.decode(result.stdout), 'Hello from Dart!\n');
      expect(result.stderr, isEmpty);
    },
  );

  test('rejects Dart outside the supported subset', () {
    expect(
      () => const MinimalDartToWasiCompiler().compileSource('''
void main() async {
  print('not supported');
}
'''),
      throwsA(
        isA<UnsupportedDartFeatureException>().having(
          (error) => error.message,
          'message',
          contains('Expected'),
        ),
      ),
    );
  });

  test(
    'runs locals, integer and boolean expressions, calls, if, and while',
    () async {
      final bytes = const MinimalDartToWasiCompiler().compileSource('''
import 'package:dart_wasi/dart_wasi.dart';

int addOne(int value) {
  return value + 1;
}

void main() {
  int count = 0;
  while (count < 2) {
    count = addOne(count);
  }
  if (count == 2 && true) {
    Wasi.stdout.write('subset works\n');
  } else {
    Wasi.stdout.write('unexpected\n');
  }
}
''');
      final module = await const WasdEngine().compile(bytes);
      final result = await module.runWasi();

      expect(result.exitCode, 0);
      expect(utf8.decode(result.stdout), 'subset works\n');
    },
  );

  test('rejects ill-typed intrinsics before code generation', () {
    expect(
      () => const MinimalDartToWasiCompiler().compileSource('''
import 'package:dart_wasi/dart_wasi.dart';

void main() {
  Wasi.stdout.writeBytes(42);
}
'''),
      throwsA(
        isA<UnsupportedDartFeatureException>().having(
          (error) => error.message,
          'message',
          contains('writeBytes argument must be WasiBytes'),
        ),
      ),
    );
  });
}
