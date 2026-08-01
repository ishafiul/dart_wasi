import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:wasi_runtime/wasi_runtime.dart';

void main() {
  group('WasiRequestExecutor', () {
    test(
      'uses independent request options for concurrent executions',
      () async {
        final module = _RecordingModule();
        final executor = WasiRequestExecutor(module);

        final results = await Future.wait([
          executor.execute(
            WasiRequest(
              arguments: const ['first'],
              environment: const {'REQUEST': 'one'},
              stdin: const [1],
            ),
          ),
          executor.execute(
            WasiRequest(
              arguments: const ['second'],
              environment: const {'REQUEST': 'two'},
              stdin: const [2],
            ),
          ),
        ]);

        expect(
          results.map((result) => result.status),
          everyElement(WasiRequestStatus.completed),
        );
        expect(module.options, hasLength(2));
        expect(
          module.options.map((options) => options.arguments.single),
          containsAll(['first', 'second']),
        );
        expect(
          module.options.map((options) => options.environment['REQUEST']),
          containsAll(['one', 'two']),
        );
        expect(
          module.options.map((options) => options.stdin.single),
          containsAll([1, 2]),
        );
        expect(
          module.options.every((options) => options.preopens.isEmpty),
          isTrue,
        );
        expect(
          module.options.every((options) => options.files.isEmpty),
          isTrue,
        );
      },
    );

    test('preserves a guest exit separately from a guest trap', () async {
      final exiting = WasiRequestExecutor(_ResultModule(exitCode: 7));
      final trapping = WasiRequestExecutor(_TrapModule());

      final exited = await exiting.execute(WasiRequest());
      final trapped = await trapping.execute(WasiRequest());

      expect(exited.status, WasiRequestStatus.exited);
      expect(exited.execution?.exitCode, 7);
      expect(exited.failure, isNull);
      expect(trapped.status, WasiRequestStatus.trapped);
      expect(trapped.execution, isNull);
      expect(trapped.failure, isA<WasmTrap>());
    });

    test('returns cancellation before starting the engine', () async {
      final module = _RecordingModule();
      final cancellation = WasiRequestCancellation()..cancel();

      final result = await WasiRequestExecutor(
        module,
      ).execute(WasiRequest(), cancellation: cancellation);

      expect(result.status, WasiRequestStatus.cancelled);
      expect(module.options, isEmpty);
    });

    test(
      'returns timeout at the host boundary for a pending engine call',
      () async {
        final result = await WasiRequestExecutor(
          _PendingModule(),
        ).execute(WasiRequest(), timeout: Duration.zero);

        expect(result.status, WasiRequestStatus.timedOut);
        expect(result.execution, isNull);
        expect(result.failure, isNull);
      },
    );
  });
}

abstract base class _FakeModule implements CompiledModule {
  @override
  List<WasmExport> get exports => const [];

  @override
  List<WasmImport> get imports => const [];

  @override
  Future<WasmInstance> instantiate({
    Map<String, Map<String, HostFunction>> imports = const {},
  }) => throw UnimplementedError();
}

final class _RecordingModule extends _FakeModule {
  final List<WasiExecutionOptions> options = [];

  @override
  Future<WasiExecutionResult> runWasi([
    WasiExecutionOptions requestOptions = const WasiExecutionOptions(),
  ]) async {
    options.add(requestOptions);
    await Future<void>.delayed(Duration.zero);
    return _executionResult();
  }
}

final class _ResultModule extends _FakeModule {
  _ResultModule({required this.exitCode});

  final int exitCode;

  @override
  Future<WasiExecutionResult> runWasi([
    WasiExecutionOptions options = const WasiExecutionOptions(),
  ]) async => _executionResult(exitCode: exitCode);
}

final class _TrapModule extends _FakeModule {
  @override
  Future<WasiExecutionResult> runWasi([
    WasiExecutionOptions options = const WasiExecutionOptions(),
  ]) => Future<WasiExecutionResult>.error(const WasmTrap('guest trapped'));
}

final class _PendingModule extends _FakeModule {
  @override
  Future<WasiExecutionResult> runWasi([
    WasiExecutionOptions options = const WasiExecutionOptions(),
  ]) => Completer<WasiExecutionResult>().future;
}

WasiExecutionResult _executionResult({int exitCode = 0}) => WasiExecutionResult(
  exitCode: exitCode,
  stdout: Uint8List(0),
  stderr: Uint8List(0),
);
