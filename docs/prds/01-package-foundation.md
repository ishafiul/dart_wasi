# PRD 01 — Workspace Foundation and Package Boundaries

## Status

Implemented; scope corrected by platform pivot

## Goal

Maintain a Dart workspace with separate compiler, guest SDK, and host-runtime
packages. The host engine implementation is `wasd`; platform APIs must not
expose engine internals.

## Requirements

- Keep workspace metadata, linting, tests, examples, licenses, and CI.
- Separate `dart2wasi`, `dart_wasi`, and `wasi_runtime`.
- Define platform-owned abstractions for compiled workloads and executions.
- Document `wasd` as the selected WebAssembly/WASI engine.
- Restrict engine integration to public `package:wasd/wasd.dart` APIs.
- Document WASI Preview 1, Dart VM, and HTTP workload scope.

## Acceptance criteria

- Package imports successfully.
- CI runs format, analysis, and tests.
- Engine-neutral public APIs do not expose `wasd` types.
- Documentation does not claim this package implements a WebAssembly runtime.

## Non-goals

- Binary parsing, validation, interpretation, or WASI syscall implementation.
- Scheduler, registry, or HTTP dispatch.
