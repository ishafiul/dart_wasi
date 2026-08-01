import 'package:dart_wasi/dart_wasi.dart';

void main() {
  Wasi.stderr.write('before exit\n');
  Wasi.exit(42);
}
