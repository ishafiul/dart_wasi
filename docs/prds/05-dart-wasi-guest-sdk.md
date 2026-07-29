# PRD 05 — Minimal Dart WASI Guest SDK

## Status

Proposed

## Depends on

PRD 04

## Goal

Provide the smallest Dart API that the experimental compiler can lower into
WASI Preview 1 calls.

## Requirements

- Define supported stdout, stderr, stdin, arguments, environment, and exit APIs.
- Keep APIs in the separate `dart_wasi` package.
- Make compiler intrinsics explicit and versioned.
- Reject normal Dart VM use when behavior exists only after compilation.
- Document supported value types, encoding, ownership, and error behavior.

## Acceptance criteria

- A Dart guest imports `package:dart_wasi/dart_wasi.dart`.
- “Hello”, echo input, arguments, environment, and non-zero exit fixtures
  compile and run through `WasdEngine`.
- SDK APIs do not imply support for unimplemented Dart libraries.

## Non-goals

- HTTP request objects.
- Filesystem, sockets, threads, or async.
- Compatibility with arbitrary pub packages.
