import 'dart:convert';

import '../errors.dart';

/// A stable category for failures reported at the platform boundary.
enum WasiFailureKind { compiler, host, engine, protocol, guest }

/// A lifecycle step measured by the WASI platform.
enum WasiLifecycleStage {
  route,
  queue,
  cache,
  compile,
  activation,
  instantiate,
  execute,
}

/// An immutable timing or outcome record for one platform lifecycle step.
final class WasiLifecycleEvent {
  const WasiLifecycleEvent({
    required this.correlationId,
    required this.stage,
    required this.elapsed,
    required this.succeeded,
    this.failureKind,
  });

  final String correlationId;
  final WasiLifecycleStage stage;
  final Duration elapsed;
  final bool succeeded;
  final WasiFailureKind? failureKind;
}

/// A numeric platform measurement.
final class WasiMetric {
  const WasiMetric({
    required this.name,
    required this.value,
    required this.correlationId,
  });

  final String name;
  final num value;
  final String correlationId;
}

/// A bounded, redacted diagnostic emitted by a guest on stderr.
final class WasiGuestLog {
  const WasiGuestLog({
    required this.correlationId,
    required this.message,
    required this.truncated,
  });

  final String correlationId;
  final String message;
  final bool truncated;
}

/// Receives structured platform diagnostics without deciding where to export them.
abstract interface class WasiTelemetrySink {
  void recordEvent(WasiLifecycleEvent event);
  void recordMetric(WasiMetric metric);
  void recordGuestLog(WasiGuestLog log);
}

/// In-memory telemetry suitable for embedding, tests, or forwarding elsewhere.
///
/// The class performs no I/O. Production hosts can forward these immutable
/// records to their metrics and tracing systems through a [WasiTelemetrySink].
final class WasiTelemetry implements WasiTelemetrySink {
  WasiTelemetry({
    this.maximumGuestLogBytes = 4096,
    Iterable<RegExp> redactions = const [],
  }) : _redactions = List.unmodifiable(redactions) {
    if (maximumGuestLogBytes < 1) {
      throw ArgumentError.value(
        maximumGuestLogBytes,
        'maximumGuestLogBytes',
        'must be positive',
      );
    }
  }

  final int maximumGuestLogBytes;
  final List<RegExp> _redactions;
  final List<WasiLifecycleEvent> _events = [];
  final List<WasiMetric> _metrics = [];
  final List<WasiGuestLog> _guestLogs = [];
  int _nextCorrelationId = 0;

  List<WasiLifecycleEvent> get events => List.unmodifiable(_events);
  List<WasiMetric> get metrics => List.unmodifiable(_metrics);
  List<WasiGuestLog> get guestLogs => List.unmodifiable(_guestLogs);

  /// Returns a locally unique correlation ID for one host request.
  String createCorrelationId() => 'wasi-${++_nextCorrelationId}';

  @override
  void recordEvent(WasiLifecycleEvent event) => _events.add(event);

  @override
  void recordMetric(WasiMetric metric) => _metrics.add(metric);

  @override
  void recordGuestLog(WasiGuestLog log) => _guestLogs.add(log);

  /// Redacts configured patterns and bounds one guest stderr record.
  void recordGuestStderr(String correlationId, List<int> bytes) {
    var message = utf8.decode(bytes, allowMalformed: true);
    for (final pattern in _redactions) {
      message = message.replaceAll(pattern, '[REDACTED]');
    }
    final encoded = utf8.encode(message);
    final truncated = encoded.length > maximumGuestLogBytes;
    final bounded = truncated
        ? utf8.decode(
            encoded.take(maximumGuestLogBytes).toList(),
            allowMalformed: true,
          )
        : message;
    recordGuestLog(
      WasiGuestLog(
        correlationId: correlationId,
        message: bounded,
        truncated: truncated,
      ),
    );
  }
}

/// Maps implementation exceptions to categories that remain stable for users.
WasiFailureKind classifyWasiFailure(Object error) => switch (error) {
  WasmValidationException _ => WasiFailureKind.compiler,
  WasiHttpProtocolException _ => WasiFailureKind.protocol,
  WasiHttpExecutionException _ || WasmTrap _ => WasiFailureKind.guest,
  WasmException _ => WasiFailureKind.engine,
  WorkloadException _ => WasiFailureKind.host,
  _ => WasiFailureKind.host,
};
