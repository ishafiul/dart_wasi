import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:wasi_runtime/wasi_runtime.dart';

void main() {
  group('CompiledModuleCache', () {
    test(
      'single-flights concurrent compilation for the same engine key',
      () async {
        final gate = Completer<void>();
        final engine = _FakeEngine(compilationGate: gate.future);
        final cache = CompiledModuleCache(engine: engine);
        final artifact = _artifact('one', [1]);

        final first = cache.getOrCompile(artifact);
        final second = cache.getOrCompile(artifact);
        await Future<void>.delayed(Duration.zero);

        expect(engine.compilationCount, 1);
        gate.complete();
        final modules = await Future.wait([first, second]);
        expect(modules[1], same(modules[0]));
        expect(cache.entryCount, 1);
      },
    );

    test(
      'separates entries when the resolved engine version changes',
      () async {
        final engine = _FakeEngine();
        final cache = CompiledModuleCache(engine: engine);
        final artifact = _artifact('one', [1]);

        await cache.getOrCompile(artifact);
        engine.version = '2.0.0';
        await cache.getOrCompile(artifact);

        expect(engine.compilationCount, 2);
        expect(cache.entryCount, 2);
      },
    );

    test(
      'evicts the least recently used entry to stay within the byte budget',
      () async {
        var now = DateTime.utc(2026, 8, 1);
        final engine = _FakeEngine();
        final cache = CompiledModuleCache(
          engine: engine,
          maximumEntries: 2,
          maximumCachedBytes: 3,
          clock: () => now,
        );

        await cache.getOrCompile(_artifact('one', [1, 1]));
        now = now.add(const Duration(seconds: 1));
        await cache.getOrCompile(_artifact('two', [2, 2]));
        await cache.getOrCompile(_artifact('one', [1, 1]));

        expect(engine.compilationCount, 3);
        expect(cache.entryCount, 1);
        expect(cache.cachedBytes, 2);
      },
    );

    test(
      'evicts entries that have remained idle for the requested duration',
      () async {
        var now = DateTime.utc(2026, 8, 1);
        final cache = CompiledModuleCache(
          engine: _FakeEngine(),
          clock: () => now,
        );

        await cache.getOrCompile(_artifact('one', [1]));
        now = now.add(const Duration(minutes: 5));
        cache.evictIdle(const Duration(minutes: 5));

        expect(cache.entryCount, 0);
        expect(cache.cachedBytes, 0);
      },
    );

    test('does not retain an artifact larger than the byte budget', () async {
      final engine = _FakeEngine();
      final cache = CompiledModuleCache(engine: engine, maximumCachedBytes: 1);
      final artifact = _artifact('large', [1, 2]);

      await cache.getOrCompile(artifact);
      await cache.getOrCompile(artifact);

      expect(engine.compilationCount, 2);
      expect(cache.entryCount, 0);
    });
  });

  group('WorkloadExecutor', () {
    test(
      'drains the old revision while new requests use the activated revision',
      () async {
        final oldGate = Completer<void>();
        final oldStarted = Completer<void>();
        final engine = _FakeEngine(
          onRun: (identity, _) async {
            if (identity == 1) {
              oldStarted.complete();
              await oldGate.future;
            }
            return _executionResult();
          },
        );
        final registry = WorkloadRegistry(
          engine: engine,
          repository: InMemoryWorkloadRepository(),
        );
        final firstArtifact = await registry.registerArtifact(
          Uint8List.fromList([1]),
        );
        final secondArtifact = await registry.registerArtifact(
          Uint8List.fromList([2]),
        );
        final firstRevision = await registry.createRevision(
          workloadName: 'worker',
          revision: 1,
          artifactId: firstArtifact.id,
        );
        await registry.createRevision(
          workloadName: 'worker',
          revision: 2,
          artifactId: secondArtifact.id,
        );
        await registry.activate('worker', 1);

        final executor = WorkloadExecutor(
          registry: registry,
          cache: CompiledModuleCache(engine: engine),
        );
        final oldRequest = executor.execute('worker', WasiRequest());
        await oldStarted.future;

        await registry.activate('worker', 2);
        final draining = executor.drain(firstRevision);
        var drained = false;
        draining.then((_) => drained = true);

        final newRequest = await executor.execute('worker', WasiRequest());
        expect(newRequest.revision.revision, 2);
        expect(newRequest.request.status, WasiRequestStatus.completed);
        expect(drained, isFalse);

        oldGate.complete();
        final oldResult = await oldRequest;
        await draining;
        expect(oldResult.revision.revision, 1);
        expect(oldResult.request.status, WasiRequestStatus.completed);
        expect(drained, isTrue);
      },
    );

    test('rejects execution when a workload has no active revision', () async {
      final executor = WorkloadExecutor(
        registry: WorkloadRegistry(
          engine: _FakeEngine(),
          repository: InMemoryWorkloadRepository(),
        ),
        cache: CompiledModuleCache(engine: _FakeEngine()),
      );

      await expectLater(
        executor.execute('worker', WasiRequest()),
        throwsA(isA<NoActiveRevisionException>()),
      );
    });
  });
}

WorkloadArtifact _artifact(String id, List<int> bytes) => WorkloadArtifact(
  id: id,
  bytes: Uint8List.fromList(bytes),
  createdAt: DateTime.utc(2026, 8, 1),
  compatibility: const EngineCompatibility(
    engine: 'fake',
    version: '1.0.0',
    wasiVersion: 'preview1',
  ),
  imports: const [],
  exports: const [],
);

final class _FakeEngine implements WasmEngine {
  _FakeEngine({this.compilationGate, this.onRun});

  final Future<void>? compilationGate;
  final Future<WasiExecutionResult> Function(
    int identity,
    WasiExecutionOptions options,
  )?
  onRun;
  int compilationCount = 0;
  String version = '1.0.0';

  @override
  EngineCompatibility get compatibility => EngineCompatibility(
    engine: 'fake',
    version: version,
    wasiVersion: 'preview1',
  );

  @override
  bool validate(Uint8List bytes) => true;

  @override
  Future<CompiledModule> compile(Uint8List bytes) async {
    compilationCount++;
    await compilationGate;
    return _FakeModule(bytes.first, onRun);
  }
}

final class _FakeModule implements CompiledModule {
  const _FakeModule(this._identity, this._onRun);

  final int _identity;
  final Future<WasiExecutionResult> Function(int, WasiExecutionOptions)? _onRun;

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
    final onRun = _onRun;
    return onRun == null
        ? Future.value(_executionResult())
        : onRun(_identity, options);
  }
}

WasiExecutionResult _executionResult() => WasiExecutionResult(
  exitCode: 0,
  stdout: Uint8List(0),
  stderr: Uint8List(0),
);
