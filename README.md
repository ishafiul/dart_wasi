# Dart and WASI experiment

I am experimenting with WASI in Dart and learning how WebAssembly works.

The main goal is to prove that a user can write a small Worker program in Dart,
compile it into a standard WASI Preview 1 `.wasm` file, and run it inside a Dart
host through `wasd`.

```text
Dart Worker source
→ experimental dart2wasi compiler
→ WASI Preview 1 module
→ Dart host
→ wasd
→ response
```

This is a learning project and proof of concept, not a production-ready
compiler, runtime, or platform.

## Workspace

- `packages/dart2wasi`: experimental Dart-to-WASI compiler research.
- `packages/dart_wasi`: minimal APIs available to Dart guest programs.
- `packages/wasi_runtime`: Dart host and `wasd` integration.

The compiler feasibility slice supports one intentionally tiny program shape:
one `Wasi.stdout.write` call with a constant string in `void main()`. It emits
a standard WASI Preview 1 module through `wasi_snapshot_preview1.fd_write`.
The existing host can validate, inspect, version, and execute standard WASI
modules.

```shell
dart run dart2wasi examples/hello.dart /tmp/hello.wasm
dart run examples/run_hello.dart
dart run examples/run_wasm.dart /tmp/hello.wasm

dart run dart2wasi examples/subset.dart /tmp/subset.wasm
dart run examples/run_wasm.dart /tmp/subset.wasm
```

`examples/run_wasm.dart` writes captured guest stdout and stderr before the
guest exit code.

## Intended result

If the proof of concept succeeds, a user will be able to:

- Write a small request handler in the supported Dart subset.
- Compile it into a WASI artifact.
- Upload and version that artifact.
- Route a request to the active revision.
- Execute the Dart-authored Worker only when requested.
- Return its response and release idle workload instances.
