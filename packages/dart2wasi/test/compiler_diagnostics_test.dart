import 'package:dart2wasi/dart2wasi.dart';
import 'package:test/test.dart';

void main() {
  group('compiler diagnostics', () {
    test('requires the guest SDK import for guest types and intrinsics', () {
      _expectUnsupported('''
void main() {
  Wasi.stdout.write('missing import');
}
''', contains('Guest APIs require import'));
    });

    test('rejects duplicate locals', () {
      _expectUnsupported('''
void main() {
  int value = 1;
  int value = 2;
}
''', contains('Duplicate parameter or local "value"'));
    });

    test('rejects use outside a local block scope', () {
      _expectUnsupported('''
void main() {
  if (true) {
    int scoped = 1;
  }
  scoped = 2;
}
''', contains('Unknown local "scoped"'));
    });

    test('checks declared function argument types', () {
      _expectUnsupported('''
int identity(int value) {
  return value;
}

void main() {
  identity(true);
}
''', contains('Argument 1 of "identity" must be int, not bool'));
    });

    test('requires non-void functions to return on every path', () {
      _expectUnsupported('''
int choose(bool condition) {
  if (condition) {
    return 1;
  }
}

void main() {}
''', contains('must return int value on every path'));
    });

    test('rejects reserved WASI function names', () {
      _expectUnsupported('''
void fd_write() {}
void main() {}
''', contains('reserved by the WASI runtime'));
    });

    test('requires valid constant environment names', () {
      _expectUnsupported('''
import 'package:dart_wasi/dart_wasi.dart';

void main() {
  Wasi.environment.contains('INVALID=NAME');
}
''', contains('Environment names must be non-empty'));
    });

    test('requires the exact HTTP fetch entrypoint signature', () {
      _expectUnsupported('''
import 'package:dart_wasi/dart_wasi.dart';

WasiHttpResponse fetch(int request) {
  return WasiHttpResponse.json(200, '{}');
}
''', contains('HTTP entrypoint must be'));
    });

    test('does not mix command and HTTP entrypoints', () {
      _expectUnsupported('''
import 'package:dart_wasi/dart_wasi.dart';

void main() {}
WasiHttpResponse fetch(WasiHttpRequest request) {
  return WasiHttpResponse.json(200, '{}');
}
''', contains('either void main() or an HTTP fetch handler'));
    });

    test('reserves stdin and stdout for HTTP envelopes', () {
      _expectUnsupported('''
import 'package:dart_wasi/dart_wasi.dart';

WasiHttpResponse fetch(WasiHttpRequest request) {
  Wasi.stdout.write('not an envelope');
  return WasiHttpResponse.json(200, '{}');
}
''', contains('reserve stdin and stdout'));
    });

    test('validates binary response content types at compile time', () {
      _expectUnsupported('''
import 'package:dart_wasi/dart_wasi.dart';

WasiHttpResponse fetch(WasiHttpRequest request) {
  return WasiHttpResponse.binary(200, request.body, 'bad\nvalue');
}
''', contains('HTTP content type must contain'));
    });
  });
}

void _expectUnsupported(String source, Matcher messageMatcher) {
  expect(
    () => const MinimalDartToWasiCompiler().compileSource(source),
    throwsA(
      isA<UnsupportedDartFeatureException>().having(
        (error) => error.message,
        'message',
        messageMatcher,
      ),
    ),
  );
}
