import 'dart:async';
import 'dart:typed_data';

import '../errors.dart';
import '../execution/request_executor.dart';
import '../execution/workload_executor.dart';
import '../observability/telemetry.dart';
import 'models.dart';
import 'protocol.dart';

/// A host and path-prefix rule that selects an active workload.
final class WasiHttpRoute {
  WasiHttpRoute({
    required this.hostname,
    required this.pathPrefix,
    required this.workloadName,
    this.maximumConcurrentRequests = 1,
  }) {
    if (hostname.isEmpty) {
      throw ArgumentError.value(hostname, 'hostname', 'must not be empty');
    }
    if (!pathPrefix.startsWith('/')) {
      throw ArgumentError.value(
        pathPrefix,
        'pathPrefix',
        'must start with "/"',
      );
    }
    if (workloadName.isEmpty) {
      throw ArgumentError.value(
        workloadName,
        'workloadName',
        'must not be empty',
      );
    }
    if (maximumConcurrentRequests < 1) {
      throw ArgumentError.value(
        maximumConcurrentRequests,
        'maximumConcurrentRequests',
        'must be at least one',
      );
    }
  }

  final String hostname;
  final String pathPrefix;
  final String workloadName;
  final int maximumConcurrentRequests;

  bool matches(String requestHostname, String requestPath) {
    if (hostname.toLowerCase() != requestHostname.toLowerCase()) {
      return false;
    }
    return pathPrefix == '/' ||
        requestPath == pathPrefix ||
        requestPath.startsWith('$pathPrefix/');
  }
}

/// Routes host HTTP requests to isolated active WASI workloads.
///
/// Capacity is shared by every route for a workload, so aliases cannot bypass
/// workload-level backpressure. A full workload fails fast with HTTP 503.
final class WasiHttpDispatcher {
  WasiHttpDispatcher({
    required WasiWorkloadExecutor executor,
    required Iterable<WasiHttpRoute> routes,
    this.telemetry,
  }) : _executor = executor,
       _routes = List.unmodifiable(routes) {
    if (_routes.isEmpty) {
      throw ArgumentError.value(routes, 'routes', 'must not be empty');
    }
    for (final route in _routes) {
      final existing = _limiters[route.workloadName];
      if (existing == null) {
        _limiters[route.workloadName] = _WorkloadLimiter(
          route.maximumConcurrentRequests,
        );
      } else if (existing.maximum != route.maximumConcurrentRequests) {
        throw ArgumentError(
          'Routes for workload "${route.workloadName}" must use the same '
          'maximumConcurrentRequests.',
        );
      }
    }
  }

  final WasiWorkloadExecutor _executor;
  final List<WasiHttpRoute> _routes;
  final Map<String, _WorkloadLimiter> _limiters = {};
  final WasiTelemetry? telemetry;

  Future<WasiHttpResponse> dispatch({
    required String hostname,
    required WasiHttpRequest request,
    Duration? timeout,
    WasiRequestCancellation? cancellation,
    String? correlationId,
  }) async {
    final requestId = correlationId ?? telemetry?.createCorrelationId() ?? '';
    final stopwatch = Stopwatch()..start();
    Object? failure;
    try {
      final route = _routes.cast<WasiHttpRoute?>().firstWhere(
        (candidate) => candidate!.matches(hostname, request.path),
        orElse: () => null,
      );
      if (route == null) {
        return _emptyResponse(404);
      }

      final limiter = _limiters[route.workloadName]!;
      if (!limiter.tryAcquire()) {
        return _emptyResponse(503);
      }
      try {
        final result = await _executor.execute(
          route.workloadName,
          WasiRequest(stdin: WasiHttpProtocol.encodeRequest(request)),
          timeout: timeout,
          cancellation: cancellation,
          correlationId: requestId,
        );
        return _toHttpResponse(result.request);
      } finally {
        limiter.release();
      }
    } on Object catch (error) {
      failure = error;
      rethrow;
    } finally {
      stopwatch.stop();
      _recordRoute(
        requestId,
        stopwatch,
        succeeded: failure == null,
        failure: failure,
      );
    }
  }

  void _recordRoute(
    String correlationId,
    Stopwatch stopwatch, {
    required bool succeeded,
    Object? failure,
  }) {
    if (correlationId.isEmpty) {
      return;
    }
    telemetry?.recordEvent(
      WasiLifecycleEvent(
        correlationId: correlationId,
        stage: WasiLifecycleStage.route,
        elapsed: stopwatch.elapsed,
        succeeded: succeeded,
        failureKind: failure == null ? null : classifyWasiFailure(failure),
      ),
    );
    telemetry?.recordMetric(
      WasiMetric(
        name: 'route.duration_ms',
        value:
            stopwatch.elapsedMicroseconds / Duration.microsecondsPerMillisecond,
        correlationId: correlationId,
      ),
    );
  }

  WasiHttpResponse _toHttpResponse(WasiRequestResult result) {
    return switch (result.status) {
      WasiRequestStatus.completed => _decodeResponse(result),
      WasiRequestStatus.timedOut => _emptyResponse(504),
      WasiRequestStatus.cancelled => _emptyResponse(499),
      WasiRequestStatus.rejected => _emptyResponse(503),
      WasiRequestStatus.exited ||
      WasiRequestStatus.trapped ||
      WasiRequestStatus.failed => _emptyResponse(502),
    };
  }

  WasiHttpResponse _decodeResponse(WasiRequestResult result) {
    final execution = result.execution;
    if (execution == null) {
      return _emptyResponse(502);
    }
    try {
      return WasiHttpProtocol.decodeResponse(execution.stdout);
    } on WasiHttpProtocolException {
      return _emptyResponse(502);
    }
  }
}

WasiHttpResponse _emptyResponse(int status) =>
    WasiHttpResponse(status: status, body: Uint8List(0));

final class _WorkloadLimiter {
  _WorkloadLimiter(this.maximum);

  final int maximum;
  int _active = 0;

  bool tryAcquire() {
    if (_active >= maximum) {
      return false;
    }
    _active++;
    return true;
  }

  void release() {
    _active--;
  }
}
