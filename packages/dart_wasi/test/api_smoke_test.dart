import 'package:dart_wasi/dart_wasi.dart';
import 'package:test/test.dart';

void main() {
  group('guest API contract', () {
    test('exposes the supported version and runtime error status', () {
      expect(dartWasiGuestApiVersion, 1);
      expect(dartWasiGuestRuntimeErrorExitCode, 70);
    });

    test('exposes only the explicit guest service objects', () {
      expect(Wasi.stdout, isA<WasiOutput>());
      expect(Wasi.stderr, isA<WasiOutput>());
      expect(Wasi.stdin, isA<WasiInput>());
      expect(Wasi.arguments, isA<WasiArguments>());
      expect(Wasi.environment, isA<WasiEnvironment>());
    });

    test('compiler intrinsics reject normal Dart VM execution', () {
      expect(() => Wasi.stdout.write('text'), throwsUnsupportedError);
      expect(() => Wasi.stderr.write('text'), throwsUnsupportedError);
      expect(Wasi.stdin.readAll, throwsUnsupportedError);
      expect(() => Wasi.arguments.length, throwsUnsupportedError);
      expect(() => Wasi.arguments.at(0), throwsUnsupportedError);
      expect(() => Wasi.environment.contains('MODE'), throwsUnsupportedError);
      expect(
        () => Wasi.environment.valueOr('MODE', 'development'),
        throwsUnsupportedError,
      );
      expect(() => Wasi.exit(1), throwsUnsupportedError);
    });
  });
}
