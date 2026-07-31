# dart2wasi

Experimental compiler research for turning a deliberately small subset of Dart
into a standard WASI Preview 1 command module.

The first milestone compiles one deliberately small Dart program into a core
WASI Preview 1 command module that calls `wasi_snapshot_preview1.fd_write` and
`wasi_snapshot_preview1.proc_exit`:

```dart
void main() {
  Wasi.stdout.write('Hello from Dart!\\n');
}
```

The current restricted subset supports typed integer/boolean locals and
parameters, direct declared-function calls, arithmetic and boolean expressions,
`if`/`else`, `while`, `return`, and constant-string stdout writes. Compile it
with:

```shell
dart run dart2wasi path/to/hello.dart path/to/hello.wasm
```
