import 'dart:typed_data';

import '../runtime/api.dart';
import '../execution/capability_policy.dart';

/// Immutable, content-addressed WebAssembly artifact and derived metadata.
final class WorkloadArtifact {
  WorkloadArtifact({
    required this.id,
    required Uint8List bytes,
    required this.createdAt,
    required this.compatibility,
    required List<WasmImport> imports,
    required List<WasmExport> exports,
  }) : _bytes = Uint8List.fromList(bytes),
       imports = List.unmodifiable(imports),
       exports = List.unmodifiable(exports);

  final String id;
  final Uint8List _bytes;
  final DateTime createdAt;
  final EngineCompatibility compatibility;
  final List<WasmImport> imports;
  final List<WasmExport> exports;

  int get size => _bytes.length;

  /// Returns a copy so stored artifact content cannot be mutated by callers.
  Uint8List get bytes => Uint8List.fromList(_bytes);
}

/// An immutable version of a logical workload.
final class WorkloadRevision {
  const WorkloadRevision({
    required this.workloadName,
    required this.revision,
    required this.artifactId,
    required this.createdAt,
    this.policy = const WasiCapabilityPolicy(),
  });

  final String workloadName;
  final int revision;
  final String artifactId;
  final DateTime createdAt;
  final WasiCapabilityPolicy policy;
}
