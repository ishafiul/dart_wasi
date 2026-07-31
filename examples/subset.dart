import 'package:dart_wasi/dart_wasi.dart';

int addOne(int value) {
  return value + 1;
}

void main() {
  int count = 0;

  while (count < 2) {
    count = addOne(count);
  }

  if (count == 2 && true) {
    Wasi.stdout.write('subset works\n');
  } else {
    Wasi.stdout.write('unexpected\n');
  }
}
