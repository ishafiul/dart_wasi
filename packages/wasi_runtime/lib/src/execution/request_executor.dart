import 'dart:async';
import 'dart:typed_data';

import '../errors.dart';
import '../runtime/api.dart';

/// Immutable input supplied to one isolated WASI command execution.
///
/// The executor deliberately exposes no filesystem preopens or inherited host
/// environment. Each request receives only the values explicitly supplied here.
final class WasiRequest {
  WasiRequest({
    List<String> arguments = const [],
    Map<String, String> environment = const {},
    List<int> stdin = const [],
  }) : _arguments = List.unmodifiable(arguments),
       _environment = Map.unmodifiable(environment),
       _stdin = Uint8List.fromList(stdin).asUnmodifiableView();

  final List<String> _arguments;
  final Map<String, String> _environment;
  final Uint8List _stdin;

  List<String> get arguments => _arguments;
  Map<String, String> get environment => _environment;
  Uint8List get stdin => _stdin;
}

/// The terminal state returned for one request at the host boundary.
enum WasiRequestStatus {
  completed,
  exited,
  trapped,
  timedOut,
  cancelled,
  failed,
}

/// Structured result of one request-scoped WASI execution.
final class WasiRequestResult {
  const WasiRequestResult._({
    required this.status,
    required this.elapsed,
    this.execution,
    this.failure,
  });

  final WasiRequestStatus status;
  final Duration elapsed;

  /// Guest streams and exit code when the guest reached a normal exit.
  final WasiExecutionResult? execution;

  /// The stable platform failure for trapped or otherwise failed requests.
  final WasmException? failure;

  bool get isSuccess => status == WasiRequestStatus.completed;
}

/// Cooperative cancellation signal for a single request.
final class WasiRequestCancellation {
  final Completer<void> _completion = Completer<void>();

  bool get isCancelled => _completion.isCompleted;

  Future<void> get whenCancelled => _completion.future;

  void cancel() {
    if (!_completion.isCompleted) {
      _completion.complete();
    }
  }
}

/// Runs a compiled WASI command with a fresh request-specific context.
///
/// A timeout or cancellation returns control at this host boundary. It cannot
/// forcibly interrupt an engine invocation that has already begun; engines
/// with hard preemption can be introduced behind [CompiledModule] later.
final class WasiRequestExecutor {
  const WasiRequestExecutor(this._module);

  final CompiledModule _module;

  Future<WasiRequestResult> execute(
    WasiRequest request, {
    Duration? timeout,
    WasiRequestCancellation? cancellation,
  }) async {
    if (timeout != null && timeout.isNegative) {
      throw ArgumentError.value(timeout, 'timeout', 'must not be negative');
    }

    final stopwatch = Stopwatch()..start();
    if (cancellation?.isCancelled ?? false) {
      return _cancelled(stopwatch);
    }

    final options = WasiExecutionOptions(
      arguments: List<String>.from(request.arguments),
      environment: Map<String, String>.from(request.environment),
      stdin: Uint8List.fromList(request.stdin),
    );
    final outcome = await _awaitBoundary(
      _module.runWasi(options),
      timeout: timeout,
      cancellation: cancellation,
    );
    stopwatch.stop();

    return switch (outcome) {
      _ExecutionOutcome(:final result?) => WasiRequestResult._(
        status: result.exitCode == 0
            ? WasiRequestStatus.completed
            : WasiRequestStatus.exited,
        elapsed: stopwatch.elapsed,
        execution: result,
      ),
      _ExecutionOutcome(:final error?) when error is WasmTrap =>
        WasiRequestResult._(
          status: WasiRequestStatus.trapped,
          elapsed: stopwatch.elapsed,
          failure: error,
        ),
      _ExecutionOutcome(:final error?) when error is WasmException =>
        WasiRequestResult._(
          status: WasiRequestStatus.failed,
          elapsed: stopwatch.elapsed,
          failure: error,
        ),
      _ExecutionOutcome(:final error?) => WasiRequestResult._(
        status: WasiRequestStatus.failed,
        elapsed: stopwatch.elapsed,
        failure: WasmInstantiationException(
          'The WASI request could not be executed.',
          cause: error,
        ),
      ),
      _ExecutionOutcome() => WasiRequestResult._(
        status: WasiRequestStatus.failed,
        elapsed: stopwatch.elapsed,
        failure: const WasmInstantiationException(
          'The WASI request completed without a result.',
        ),
      ),
      _TimeoutOutcome() => WasiRequestResult._(
        status: WasiRequestStatus.timedOut,
        elapsed: stopwatch.elapsed,
      ),
      _CancellationOutcome() => _cancelled(stopwatch),
    };
  }

  WasiRequestResult _cancelled(Stopwatch stopwatch) {
    stopwatch.stop();
    return WasiRequestResult._(
      status: WasiRequestStatus.cancelled,
      elapsed: stopwatch.elapsed,
    );
  }
}

Future<_RequestOutcome> _awaitBoundary(
  Future<WasiExecutionResult> execution, {
  required Duration? timeout,
  required WasiRequestCancellation? cancellation,
}) {
  final outcomes = <Future<_RequestOutcome>>[
    execution.then<_RequestOutcome>(
      _ExecutionOutcome.result,
      onError: (Object error, StackTrace _) => _ExecutionOutcome.error(error),
    ),
  ];
  if (timeout != null) {
    outcomes.add(Future<_RequestOutcome>.delayed(timeout, _TimeoutOutcome.new));
  }
  if (cancellation != null) {
    outcomes.add(
      cancellation.whenCancelled.then((_) => const _CancellationOutcome()),
    );
  }
  return Future.any(outcomes);
}

sealed class _RequestOutcome {
  const _RequestOutcome();
}

final class _ExecutionOutcome extends _RequestOutcome {
  const _ExecutionOutcome.result(this.result) : error = null;
  const _ExecutionOutcome.error(this.error) : result = null;

  final WasiExecutionResult? result;
  final Object? error;
}

final class _TimeoutOutcome extends _RequestOutcome {
  const _TimeoutOutcome();
}

final class _CancellationOutcome extends _RequestOutcome {
  const _CancellationOutcome();
}
