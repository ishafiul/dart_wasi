import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:wasi_runtime/wasi_runtime.dart';

void main() {
  group('artifact registration', () {
    test(
      'identical bytes are idempotent and metadata comes from engine',
      () async {
        final registry = _registry(engine: const WasdEngine());
        final bytes = Uint8List.fromList(_simpleModule);

        final first = await registry.registerArtifact(bytes);
        final second = await registry.registerArtifact(bytes);

        expect(second, same(first));
        expect(first.id, hasLength(64));
        expect(first.size, _simpleModule.length);
        expect(first.compatibility.engine, 'wasd');
        expect(first.compatibility.version, '0.3.0');
        expect(first.imports, isEmpty);
        expect(
          first.exports.where((value) => value.name == 'add').single.kind,
          WasmExternalKind.function,
        );
      },
    );

    test('different valid bytes receive different artifact IDs', () async {
      final registry = _registry(engine: const WasdEngine());

      final first = await registry.registerArtifact(
        Uint8List.fromList(_simpleModule),
      );
      final second = await registry.registerArtifact(
        Uint8List.fromList(_trapModule),
      );

      expect(first.id, isNot(second.id));
    });

    test('stored bytes cannot be changed by callers', () async {
      final registry = _registry(engine: const WasdEngine());
      final input = Uint8List.fromList(_simpleModule);
      final artifact = await registry.registerArtifact(input);

      input[0] = 99;
      final returnedBytes = artifact.bytes..[1] = 99;

      expect(artifact.bytes, orderedEquals(_simpleModule));
      expect(returnedBytes, isNot(orderedEquals(_simpleModule)));
    });

    test('invalid modules are rejected and never stored', () async {
      final repository = InMemoryWorkloadRepository();
      final registry = WorkloadRegistry(
        engine: const WasdEngine(),
        repository: repository,
      );

      await expectLater(
        registry.registerArtifact(Uint8List.fromList([0, 1, 2])),
        throwsA(isA<WasmValidationException>()),
      );
      expect(await registry.findArtifact(_unknownArtifactId), isNull);
    });

    test('oversized modules are rejected before engine work', () {
      final engine = _RecordingEngine();
      final registry = WorkloadRegistry(
        engine: engine,
        repository: InMemoryWorkloadRepository(),
        maximumArtifactBytes: 2,
      );

      expect(
        () => registry.registerArtifact(Uint8List.fromList([0, 1, 2])),
        throwsA(isA<ArtifactTooLargeException>()),
      );
      expect(engine.validationCount, 0);
      expect(engine.compilationCount, 0);
    });

    test('concurrent identical registration compiles once', () async {
      final gate = Completer<void>();
      final engine = _RecordingEngine(compilationGate: gate.future);
      final registry = _registry(engine: engine);
      final bytes = Uint8List.fromList(_simpleModule);

      final first = registry.registerArtifact(bytes);
      final second = registry.registerArtifact(bytes);
      await Future<void>.delayed(Duration.zero);

      expect(engine.compilationCount, 1);
      gate.complete();
      final artifacts = await Future.wait([first, second]);
      expect(artifacts[1], same(artifacts[0]));
    });
  });

  group('workload revisions', () {
    test('creates, activates, and rolls back immutable revisions', () async {
      final registry = _registry(engine: const WasdEngine());
      final firstArtifact = await registry.registerArtifact(
        Uint8List.fromList(_simpleModule),
      );
      final secondArtifact = await registry.registerArtifact(
        Uint8List.fromList(_trapModule),
      );

      final first = await registry.createRevision(
        workloadName: 'calculator',
        revision: 1,
        artifactId: firstArtifact.id,
      );
      final second = await registry.createRevision(
        workloadName: 'calculator',
        revision: 2,
        artifactId: secondArtifact.id,
      );

      expect(await registry.activate('calculator', 1), same(first));
      expect(await registry.activate('calculator', 2), same(second));
      expect((await registry.activeRevision('calculator'))?.revision, 2);

      final rolledBack = await registry.rollback('calculator');
      expect(rolledBack, same(first));
      expect((await registry.activeRevision('calculator'))?.revision, 1);
      expect(
        (await registry.listRevisions(
          'calculator',
        )).map((value) => value.revision),
        [1, 2],
      );
    });

    test('same revision and artifact is idempotent', () async {
      final registry = _registry(engine: const WasdEngine());
      final artifact = await registry.registerArtifact(
        Uint8List.fromList(_simpleModule),
      );

      final first = await registry.createRevision(
        workloadName: 'calculator',
        revision: 1,
        artifactId: artifact.id,
      );
      final second = await registry.createRevision(
        workloadName: 'calculator',
        revision: 1,
        artifactId: artifact.id,
      );

      expect(second, same(first));
    });

    test('same revision with different content is rejected', () async {
      final registry = _registry(engine: const WasdEngine());
      final first = await registry.registerArtifact(
        Uint8List.fromList(_simpleModule),
      );
      final second = await registry.registerArtifact(
        Uint8List.fromList(_trapModule),
      );
      await registry.createRevision(
        workloadName: 'calculator',
        revision: 1,
        artifactId: first.id,
      );

      await expectLater(
        registry.createRevision(
          workloadName: 'calculator',
          revision: 1,
          artifactId: second.id,
        ),
        throwsA(isA<RevisionConflictException>()),
      );
    });

    test('missing artifacts and invalid workload names are rejected', () async {
      final registry = _registry(engine: const WasdEngine());

      await expectLater(
        registry.createRevision(
          workloadName: 'calculator',
          revision: 1,
          artifactId: _unknownArtifactId,
        ),
        throwsA(isA<ArtifactNotFoundException>()),
      );
      expect(
        () => registry.activeRevision('../calculator'),
        throwsA(isA<InvalidWorkloadNameException>()),
      );
    });

    test('rollback requires an earlier activation', () async {
      final registry = _registry(engine: const WasdEngine());
      final artifact = await registry.registerArtifact(
        Uint8List.fromList(_simpleModule),
      );
      await registry.createRevision(
        workloadName: 'calculator',
        revision: 1,
        artifactId: artifact.id,
      );
      await registry.activate('calculator', 1);

      await expectLater(
        registry.rollback('calculator'),
        throwsA(isA<NoRollbackTargetException>()),
      );
    });
  });
}

WorkloadRegistry _registry({required WasmEngine engine}) => WorkloadRegistry(
  engine: engine,
  repository: InMemoryWorkloadRepository(),
  clock: () => DateTime.utc(2026, 7, 29),
);

final class _RecordingEngine implements WasmEngine {
  _RecordingEngine({this.compilationGate});

  final Future<void>? compilationGate;
  int validationCount = 0;
  int compilationCount = 0;

  @override
  EngineCompatibility get compatibility => const EngineCompatibility(
    engine: 'fake',
    version: '1.0.0',
    wasiVersion: 'preview1',
  );

  @override
  bool validate(Uint8List bytes) {
    validationCount++;
    return true;
  }

  @override
  Future<CompiledModule> compile(Uint8List bytes) async {
    compilationCount++;
    await compilationGate;
    return _MetadataModule();
  }
}

final class _MetadataModule implements CompiledModule {
  @override
  List<WasmExport> get exports => const [
    WasmExport(name: '_start', kind: WasmExternalKind.function),
  ];

  @override
  List<WasmImport> get imports => const [
    WasmImport(
      module: 'wasi_snapshot_preview1',
      name: 'proc_exit',
      kind: WasmExternalKind.function,
    ),
  ];

  @override
  Future<WasmInstance> instantiate({
    Map<String, Map<String, HostFunction>> imports = const {},
  }) => throw UnimplementedError();

  @override
  Future<WasiExecutionResult> runWasi([
    WasiExecutionOptions options = const WasiExecutionOptions(),
  ]) => throw UnimplementedError();
}

const _unknownArtifactId =
    '0000000000000000000000000000000000000000000000000000000000000000';

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
