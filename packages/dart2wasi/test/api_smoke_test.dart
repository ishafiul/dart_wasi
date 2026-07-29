import 'package:dart2wasi/dart2wasi.dart';
import 'package:test/test.dart';

void main() {
  test('compiler contract is public', () {
    const error = UnsupportedDartFeatureException('unsupported');
    expect(error.message, 'unsupported');
  });
}
