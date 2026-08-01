import 'package:dart_wasi/dart_wasi.dart';

void main() {
  Wasi.stdout.writeBytes(Wasi.arguments.at(1));
}
