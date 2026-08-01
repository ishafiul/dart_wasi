import 'package:dart_wasi/dart_wasi.dart';

int invalidExitCode() {
  return 256;
}

void main() {
  Wasi.exit(invalidExitCode());
}
