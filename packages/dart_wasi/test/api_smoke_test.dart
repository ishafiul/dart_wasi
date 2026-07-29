import 'package:dart_wasi/dart_wasi.dart';
import 'package:test/test.dart';

void main() {
  test('guest API exposes a version', () {
    expect(dartWasiGuestApiVersion, 1);
  });
}
