import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../errors.dart';
import '../runtime/api.dart';
import 'models.dart';
import 'repository.dart';

typedef RegistryClock = DateTime Function();

/// Validates, describes, and versions immutable workload artifacts.
final class WorkloadRegistry {
  WorkloadRegistry({
    required WasmEngine engine,
    required WorkloadRepository repository,
    this.maximumArtifactBytes = 10 * 1024 * 1024,
    RegistryClock? clock,
  }) : _engine = engine,
       _repository = repository,
       _clock = clock ?? DateTime.now {
    if (maximumArtifactBytes < 1) {
      throw ArgumentError.value(
        maximumArtifactBytes,
        'maximumArtifactBytes',
        'must be positive',
      );
    }
  }

  final WasmEngine _engine;
  final WorkloadRepository _repository;
  final RegistryClock _clock;
  final int maximumArtifactBytes;
  final Map<String, Future<WorkloadArtifact>> _registrations = {};

  Future<WorkloadArtifact> registerArtifact(Uint8List bytes) {
    if (bytes.length > maximumArtifactBytes) {
      throw ArtifactTooLargeException(
        actualBytes: bytes.length,
        maximumBytes: maximumArtifactBytes,
      );
    }

    final ownedBytes = Uint8List.fromList(bytes);
    final artifactId = sha256.convert(ownedBytes).toString();
    return _registrations.putIfAbsent(
      artifactId,
      () => _register(artifactId, ownedBytes),
    );
  }

  Future<WorkloadRevision> createRevision({
    required String workloadName,
    required int revision,
    required String artifactId,
  }) async {
    _validateWorkloadName(workloadName);
    if (revision < 1) {
      throw ArgumentError.value(revision, 'revision', 'must be positive');
    }
    if (await _repository.findArtifact(artifactId) == null) {
      throw ArtifactNotFoundException(artifactId);
    }

    return _repository.saveRevision(
      WorkloadRevision(
        workloadName: workloadName,
        revision: revision,
        artifactId: artifactId,
        createdAt: _clock().toUtc(),
      ),
    );
  }

  Future<WorkloadRevision> activate(String workloadName, int revision) {
    _validateWorkloadName(workloadName);
    return _repository.activate(workloadName, revision);
  }

  Future<WorkloadRevision> rollback(String workloadName) {
    _validateWorkloadName(workloadName);
    return _repository.rollback(workloadName);
  }

  Future<WorkloadArtifact?> findArtifact(String artifactId) =>
      _repository.findArtifact(artifactId);

  Future<WorkloadRevision?> activeRevision(String workloadName) {
    _validateWorkloadName(workloadName);
    return _repository.activeRevision(workloadName);
  }

  Future<List<WorkloadRevision>> listRevisions(String workloadName) {
    _validateWorkloadName(workloadName);
    return _repository.listRevisions(workloadName);
  }

  Future<WorkloadArtifact> _register(String artifactId, Uint8List bytes) async {
    try {
      final existing = await _repository.findArtifact(artifactId);
      if (existing != null) {
        return existing;
      }
      if (!_engine.validate(bytes)) {
        throw const WasmValidationException(
          'The WebAssembly module failed validation.',
        );
      }

      final module = await _engine.compile(bytes);
      return _repository.saveArtifact(
        WorkloadArtifact(
          id: artifactId,
          bytes: bytes,
          createdAt: _clock().toUtc(),
          compatibility: _engine.compatibility,
          imports: module.imports,
          exports: module.exports,
        ),
      );
    } finally {
      _registrations.remove(artifactId);
    }
  }
}

final _workloadNamePattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$');

void _validateWorkloadName(String name) {
  if (!_workloadNamePattern.hasMatch(name)) {
    throw InvalidWorkloadNameException(name);
  }
}
