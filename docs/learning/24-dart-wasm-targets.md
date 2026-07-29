# 24 — Dart's WebAssembly Targets

Dart can already compile code to WebAssembly:

```shell
dart compile wasm app.dart
```

But that output is designed for web and JavaScript environments. It uses
WasmGC and expects support around the generated module.

Our target is different:

```text
core Wasm version 1
imports wasi_snapshot_preview1
exports _start
runs without a JavaScript host
```

That is why the project needs an experimental compiler rather than passing
official Dart Wasm output directly to `wasd`.

The first compiler supports only a small Dart subset. It is not a replacement
for the official Dart compiler.

## Why we need to know this

It prevents us from confusing “Dart can compile to Wasm” with “Dart can compile
to a standard WASI Preview 1 command module.”

## References

- [Dart WebAssembly compilation](https://dart.dev/web/wasm)
- [Dart compile command](https://dart.dev/tools/dart-compile)
