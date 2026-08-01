import 'dart:convert';

import 'package:dart2wasi/dart2wasi.dart';
import 'package:dart_wasi/dart_wasi.dart' as guest;
import 'package:test/test.dart';
import 'package:wasi_runtime/wasi_runtime.dart';

import 'support/guest_fixture.dart';

void main() {
  group('HTTP guest conformance', () {
    test('runs a Dart fetch handler that returns JSON', () async {
      final module = await _compileFixture('http_json');

      final result = await module.runHttp(
        WasiHttpRequest(method: 'GET', path: '/hello'),
      );

      expect(result.response.status, 200);
      expect(result.response.header('content-type'), 'application/json');
      expect(
        utf8.decode(result.response.body),
        '{"message":"Hello from Dart"}',
      );
      expect(utf8.decode(result.stderr), 'handled request\n');
    });

    test('round-trips request metadata, a header, and binary body', () async {
      final module = await _compileFixture('http_echo');
      const body = [0, 1, 2, 127, 128, 255];

      final result = await module.runHttp(
        WasiHttpRequest(
          method: 'POST',
          path: '/echo',
          query: 'mode=raw',
          headers: const [WasiHttpHeader('x-trace', 'abc')],
          body: body,
        ),
      );

      expect(result.response.status, 201);
      expect(
        result.response.header('content-type'),
        'application/octet-stream',
      );
      expect(result.response.body, body);
      expect(utf8.decode(result.stderr), 'POST|/echo|mode=raw|x-trace|abc');
    });

    test(
      'malformed request envelopes exit with the guest runtime status',
      () async {
        final module = await _compileFixture('http_json');
        final envelope = WasiHttpProtocol.encodeRequest(
          WasiHttpRequest(method: 'GET', path: '/'),
        );
        envelope[4] = 2;

        final result = await module.runWasi(
          WasiExecutionOptions(stdin: envelope),
        );

        expect(result.exitCode, guest.dartWasiGuestRuntimeErrorExitCode);
        expect(result.stdout, isEmpty);
      },
    );

    test('imports only descriptor I/O and process exit', () async {
      final module = await _compileFixture('http_json');

      expect(
        module.imports.map((value) => '${value.module}.${value.name}'),
        const [
          'wasi_snapshot_preview1.fd_write',
          'wasi_snapshot_preview1.fd_read',
          'wasi_snapshot_preview1.proc_exit',
        ],
      );
    });
  });
}

Future<CompiledModule> _compileFixture(String name) async {
  final bytes = await const MinimalDartToWasiCompiler().compile(
    guestFixtureUri(name),
  );
  return const WasdEngine().compile(bytes);
}
