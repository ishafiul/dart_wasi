# PRD 04 — Dart-to-WASI Compiler Feasibility

## Status

Implemented (minimal feasibility subset)

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

## Implemented Dart subset

- One entry-point library and `void main()`.
- Typed `int` and `bool` function parameters and local variables.
- Integer and boolean literals.
- Direct calls to declared `void`, `int`, and `bool` functions.
- Integer arithmetic, comparisons, boolean `!`, `&&`, and `||`.
- `if`/`else`, `while`, assignment, and `return`.
- Constant UTF-8 strings.
- A compiler intrinsic for writing bytes to stdout.

The compiler intentionally remains a restricted source parser. It accepts only
these forms and reports unsupported syntax or APIs with a stable diagnostic.

## Required research

- Use a deliberately restricted source recognizer for the first feasibility
  fixture; choosing and integrating a full Dart frontend remains future work.
- Define the minimal runtime and memory layout.
- Generate valid core Wasm sections and instructions.
- Lower guest output to WASI Preview 1 `fd_write`.
- Generate memory, data segments, `_start`, and `proc_exit`.
- Confirm every generated feature is supported by `wasd` 0.3.x.

## Implementation notes

`MinimalDartToWasiCompiler` emits a core WebAssembly version 1 module with
`wasi_snapshot_preview1.fd_write` and `proc_exit` imports, exported `_start`
and memory, one linear-memory page, an iovec at offset zero, a byte count at
offset four, and UTF-8 text data at offset eight. The generated `_start` calls
`fd_write` for stdout, then exits with the returned errno (zero on success).

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
