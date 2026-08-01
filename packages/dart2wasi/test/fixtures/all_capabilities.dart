import 'package:dart_wasi/dart_wasi.dart';

void main() {
  Wasi.stderr.write('running\n');
  if (Wasi.arguments.length > 0) {
    Wasi.stdout.writeBytes(Wasi.arguments.at(0));
  }
  Wasi.stdout.writeBytes(Wasi.environment.valueOr('MODE', 'development'));
  Wasi.stdout.writeBytes(Wasi.stdin.readAll());
}
