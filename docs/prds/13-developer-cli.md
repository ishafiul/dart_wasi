# PRD 13 — Compiler and Host CLI

## Status

Proposed

## Depends on

PRD 12

## Goal

Provide one local workflow from Dart source to deployed Wasm execution.

## Commands

```shell
dart run dart2wasi compile worker.dart -o worker.wasm
dart run dart_wasi_host inspect worker.wasm
dart run dart_wasi_host serve worker.wasm
```

## Acceptance criteria

- Users can compile, inspect, run, and locally serve a supported Dart Worker.
- Diagnostics identify compiler, validation, link, protocol, and guest errors.
