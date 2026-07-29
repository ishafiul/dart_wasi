import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:wasi_runtime/wasi_runtime.dart';

void main() {
  const engine = WasdEngine();

  test('validates, compiles, inspects, and invokes a module', () async {
    final bytes = Uint8List.fromList(_simpleModule);

    expect(engine.validate(bytes), isTrue);
    final module = await engine.compile(bytes);

    expect(module.imports, isEmpty);
    expect(
      module.exports.where((value) => value.name == 'add').single.kind,
      WasmExternalKind.function,
    );

    final instance = await module.instantiate();
    expect(instance.invoke('add', [20, 22]), 42);
  });

  test('invalid bytes produce a stable validation failure', () async {
    final bytes = Uint8List.fromList([0, 1, 2]);

    expect(engine.validate(bytes), isFalse);
    await expectLater(
      engine.compile(bytes),
      throwsA(isA<WasmValidationException>()),
    );
  });

  test('missing function export produces a stable export failure', () async {
    final module = await engine.compile(Uint8List.fromList(_simpleModule));
    final instance = await module.instantiate();

    expect(
      () => instance.invoke('missing'),
      throwsA(isA<WasmExportException>()),
    );
  });

  test('missing imports produce a stable link failure', () async {
    final module = await engine.compile(Uint8List.fromList(_hostImportModule));

    await expectLater(module.instantiate(), throwsA(isA<WasmLinkException>()));
  });

  test('host functions are linked and invoked', () async {
    final module = await engine.compile(Uint8List.fromList(_hostImportModule));
    final instance = await module.instantiate(
      imports: {
        'env': {
          'plus': _CallbackHostFunction(
            (arguments) => (arguments[0] as int) + (arguments[1] as int),
          ),
        },
      },
    );

    expect(instance.invoke('use_plus', [4, 5]), 9);
  });

  test('upstream-wrapped host callback failures become stable traps', () async {
    final module = await engine.compile(Uint8List.fromList(_hostImportModule));
    final instance = await module.instantiate(
      imports: {
        'env': {
          'plus': _CallbackHostFunction((_) => throw StateError('host failed')),
        },
      },
    );

    expect(() => instance.invoke('use_plus', [4, 5]), throwsA(isA<WasmTrap>()));
  });

  test('guest traps use a stable runtime failure', () async {
    final module = await engine.compile(Uint8List.fromList(_trapModule));
    final instance = await module.instantiate();

    expect(() => instance.invoke('boom'), throwsA(isA<WasmTrap>()));
  });

  test('runs a genuine WASI Preview 1 command and preserves exit', () async {
    final module = await engine.compile(Uint8List.fromList(_wasiExitModule));

    expect(
      module.imports.single,
      isA<WasmImport>()
          .having((value) => value.module, 'module', 'wasi_snapshot_preview1')
          .having((value) => value.name, 'name', 'proc_exit'),
    );
    final result = await module.runWasi();
    expect(result.exitCode, 42);
  });
}

// Generated from a minimal WebAssembly module exporting `add(i32, i32)`.
const _simpleModule = <int>[
  0x00,
  0x61,
  0x73,
  0x6d,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x07,
  0x01,
  0x60,
  0x02,
  0x7f,
  0x7f,
  0x01,
  0x7f,
  0x03,
  0x02,
  0x01,
  0x00,
  0x05,
  0x03,
  0x01,
  0x00,
  0x01,
  0x07,
  0x10,
  0x02,
  0x06,
  0x6d,
  0x65,
  0x6d,
  0x6f,
  0x72,
  0x79,
  0x02,
  0x00,
  0x03,
  0x61,
  0x64,
  0x64,
  0x00,
  0x00,
  0x0a,
  0x09,
  0x01,
  0x07,
  0x00,
  0x20,
  0x00,
  0x20,
  0x01,
  0x6a,
  0x0b,
];

// Imports `env.plus` and exports `use_plus(i32, i32)`.
const _hostImportModule = <int>[
  0x00,
  0x61,
  0x73,
  0x6d,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x07,
  0x01,
  0x60,
  0x02,
  0x7f,
  0x7f,
  0x01,
  0x7f,
  0x02,
  0x0c,
  0x01,
  0x03,
  0x65,
  0x6e,
  0x76,
  0x04,
  0x70,
  0x6c,
  0x75,
  0x73,
  0x00,
  0x00,
  0x03,
  0x02,
  0x01,
  0x00,
  0x07,
  0x0c,
  0x01,
  0x08,
  0x75,
  0x73,
  0x65,
  0x5f,
  0x70,
  0x6c,
  0x75,
  0x73,
  0x00,
  0x01,
  0x0a,
  0x0a,
  0x01,
  0x08,
  0x00,
  0x20,
  0x00,
  0x20,
  0x01,
  0x10,
  0x00,
  0x0b,
];

// Exports `boom`, whose first instruction is `unreachable`.
const _trapModule = <int>[
  0x00,
  0x61,
  0x73,
  0x6d,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x04,
  0x01,
  0x60,
  0x00,
  0x00,
  0x03,
  0x02,
  0x01,
  0x00,
  0x07,
  0x08,
  0x01,
  0x04,
  0x62,
  0x6f,
  0x6f,
  0x6d,
  0x00,
  0x00,
  0x0a,
  0x05,
  0x01,
  0x03,
  0x00,
  0x00,
  0x0b,
];

// Generated from a WASI Preview 1 module that calls `proc_exit(42)`.
const _wasiExitModule = <int>[
  0x00,
  0x61,
  0x73,
  0x6d,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x02,
  0x60,
  0x01,
  0x7f,
  0x00,
  0x60,
  0x00,
  0x00,
  0x02,
  0x24,
  0x01,
  0x16,
  0x77,
  0x61,
  0x73,
  0x69,
  0x5f,
  0x73,
  0x6e,
  0x61,
  0x70,
  0x73,
  0x68,
  0x6f,
  0x74,
  0x5f,
  0x70,
  0x72,
  0x65,
  0x76,
  0x69,
  0x65,
  0x77,
  0x31,
  0x09,
  0x70,
  0x72,
  0x6f,
  0x63,
  0x5f,
  0x65,
  0x78,
  0x69,
  0x74,
  0x00,
  0x00,
  0x03,
  0x02,
  0x01,
  0x01,
  0x05,
  0x03,
  0x01,
  0x00,
  0x01,
  0x07,
  0x13,
  0x02,
  0x06,
  0x5f,
  0x73,
  0x74,
  0x61,
  0x72,
  0x74,
  0x00,
  0x01,
  0x06,
  0x6d,
  0x65,
  0x6d,
  0x6f,
  0x72,
  0x79,
  0x02,
  0x00,
  0x0a,
  0x08,
  0x01,
  0x06,
  0x00,
  0x41,
  0x2a,
  0x10,
  0x00,
  0x0b,
];

final class _CallbackHostFunction implements HostFunction {
  const _CallbackHostFunction(this._callback);

  final Object? Function(List<Object?>) _callback;

  @override
  Object? call(List<Object?> arguments) => _callback(arguments);
}
