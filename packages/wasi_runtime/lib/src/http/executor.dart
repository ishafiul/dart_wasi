import 'dart:convert';
import 'dart:typed_data';

import '../errors.dart';
import '../runtime/api.dart';
import 'models.dart';
import 'protocol.dart';

/// A decoded HTTP response plus guest diagnostics written to stderr.
final class WasiHttpExecutionResult {
  WasiHttpExecutionResult({required this.response, required List<int> stderr})
    : stderr = Uint8List.fromList(stderr).asUnmodifiableView();

  final WasiHttpResponse response;
  final Uint8List stderr;
}

/// HTTP-over-WASI behavior layered on the engine-neutral compiled module API.
extension WasiHttpExecution on CompiledModule {
  Future<WasiHttpExecutionResult> runHttp(WasiHttpRequest request) async {
    final execution = await runWasi(
      WasiExecutionOptions(stdin: WasiHttpProtocol.encodeRequest(request)),
    );
    if (execution.exitCode != 0) {
      throw WasiHttpExecutionException(
        exitCode: execution.exitCode,
        stderr: utf8.decode(execution.stderr, allowMalformed: true),
      );
    }
    return WasiHttpExecutionResult(
      response: WasiHttpProtocol.decodeResponse(execution.stdout),
      stderr: execution.stderr,
    );
  }
}
