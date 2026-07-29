# PRD 04 — Dart-to-WASI Compiler Feasibility

## Status

Proposed

## Depends on

PRD 03

## Problem

Official `dart compile wasm` produces WasmGC for JavaScript environments, not a
standard WASI Preview 1 command module. The main project goal requires user
Worker code to be written in Dart.

## Goal

Compile one deliberately small Dart program into a core WebAssembly module that
imports `wasi_snapshot_preview1`, exports `_start`, and runs through
`WasdEngine`.

## Initial supported Dart subset

- One entry-point library and `void main()`.
- Integer and boolean literals.
- Local variables.
- Direct function calls.
- Basic control flow needed by the fixture.
- Constant UTF-8 strings.
- A compiler intrinsic for writing bytes to stdout.

Everything else must fail with a clear unsupported-feature diagnostic.

## Required research

- Choose a frontend: Dart Kernel IR or a smaller source parser.
- Define the minimal runtime and memory layout.
- Generate valid core Wasm sections and instructions.
- Lower guest output to WASI Preview 1 `fd_write`.
- Generate memory, data segments, `_start`, and `proc_exit`.
- Confirm every generated feature is supported by `wasd` 0.3.x.

## Acceptance criteria

Given:

```dart
void main() {
  Wasi.stdout.write('Hello from Dart!\n');
}
```

The compiler produces `hello.wasm`, and executing it through `WasdEngine`
successfully invokes `_start` and writes the expected bytes.

- Output is a core Wasm version 1 module, not Dart's browser WasmGC output.
- The module imports only documented WASI Preview 1 functions.
- Unsupported Dart syntax or libraries produce stable diagnostics.
- The generated fixture also validates in an independent WASI runtime when
  available.

## Non-goals

- Full Dart language support.
- Flutter.
- Dart VM compatibility inside the guest.
- Garbage-collected objects, async, isolates, reflection, FFI, or `dart:io`.
- Optimizing code generation.
