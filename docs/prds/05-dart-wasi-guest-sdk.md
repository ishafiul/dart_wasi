# PRD 05 — Minimal Dart WASI Guest SDK

## Status

Implemented

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

## Implemented API

The version 1 `dart_wasi` contract provides:

```text
Wasi.stdout.write(constantString)
Wasi.stdout.writeBytes(bytes)
Wasi.stderr.write(constantString)
Wasi.stderr.writeBytes(bytes)
Wasi.stdin.readAll()
Wasi.arguments.length
Wasi.arguments.at(index)
Wasi.environment.contains(constantName)
Wasi.environment.valueOr(constantName, constantFallback)
Wasi.exit(code)
```

Runtime data uses opaque `WasiBytes`, represented in generated Wasm as a packed
32-bit pointer and 32-bit byte length. Values are guest-owned and remain valid
for one execution. They may be stored, passed, returned, and written, but do
not provide general Dart string, list, or collection behavior.

Compile-time strings and host arguments/environment values use UTF-8. stdin and
`WasiBytes` output remain raw bytes and are not decoded by the guest SDK.

The complete value subset is:

- `int`: signed WebAssembly `i32`.
- `bool`: WebAssembly `i32` with `0` or `1`.
- `WasiBytes`: packed pointer and byte length in an `i64`.
- `String`: compile-time literals accepted only by documented intrinsics.
- `void` and non-returning `Wasi.exit` control flow.

## Limits and errors

- stdin: 16 KiB.
- arguments: 64 entries and 8 KiB total, including NUL terminators.
- environment: 64 entries and 16 KiB total, including NUL terminators.
- explicit exit status: 0 through 255.
- non-zero WASI errno: guest exits with that errno.
- invalid indexes, malformed host layouts, exceeded limits, or invalid dynamic
  exit statuses: guest exits with `dartWasiGuestRuntimeErrorExitCode` (`70`).

Every compiler-only SDK operation throws `UnsupportedError` on the normal Dart
VM. Generated modules contain a `dart_wasi.sdk` custom section with API version
1 and import only the WASI operations needed by their source.

## Verification fixtures

Dedicated fixtures cover Hello, stderr, exact binary echo, arguments,
environment lookup/fallback, non-zero exit, capability imports, invalid
indexes, and oversized stdin. They compile fresh source and execute through
`WasdEngine`; CI also runs Hello and binary echo through Wasmtime.

## Verification

Verified on 2026-08-01:

- Workspace formatting is unchanged and `dart analyze` reports no issues.
- All 23 `dart2wasi` compiler, diagnostic, and conformance tests pass locally.
- All 3 `dart_wasi` contract tests pass.
- All 20 `wasi_runtime` regression tests pass.
- The guest I/O example compiles and runs through `WasdEngine` with arguments,
  environment, stdin, stdout, stderr, and exit code `0`.
- Two Wasmtime tests are configured for Hello and exact binary stdin echo. They
  skip when Wasmtime is unavailable locally; CI installs Wasmtime and requires
  both tests to execute.

## Non-goals

- HTTP request objects.
- Filesystem, sockets, threads, or async.
- Compatibility with arbitrary pub packages.
