import 'dart:convert';

import 'request_executor.dart';

/// Immutable limits and capabilities assigned to one workload revision.
///
/// This runtime never supplies filesystem preopens, host files, or network
/// access. Environment values are denied unless explicitly enabled.
final class WasiCapabilityPolicy {
  const WasiCapabilityPolicy({
    this.maximumInputBytes = 16 * 1024,
    this.maximumOutputBytes = 16 * 1024,
    this.maximumConcurrentRequests = 1,
    this.maximumWallTime = const Duration(seconds: 5),
    this.allowsEnvironment = false,
  }) : assert(maximumInputBytes >= 0),
       assert(maximumOutputBytes >= 0),
       assert(maximumConcurrentRequests >= 1);

  final int maximumInputBytes;
  final int maximumOutputBytes;
  final int maximumConcurrentRequests;
  final Duration maximumWallTime;
  final bool allowsEnvironment;

  @override
  bool operator ==(Object other) =>
      other is WasiCapabilityPolicy &&
      maximumInputBytes == other.maximumInputBytes &&
      maximumOutputBytes == other.maximumOutputBytes &&
      maximumConcurrentRequests == other.maximumConcurrentRequests &&
      maximumWallTime == other.maximumWallTime &&
      allowsEnvironment == other.allowsEnvironment;

  @override
  int get hashCode => Object.hash(
    maximumInputBytes,
    maximumOutputBytes,
    maximumConcurrentRequests,
    maximumWallTime,
    allowsEnvironment,
  );

  WasiRequest applyTo(WasiRequest request) => WasiRequest(
    arguments: request.arguments,
    environment: allowsEnvironment ? request.environment : const {},
    stdin: request.stdin,
  );

  int inputBytesFor(WasiRequest request) {
    var bytes = request.stdin.length;
    for (final argument in request.arguments) {
      bytes += utf8.encode(argument).length;
    }
    if (allowsEnvironment) {
      for (final entry in request.environment.entries) {
        bytes +=
            utf8.encode(entry.key).length + utf8.encode(entry.value).length;
      }
    }
    return bytes;
  }
}
