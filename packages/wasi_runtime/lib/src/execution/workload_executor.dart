import 'dart:async';

import '../artifacts/models.dart';
import '../artifacts/registry.dart';
import '../errors.dart';
import 'compiled_module_cache.dart';
import 'request_executor.dart';

/// A completed request together with the immutable revision that served it.
final class WorkloadExecutionResult {
  const WorkloadExecutionResult({
    required this.revision,
    required this.request,
  });

  final WorkloadRevision revision;
  final WasiRequestResult request;
}

/// Executes an active workload with request-scoped WASI options.
///
/// The interface keeps host transports, such as HTTP, independent from the
/// registry and compilation-cache implementation.
abstract interface class WasiWorkloadExecutor {
  Future<WorkloadExecutionResult> execute(
    String workloadName,
    WasiRequest request, {
    Duration? timeout,
    WasiRequestCancellation? cancellation,
  });
}

/// Executes active workload revisions through a shared compilation cache.
///
/// The active revision is read before compilation begins. Activating or
/// rolling back later requests therefore cannot interrupt an in-flight request
/// or change the revision it is already draining.
final class WorkloadExecutor implements WasiWorkloadExecutor {
  WorkloadExecutor({
    required WorkloadRegistry registry,
    required CompiledModuleCache cache,
  }) : _registry = registry,
       _cache = cache;

  final WorkloadRegistry _registry;
  final CompiledModuleCache _cache;
  final Map<_RevisionKey, _DrainState> _draining = {};
  final Map<_RevisionKey, _RevisionLimiter> _limiters = {};

  @override
  Future<WorkloadExecutionResult> execute(
    String workloadName,
    WasiRequest request, {
    Duration? timeout,
    WasiRequestCancellation? cancellation,
  }) async {
    final revision = await _registry.activeRevision(workloadName);
    if (revision == null) {
      throw NoActiveRevisionException(workloadName);
    }
    final artifact = await _registry.findArtifact(revision.artifactId);
    if (artifact == null) {
      throw ArtifactNotFoundException(revision.artifactId);
    }

    final policyRequest = revision.policy.applyTo(request);
    if (revision.policy.inputBytesFor(policyRequest) >
        revision.policy.maximumInputBytes) {
      return WorkloadExecutionResult(
        revision: revision,
        request: WasiRequestResult.rejected('Request input exceeds policy.'),
      );
    }

    final key = _RevisionKey(revision.workloadName, revision.revision);
    final limiter = _limiters.putIfAbsent(
      key,
      () => _RevisionLimiter(revision.policy.maximumConcurrentRequests),
    );
    if (!limiter.tryAcquire()) {
      return WorkloadExecutionResult(
        revision: revision,
        request: WasiRequestResult.rejected('Workload capacity is exhausted.'),
      );
    }
    final drainState = _draining.putIfAbsent(key, _DrainState.new)..start();
    try {
      final module = await _cache.getOrCompile(artifact);
      final requestResult = await WasiRequestExecutor(module).execute(
        policyRequest,
        timeout: _effectiveTimeout(timeout, revision.policy.maximumWallTime),
        cancellation: cancellation,
        maximumOutputBytes: revision.policy.maximumOutputBytes,
      );
      _releaseWhenSafe(limiter, drainState, key, requestResult);
      return WorkloadExecutionResult(
        revision: revision,
        request: requestResult,
      );
    } on Object {
      _finish(limiter, drainState, key);
      rethrow;
    }
  }

  void _releaseWhenSafe(
    _RevisionLimiter limiter,
    _DrainState drainState,
    _RevisionKey key,
    WasiRequestResult result,
  ) {
    if (result.status == WasiRequestStatus.timedOut ||
        result.status == WasiRequestStatus.cancelled) {
      result.whenExecutionSettled.whenComplete(
        () => _finish(limiter, drainState, key),
      );
      return;
    }
    _finish(limiter, drainState, key);
  }

  void _finish(
    _RevisionLimiter limiter,
    _DrainState drainState,
    _RevisionKey key,
  ) {
    limiter.release();
    if (drainState.finish()) {
      _draining.remove(key);
      _limiters.remove(key);
    }
  }

  /// Completes when executions already using [revision] have finished.
  ///
  /// Activate a different revision before calling this method to ensure no new
  /// requests begin on the revision being drained.
  Future<void> drain(WorkloadRevision revision) {
    final key = _RevisionKey(revision.workloadName, revision.revision);
    return _draining[key]?.whenDrained ?? Future.value();
  }
}

Duration _effectiveTimeout(Duration? requested, Duration maximum) {
  if (requested == null || requested > maximum) {
    return maximum;
  }
  return requested;
}

final class _RevisionKey {
  const _RevisionKey(this.workloadName, this.revision);

  final String workloadName;
  final int revision;

  @override
  bool operator ==(Object other) =>
      other is _RevisionKey &&
      workloadName == other.workloadName &&
      revision == other.revision;

  @override
  int get hashCode => Object.hash(workloadName, revision);
}

final class _DrainState {
  final _drained = Completer<void>();
  int _active = 0;

  Future<void> get whenDrained => _drained.future;

  void start() {
    _active++;
  }

  bool finish() {
    _active--;
    if (_active == 0) {
      _drained.complete();
      return true;
    }
    return false;
  }
}

final class _RevisionLimiter {
  _RevisionLimiter(this._maximum);

  final int _maximum;
  int _active = 0;

  bool tryAcquire() {
    if (_active >= _maximum) {
      return false;
    }
    _active++;
    return true;
  }

  void release() {
    _active--;
  }
}
