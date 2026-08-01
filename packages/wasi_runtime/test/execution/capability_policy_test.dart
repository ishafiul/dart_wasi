import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:wasi_runtime/wasi_runtime.dart';

void main() {
  group('WasiCapabilityPolicy', () {
    test('is immutable once a revision is created', () async {
      final registry = _registry(_RecordingEngine());
      final artifact = await registry.registerArtifact(Uint8List.fromList([1]));
      const original = WasiCapabilityPolicy(maximumInputBytes: 4);
      await registry.createRevision(
        workloadName: 'worker',
        revision: 1,
        artifactId: artifact.id,
        policy: original,
      );

      await expectLater(
        registry.createRevision(
          workloadName: 'worker',
          revision: 1,
          artifactId: artifact.id,
          policy: const WasiCapabilityPolicy(maximumInputBytes: 5),
        ),
        throwsA(isA<RevisionConflictException>()),
      );
    });

    test(
      'denies request environment and forwards output limit to the engine',
      () async {
        final engine = _RecordingEngine();
        final executor = await _executor(
          engine,
          const WasiCapabilityPolicy(maximumOutputBytes: 7),
        );

        final result = await executor.execute(
          'worker',
          WasiRequest(environment: const {'SECRET': 'not inherited'}),
        );

        expect(result.request.status, WasiRequestStatus.completed);
        expect(engine.options.single.environment, isEmpty);
        expect(engine.options.single.preopens, isEmpty);
        expect(engine.options.single.files, isEmpty);
        expect(engine.options.single.maximumOutputBytes, 7);
      },
    );

    test(
      'rejects oversized input before compiling or running a module',
      () async {
        final engine = _RecordingEngine();
        final executor = await _executor(
          engine,
          const WasiCapabilityPolicy(maximumInputBytes: 2),
        );

        final result = await executor.execute(
          'worker',
          WasiRequest(stdin: const [1, 2, 3]),
        );

        expect(result.request.status, WasiRequestStatus.rejected);
        expect(result.request.rejectionReason, contains('input'));
        expect(engine.runCount, 0);
      },
    );

    test(
      'quarantines timed-out capacity until the engine invocation settles',
      () async {
        final gate = Completer<void>();
        final engine = _RecordingEngine(
          onRun: (_) async {
            await gate.future;
            return _success();
          },
        );
        final executor = await _executor(
          engine,
          const WasiCapabilityPolicy(maximumWallTime: Duration.zero),
        );

        final timedOut = await executor.execute('worker', WasiRequest());
        final rejected = await executor.execute('worker', WasiRequest());

        expect(timedOut.request.status, WasiRequestStatus.timedOut);
        expect(rejected.request.status, WasiRequestStatus.rejected);
        expect(rejected.request.rejectionReason, contains('capacity'));

        gate.complete();
        await timedOut.request.whenExecutionSettled;
        await Future<void>.delayed(Duration.zero);

        await executor.execute('worker', WasiRequest());
        expect(engine.runCount, 2);
      },
    );
  });
}

Future<WorkloadExecutor> _executor(
  _RecordingEngine engine,
  WasiCapabilityPolicy policy,
) async {
  final registry = _registry(engine);
  final artifact = await registry.registerArtifact(Uint8List.fromList([1]));
  await registry.createRevision(
    workloadName: 'worker',
    revision: 1,
    artifactId: artifact.id,
    policy: policy,
  );
  await registry.activate('worker', 1);
  return WorkloadExecutor(
    registry: registry,
    cache: CompiledModuleCache(engine: engine),
  );
}

WorkloadRegistry _registry(_RecordingEngine engine) =>
    WorkloadRegistry(engine: engine, repository: InMemoryWorkloadRepository());

WasiExecutionResult _success() => WasiExecutionResult(
  exitCode: 0,
  stdout: Uint8List(0),
  stderr: Uint8List(0),
);

final class _RecordingEngine implements WasmEngine {
  _RecordingEngine({this.onRun});

  final Future<WasiExecutionResult> Function(WasiExecutionOptions)? onRun;
  final List<WasiExecutionOptions> options = [];
  int runCount = 0;

  @override
  EngineCompatibility get compatibility => const EngineCompatibility(
    engine: 'fake',
    version: '1',
    wasiVersion: 'preview1',
  );

  @override
  Future<CompiledModule> compile(Uint8List bytes) async =>
      _RecordingModule(this);

  @override
  bool validate(Uint8List bytes) => true;
}

final class _RecordingModule implements CompiledModule {
  const _RecordingModule(this._engine);

  final _RecordingEngine _engine;

  @override
  List<WasmExport> get exports => const [];

  @override
  List<WasmImport> get imports => const [];

  @override
  Future<WasmInstance> instantiate({
    Map<String, Map<String, HostFunction>> imports = const {},
  }) => throw UnimplementedError();

  @override
  Future<WasiExecutionResult> runWasi([
    WasiExecutionOptions options = const WasiExecutionOptions(),
  ]) {
    _engine.runCount++;
    _engine.options.add(options);
    return _engine.onRun?.call(options) ?? Future.value(_success());
  }
}
