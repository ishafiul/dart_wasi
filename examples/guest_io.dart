import 'package:dart_wasi/dart_wasi.dart';

void main() {
  Wasi.stderr.write('guest started\n');

  if (Wasi.arguments.length > 1) {
    Wasi.stdout.write('argument: ');
    Wasi.stdout.writeBytes(Wasi.arguments.at(1));
    Wasi.stdout.write('\n');
  }

  Wasi.stdout.write('mode: ');
  Wasi.stdout.writeBytes(Wasi.environment.valueOr('MODE', 'development'));
  Wasi.stdout.write('\nstdin: ');
  Wasi.stdout.writeBytes(Wasi.stdin.readAll());
}
