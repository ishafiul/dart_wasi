# PRD 02 — `wasd` Engine Adapter

## Status

Implemented

## Depends on

PRD 01

## Problem

The original binary reader began duplicating functionality already provided by
`wasd`. Platform code needs a narrow adapter over the dependency instead.

## Goal

Compile, inspect, instantiate, and run WASI Preview 1 modules through `wasd`
without leaking its types into the rest of the platform.

## Requirements

- Add a compatible pinned `wasd` dependency.
- Implement the local engine interface with public `wasd` APIs:
  `WebAssembly.validate`, `WebAssembly.compile`,
  `WebAssembly.instantiate`, `Module.imports`, `Module.exports`, and `WASI`.
- Translate `wasd` failures into stable platform error categories.
- Provide dependency injection or a fake engine for platform unit tests.
- Remove custom byte-reader, LEB128, module-envelope, interpreter, and WASI
  implementation code from the product library.
- Retain the concepts from the removed spike in
  `docs/learning/need-to-learn.md`.

## Acceptance criteria

- Empty and simple exported-function modules compile through the adapter.
- A genuine WASI Preview 1 module runs `_start` through `WASI`.
- Imports and exports can be inspected through platform metadata.
- No product source implements WebAssembly binary decoding or execution.
- Adapter tests distinguish validation, instantiation, trap, exit, and host
  integration failures where the `wasd` API permits.

## Validation notes

- Implemented against `wasd: ^0.3.0`, resolved to 0.3.0 in `pubspec.lock`, and
  Dart SDK `^3.11.0`.
- Product code imports only `package:wasd/wasd.dart`.
- The old byte reader and module-envelope code and tests were removed.
- A real WASI Preview 1 module importing `proc_exit` is exercised in tests and
  returns exit code 42 without terminating the Dart host.
- `wasd` 0.3.0 writes Preview 1 stdout/stderr to host stdio and does not expose
  injectable output sinks through its public API. Captured/bounded output is
  therefore deferred to PRD 05/08 and must use a future public upstream API or
  a stronger isolation boundary; this project will not import `package:wasd/src`
  to work around it.
- On the native backend, `wasd` 0.3.0 wraps host-callback exceptions in a
  private execution-trap type without a public typed cause. The adapter
  therefore preserves these as `WasmTrap`; a distinct `WasmHostException`
  cannot be recovered reliably through the public API.

## Non-goals

- Forking or patching `wasd`.
- Importing files from `package:wasd/src`.
- Building a fallback interpreter.
