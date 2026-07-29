import '../errors.dart';
import 'models.dart';

/// Replaceable persistence boundary for artifacts and workload revisions.
abstract interface class WorkloadRepository {
  Future<WorkloadArtifact?> findArtifact(String artifactId);

  Future<WorkloadArtifact> saveArtifact(WorkloadArtifact artifact);

  Future<WorkloadRevision?> findRevision(String workloadName, int revision);

  Future<List<WorkloadRevision>> listRevisions(String workloadName);

  Future<WorkloadRevision> saveRevision(WorkloadRevision revision);

  Future<WorkloadRevision?> activeRevision(String workloadName);

  Future<WorkloadRevision> activate(String workloadName, int revision);

  Future<WorkloadRevision> rollback(String workloadName);
}

/// Deterministic in-memory repository used by the proof of concept.
final class InMemoryWorkloadRepository implements WorkloadRepository {
  final Map<String, WorkloadArtifact> _artifacts = {};
  final Map<String, Map<int, WorkloadRevision>> _revisions = {};
  final Map<String, int> _activeRevisions = {};
  final Map<String, List<int>> _activationHistory = {};

  @override
  Future<WorkloadArtifact?> findArtifact(String artifactId) async =>
      _artifacts[artifactId];

  @override
  Future<WorkloadArtifact> saveArtifact(WorkloadArtifact artifact) async {
    final existing = _artifacts[artifact.id];
    if (existing != null) {
      if (!_sameBytes(existing.bytes, artifact.bytes)) {
        throw ArtifactConflictException(artifact.id);
      }
      return existing;
    }
    _artifacts[artifact.id] = artifact;
    return artifact;
  }

  @override
  Future<WorkloadRevision?> findRevision(
    String workloadName,
    int revision,
  ) async => _revisions[workloadName]?[revision];

  @override
  Future<List<WorkloadRevision>> listRevisions(String workloadName) async {
    final revisions = _revisions[workloadName]?.values.toList() ?? [];
    revisions.sort((left, right) => left.revision.compareTo(right.revision));
    return List.unmodifiable(revisions);
  }

  @override
  Future<WorkloadRevision> saveRevision(WorkloadRevision revision) async {
    if (!_artifacts.containsKey(revision.artifactId)) {
      throw ArtifactNotFoundException(revision.artifactId);
    }

    final revisions = _revisions.putIfAbsent(revision.workloadName, () => {});
    final existing = revisions[revision.revision];
    if (existing != null) {
      if (existing.artifactId != revision.artifactId) {
        throw RevisionConflictException(
          revision.workloadName,
          revision.revision,
        );
      }
      return existing;
    }
    revisions[revision.revision] = revision;
    return revision;
  }

  @override
  Future<WorkloadRevision?> activeRevision(String workloadName) async {
    final revision = _activeRevisions[workloadName];
    return revision == null ? null : _revisions[workloadName]?[revision];
  }

  @override
  Future<WorkloadRevision> activate(String workloadName, int revision) async {
    final target = _revisions[workloadName]?[revision];
    if (target == null) {
      throw RevisionNotFoundException(workloadName, revision);
    }

    if (_activeRevisions[workloadName] != revision) {
      _activeRevisions[workloadName] = revision;
      _activationHistory.putIfAbsent(workloadName, () => []).add(revision);
    }
    return target;
  }

  @override
  Future<WorkloadRevision> rollback(String workloadName) async {
    final history = _activationHistory[workloadName];
    if (history == null || history.length < 2) {
      throw NoRollbackTargetException(workloadName);
    }

    history.removeLast();
    final previous = history.last;
    _activeRevisions[workloadName] = previous;
    return _revisions[workloadName]![previous]!;
  }
}

bool _sameBytes(List<int> left, List<int> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
