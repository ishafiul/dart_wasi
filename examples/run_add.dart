import 'dart:typed_data';

import 'package:wasi_runtime/wasi_runtime.dart';

Future<void> main() async {
  const engine = WasdEngine();
  final registry = WorkloadRegistry(
    engine: engine,
    repository: InMemoryWorkloadRepository(),
  );

  final artifact = await registry.registerArtifact(
    Uint8List.fromList(_addModule),
  );
  final revision = await registry.createRevision(
    workloadName: 'calculator',
    revision: 1,
    artifactId: artifact.id,
  );
  await registry.activate(revision.workloadName, revision.revision);

  print('Artifact: ${artifact.id}');
  print(
    'Engine: ${artifact.compatibility.engine} '
    '${artifact.compatibility.version}',
  );
  print('Exports: ${artifact.exports.map((value) => value.name).join(', ')}');
  print('Active: ${revision.workloadName}@${revision.revision}');

  final module = await engine.compile(artifact.bytes);
  final instance = await module.instantiate();
  print('20 + 22 = ${instance.invoke('add', [20, 22])}');
}

const _addModule = <int>[
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
  0x07,
  0x07,
  0x01,
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
