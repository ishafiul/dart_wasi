import 'dart:convert';

import 'package:dart2wasi/dart2wasi.dart';
import 'package:test/test.dart';
import 'package:wasi_runtime/wasi_runtime.dart';

import 'support/guest_fixture.dart';

void main() {
  group('guest SDK conformance', () {
    test('runs the Hello fixture', () async {
      final result = await _runFixture('hello');

      expect(result.exitCode, 0);
      expect(utf8.decode(result.stdout), 'Hello from Dart!\n');
      expect(result.stderr, isEmpty);
    });

    test('captures the stderr fixture independently from stdout', () async {
      final result = await _runFixture('stderr');

      expect(result.exitCode, 0);
      expect(result.stdout, isEmpty);
      expect(utf8.decode(result.stderr), 'diagnostic\n');
    });

    test('echoes exact runtime stdin bytes', () async {
      const input = [0, 1, 2, 127, 128, 255];
      final result = await _runFixture('echo', stdin: input);

      expect(result.exitCode, 0);
      expect(result.stdout, input);
      expect(result.stderr, isEmpty);
    });

    test('accepts stdin exactly at the documented limit', () async {
      final input = List.filled(16 * 1024, 7);
      final result = await _runFixture('echo', stdin: input);

      expect(result.exitCode, 0);
      expect(result.stdout, input);
    });

    test('reads argument count and an indexed argument', () async {
      final result = await _runFixture(
        'arguments',
        arguments: const ['worker', '--mode', 'fast'],
      );

      expect(result.exitCode, 0);
      expect(utf8.decode(result.stdout), 'fast');
      expect(result.stderr, isEmpty);
    });

    test('looks up an exact environment name', () async {
      final result = await _runFixture(
        'environment',
        environment: const {
          'MODE_PREFIX': 'wrong',
          'OTHER': 'also wrong',
          'MODE': 'production=value',
        },
      );

      expect(result.exitCode, 0);
      expect(utf8.decode(result.stdout), 'production=value');
    });

    test('uses the explicit environment fallback for a missing name', () async {
      final result = await _runFixture('environment');

      expect(result.exitCode, 0);
      expect(utf8.decode(result.stdout), 'development');
    });

    test(
      'distinguishes an empty environment value from a missing name',
      () async {
        final result = await _runFixture(
          'environment',
          environment: const {'MODE': ''},
        );

        expect(result.exitCode, 0);
        expect(result.stdout, isEmpty);
      },
    );

    test('returns a non-zero exit without terminating the host', () async {
      final result = await _runFixture('exit');

      expect(result.exitCode, 42);
      expect(result.stdout, isEmpty);
      expect(utf8.decode(result.stderr), 'before exit\n');
    });

    test('imports exactly the required Preview 1 capabilities', () async {
      final compiler = const MinimalDartToWasiCompiler();
      final bytes = await compiler.compile(guestFixtureUri('all_capabilities'));
      final module = await const WasdEngine().compile(bytes);

      expect(
        module.imports.map((value) => '${value.module}.${value.name}'),
        const [
          'wasi_snapshot_preview1.fd_write',
          'wasi_snapshot_preview1.fd_read',
          'wasi_snapshot_preview1.args_sizes_get',
          'wasi_snapshot_preview1.args_get',
          'wasi_snapshot_preview1.environ_sizes_get',
          'wasi_snapshot_preview1.environ_get',
          'wasi_snapshot_preview1.proc_exit',
        ],
      );
    });

    test('uses a stable runtime status for invalid guest input', () async {
      final invalidArgument = await _runFixture(
        'invalid_argument',
        arguments: const ['only'],
      );
      final oversizedInput = await _runFixture(
        'echo',
        stdin: List.filled(16 * 1024 + 1, 1),
      );
      final invalidExit = await _runFixture('invalid_exit');

      expect(invalidArgument.exitCode, 70);
      expect(oversizedInput.exitCode, 70);
      expect(invalidExit.exitCode, 70);
    });
  });
}

Future<WasiExecutionResult> _runFixture(
  String name, {
  List<int> stdin = const [],
  List<String> arguments = const [],
  Map<String, String> environment = const {},
}) async {
  final compiler = const MinimalDartToWasiCompiler();
  final bytes = await compiler.compile(guestFixtureUri(name));
  final module = await const WasdEngine().compile(bytes);
  return module.runWasi(
    WasiExecutionOptions(
      stdin: stdin,
      arguments: arguments,
      environment: environment,
    ),
  );
}
