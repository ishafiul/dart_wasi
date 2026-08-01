import 'package:dart_wasi/dart_wasi.dart';

void main() {
  if (Wasi.environment.contains('MODE')) {
    Wasi.stdout.writeBytes(Wasi.environment.valueOr('MODE', 'development'));
  } else {
    Wasi.stdout.writeBytes(Wasi.environment.valueOr('MODE', 'development'));
  }
}
