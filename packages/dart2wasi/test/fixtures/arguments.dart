import 'package:dart_wasi/dart_wasi.dart';

void main() {
  if (Wasi.arguments.length == 3) {
    Wasi.stdout.writeBytes(Wasi.arguments.at(2));
  } else {
    Wasi.exit(2);
  }
}
