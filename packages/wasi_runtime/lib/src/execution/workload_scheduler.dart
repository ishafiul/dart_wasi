import 'dart:async';
import 'dart:collection';

import '../artifacts/models.dart';

/// A clock controlled by the host, rather than wall time hidden in a timer.
///
/// Calling [tick] lets production hosts drive eviction from their event loop
/// and lets tests advance lifecycle state without waiting.
abstract interface class WorkloadSchedulerClock {
  DateTime get now;
}

/// The lifecycle of capacity allocated to one workload revision.
enum WorkloadCapacityState { inactive, compiling, warm, busy, draining, failed }

/// Settings that bound a workload's warm capacity and waiting work.
final class WorkloadCapacityPolicy {
  const WorkloadCapacityPolicy({
    this.desiredConcurrency = 1,
    this.maximumConcurrency = 1,
    this.maximumQueuedRequests = 0,
    this.idleTimeout = const Duration(minutes: 1),
  }) : assert(desiredConcurrency > 0),
       assert(maximumConcurrency >= desiredConcurrency),
       assert(maximumQueuedRequests >= 0);

  final int desiredConcurrency;
  final int maximumConcurrency;
  final int maximumQueuedRequests;
  final Duration idleTimeout;

  @override
  bool operator ==(Object other) =>
      other is WorkloadCapacityPolicy &&
      desiredConcurrency == other.desiredConcurrency &&
      maximumConcurrency == other.maximumConcurrency &&
      maximumQueuedRequests == other.maximumQueuedRequests &&
      idleTimeout == other.idleTimeout;

  @override
  int get hashCode => Object.hash(
    desiredConcurrency,
    maximumConcurrency,
    maximumQueuedRequests,
    idleTimeout,
  );
}

/// A stable view of a revision's scheduler state.
final class WorkloadCapacitySnapshot {
  const WorkloadCapacitySnapshot({
    required this.state,
    required this.warmInstances,
    required this.busyInstances,
    required this.queuedRequests,
  });

  final WorkloadCapacityState state;
  final int warmInstances;
  final int busyInstances;
  final int queuedRequests;
}

/// Reports that a request cannot be admitted to a workload's bounded queue.
final class WorkloadQueueFullException implements Exception {
  const WorkloadQueueFullException(this.workloadName);

  final String workloadName;

  @override
  String toString() => 'Workload queue is full: $workloadName';
}

/// Schedules revision-scoped work onto bounded, scale-to-zero capacity.
///
/// [activate] is deliberately separate from request execution. It can warm a
/// compiled module, open a process, or reserve any host resource. Individual
/// requests still supply [operation], so callers retain request-scoped WASI
/// inputs and do not accidentally share mutable execution state.
final class WorkloadCapacityScheduler {
  WorkloadCapacityScheduler({
    required WorkloadSchedulerClock clock,
    required Future<void> Function(WorkloadRevision revision) activate,
  }) : _clock = clock,
       _activate = activate;

  final WorkloadSchedulerClock _clock;
  final Future<void> Function(WorkloadRevision revision) _activate;
  final Map<_RevisionKey, _Capacity> _capacities = {};

  /// Starts [operation] when [revision] has capacity available.
  ///
  /// A concurrent cold start is single-flighted. Requests beyond live capacity
  /// wait in FIFO order until [WorkloadCapacityPolicy.maximumQueuedRequests]
  /// is reached.
  Future<T> schedule<T>(
    WorkloadRevision revision,
    WorkloadCapacityPolicy policy,
    Future<T> Function() operation,
  ) {
    final capacity = _capacities.putIfAbsent(
      _RevisionKey(revision),
      () => _Capacity(revision, policy, _clock.now.toUtc()),
    );
    capacity.ensureCompatible(policy);
    if (capacity.isDraining) {
      return Future<T>.error(StateError('Revision is draining.'));
    }
    if (capacity.canStart) {
      return _start(capacity, operation);
    }
    if (capacity.queue.length >= policy.maximumQueuedRequests) {
      return Future<T>.error(WorkloadQueueFullException(revision.workloadName));
    }

    final completer = Completer<T>();
    capacity.queue.add(_QueuedOperation<T>(operation, completer));
    return completer.future;
  }

  /// Prevents new work on [revision] and completes after active work settles.
  Future<void> drain(WorkloadRevision revision) {
    final capacity = _capacities[_RevisionKey(revision)];
    if (capacity == null) {
      return Future.value();
    }
    capacity.isDraining = true;
    capacity.rejectQueued();
    if (capacity.busy == 0) {
      _capacities.remove(_RevisionKey(revision));
      return Future.value();
    }
    return capacity.drained.future;
  }

  /// Applies idle eviction using the injected deterministic clock.
  void tick() {
    final now = _clock.now.toUtc();
    final expired = <_RevisionKey>[];
    for (final entry in _capacities.entries) {
      final capacity = entry.value;
      if (capacity.busy == 0 &&
          capacity.queue.isEmpty &&
          now.difference(capacity.lastActivity) >=
              capacity.policy.idleTimeout) {
        expired.add(entry.key);
      }
    }
    for (final key in expired) {
      _capacities.remove(key);
    }
  }

  WorkloadCapacitySnapshot snapshot(WorkloadRevision revision) {
    final capacity = _capacities[_RevisionKey(revision)];
    if (capacity == null) {
      return const WorkloadCapacitySnapshot(
        state: WorkloadCapacityState.inactive,
        warmInstances: 0,
        busyInstances: 0,
        queuedRequests: 0,
      );
    }
    return capacity.snapshot;
  }

  Future<T> _start<T>(
    _Capacity capacity,
    Future<T> Function() operation,
  ) async {
    capacity.busy++;
    capacity.lastActivity = _clock.now.toUtc();
    try {
      await _ensureActivated(capacity);
      return await operation();
    } on Object {
      capacity.failed = true;
      rethrow;
    } finally {
      capacity.busy--;
      capacity.lastActivity = _clock.now.toUtc();
      _settle(capacity);
    }
  }

  Future<void> _ensureActivated(_Capacity capacity) {
    if (capacity.activation != null) {
      return capacity.activation!;
    }
    capacity.activating = true;
    return capacity.activation = _activate(capacity.revision).then(
      (_) {
        capacity.activating = false;
        capacity.warm = capacity.policy.desiredConcurrency;
      },
      onError: (Object error, StackTrace stackTrace) {
        capacity.activating = false;
        Error.throwWithStackTrace(error, stackTrace);
      },
    );
  }

  void _settle(_Capacity capacity) {
    if (capacity.isDraining) {
      if (capacity.busy == 0) {
        _capacities.remove(_RevisionKey(capacity.revision));
        if (!capacity.drained.isCompleted) {
          capacity.drained.complete();
        }
      }
      return;
    }
    while (capacity.canStart && capacity.queue.isNotEmpty) {
      capacity.queue.removeFirst().start(this, capacity);
    }
  }
}

final class _Capacity {
  _Capacity(this.revision, this.policy, this.lastActivity);

  final WorkloadRevision revision;
  final WorkloadCapacityPolicy policy;
  final Queue<_QueuedOperation<dynamic>> queue = Queue();
  final Completer<void> drained = Completer<void>();
  DateTime lastActivity;
  Future<void>? activation;
  bool activating = false;
  int warm = 0;
  int busy = 0;
  bool isDraining = false;
  bool failed = false;

  bool get canStart => busy < policy.maximumConcurrency;

  WorkloadCapacitySnapshot get snapshot => WorkloadCapacitySnapshot(
    state: isDraining
        ? WorkloadCapacityState.draining
        : failed
        ? WorkloadCapacityState.failed
        : activation == null
        ? WorkloadCapacityState.inactive
        : activating
        ? WorkloadCapacityState.compiling
        : busy > 0
        ? WorkloadCapacityState.busy
        : WorkloadCapacityState.warm,
    warmInstances: warm,
    busyInstances: busy,
    queuedRequests: queue.length,
  );

  void ensureCompatible(WorkloadCapacityPolicy requested) {
    if (policy != requested) {
      throw ArgumentError('A revision must use one capacity policy.');
    }
  }

  void rejectQueued() {
    while (queue.isNotEmpty) {
      queue.removeFirst().reject();
    }
  }
}

final class _QueuedOperation<T> {
  _QueuedOperation(this.operation, this.completer);

  final Future<T> Function() operation;
  final Completer<T> completer;

  void start(WorkloadCapacityScheduler scheduler, _Capacity capacity) {
    scheduler
        ._start(capacity, operation)
        .then(completer.complete, onError: completer.completeError);
  }

  void reject() => completer.completeError(StateError('Revision is draining.'));
}

final class _RevisionKey {
  _RevisionKey(WorkloadRevision revision)
    : workloadName = revision.workloadName,
      revision = revision.revision;

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
