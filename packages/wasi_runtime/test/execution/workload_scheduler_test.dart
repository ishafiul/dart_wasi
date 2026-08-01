import 'dart:async';

import 'package:test/test.dart';
import 'package:wasi_runtime/wasi_runtime.dart';

void main() {
  group('WorkloadCapacityScheduler', () {
    test(
      'single-flights cold activation for concurrent first demand',
      () async {
        final activationGate = Completer<void>();
        var activations = 0;
        final scheduler = WorkloadCapacityScheduler(
          clock: _Clock(),
          activate: (_) {
            activations++;
            return activationGate.future;
          },
        );
        const policy = WorkloadCapacityPolicy(maximumConcurrency: 2);

        final first = scheduler.schedule(_revision(1), policy, () async => 1);
        final second = scheduler.schedule(_revision(1), policy, () async => 2);
        await Future<void>.delayed(Duration.zero);

        expect(activations, 1);
        expect(
          scheduler.snapshot(_revision(1)).state,
          WorkloadCapacityState.compiling,
        );

        activationGate.complete();
        expect(await Future.wait([first, second]), [1, 2]);
        expect(
          scheduler.snapshot(_revision(1)).state,
          WorkloadCapacityState.warm,
        );
      },
    );

    test('expands a burst only to its limit and bounds the queue', () async {
      final firstGate = Completer<int>();
      final secondGate = Completer<int>();
      final scheduler = WorkloadCapacityScheduler(
        clock: _Clock(),
        activate: (_) async {},
      );
      const policy = WorkloadCapacityPolicy(
        maximumConcurrency: 2,
        maximumQueuedRequests: 1,
      );

      final first = scheduler.schedule(
        _revision(1),
        policy,
        () => firstGate.future,
      );
      final second = scheduler.schedule(
        _revision(1),
        policy,
        () => secondGate.future,
      );
      final queued = scheduler.schedule(_revision(1), policy, () async => 3);
      final rejected = expectLater(
        scheduler.schedule(_revision(1), policy, () async => 4),
        throwsA(isA<WorkloadQueueFullException>()),
      );
      await Future<void>.delayed(Duration.zero);

      final snapshot = scheduler.snapshot(_revision(1));
      expect(snapshot.busyInstances, 2);
      expect(snapshot.queuedRequests, 1);
      await rejected;

      firstGate.complete(1);
      secondGate.complete(2);
      expect(await Future.wait([first, second, queued]), [1, 2, 3]);
    });

    test(
      'returns an idle workload to zero when the host advances time',
      () async {
        final clock = _Clock();
        final scheduler = WorkloadCapacityScheduler(
          clock: clock,
          activate: (_) async {},
        );
        const policy = WorkloadCapacityPolicy(
          idleTimeout: Duration(seconds: 30),
        );

        await scheduler.schedule(_revision(1), policy, () async {});
        expect(scheduler.snapshot(_revision(1)).warmInstances, 1);

        clock.advance(const Duration(seconds: 30));
        scheduler.tick();

        expect(
          scheduler.snapshot(_revision(1)).state,
          WorkloadCapacityState.inactive,
        );
      },
    );

    test('drains an old revision without interrupting active work', () async {
      final oldGate = Completer<void>();
      final scheduler = WorkloadCapacityScheduler(
        clock: _Clock(),
        activate: (_) async {},
      );
      const policy = WorkloadCapacityPolicy();
      final old = _revision(1);
      final replacement = _revision(2);

      final oldRequest = scheduler.schedule(old, policy, () => oldGate.future);
      await Future<void>.delayed(Duration.zero);
      final drained = scheduler.drain(old);

      await expectLater(
        scheduler.schedule(old, policy, () async {}),
        throwsA(isA<StateError>()),
      );
      await scheduler.schedule(replacement, policy, () async {});
      expect(scheduler.snapshot(old).state, WorkloadCapacityState.draining);

      oldGate.complete();
      await oldRequest;
      await drained;
      expect(scheduler.snapshot(old).state, WorkloadCapacityState.inactive);
      expect(scheduler.snapshot(replacement).state, WorkloadCapacityState.warm);
    });
  });
}

WorkloadRevision _revision(int version) => WorkloadRevision(
  workloadName: 'worker',
  revision: version,
  artifactId: 'artifact-$version',
  createdAt: DateTime.utc(2026, 8, 1),
);

final class _Clock implements WorkloadSchedulerClock {
  DateTime _now = DateTime.utc(2026, 8, 1);

  @override
  DateTime get now => _now;

  void advance(Duration duration) {
    _now = _now.add(duration);
  }
}
