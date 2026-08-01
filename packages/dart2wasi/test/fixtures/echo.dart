import 'package:dart_wasi/dart_wasi.dart';

WasiBytes identity(WasiBytes value) {
  return value;
}

void main() {
  WasiBytes input = Wasi.stdin.readAll();
  Wasi.stdout.writeBytes(identity(input));
}
