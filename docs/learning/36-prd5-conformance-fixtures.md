# 36 — PRD 5 Conformance Fixtures

PRD 5 is complete only when guest source, compiler output, WASI execution, and
SDK documentation agree.

A small set of fixtures should prove each supported operation end to end.

## Required fixtures

| Fixture | Host input | Expected result |
|---|---|---|
| Hello | None | Constant text on stdout and exit `0` |
| Stderr | None | Constant text on stderr and exit `0` |
| Echo | Stdin bytes | The same bytes on stdout |
| Arguments | Argument sequence | Selected argument on stdout |
| Environment | Environment entry | Selected value on stdout |
| Non-zero exit | None | Requested exit code and no host termination |

The echo fixture must use bytes read through `fd_read`. The argument and
environment fixtures must use their WASI imports rather than embedding the
expected values in generated data segments.

## Test at several layers

### 1. SDK contract tests

Verify that:

- The API version is public.
- Only intended classes and methods are exposed.
- Compiler-only methods throw `UnsupportedError` on the normal Dart VM.
- Documentation states supported types and behavior.

### 2. Compiler diagnostic tests

Reject:

- Unsupported intrinsics.
- Wrong argument counts or types.
- Unsupported runtime string operations.
- Invalid constant indexes or exit codes.
- Unsupported SDK versions.

Diagnostics should be stable enough for tests without exposing private parser
details.

### 3. Generated-module structure tests

Inspect imports and exports:

```text
required imports are present
unused capabilities are absent
_start is exported
memory is exported only when the host contract requires it
```

An environment-only fixture should not accidentally import filesystem or
socket APIs.

### 4. `WasdEngine` execution tests

Compile fresh source, execute it with `WasiExecutionOptions`, and assert:

```text
exit code
exact stdout bytes
exact stderr bytes
absence of unexpected output
```

Fresh compilation prevents stale `.wasm` fixtures from hiding compiler bugs.

### 5. Independent runtime tests

Run representative generated modules through Wasmtime or another independent
WASI Preview 1 runtime. This checks that `wasd` and `dart2wasi` do not share a
matching but non-standard assumption.

## Edge cases

Add focused coverage for:

- Empty stdin and immediate EOF.
- Input larger than one read.
- Input at and above the configured limit.
- Empty and UTF-8 arguments.
- Missing and empty environment values.
- Partial writes when they can be simulated.
- Non-zero errno behavior.
- Exit before later output.
- Fresh execution state between two runs.

## Capability check

Each generated module should import only the WASI operations required by its
source. PRD 5 must not accidentally imply support for:

- Filesystem access.
- Sockets.
- Threads.
- Clocks or randomness.
- Async execution.
- Arbitrary Dart or pub libraries.

## Verification commands

Run the workspace checks required by the PRD roadmap:

```shell
dart format --output=none --set-exit-if-changed .
dart analyze
dart test packages/dart2wasi/test
dart test packages/dart_wasi/test
dart test packages/wasi_runtime/test
```

CI should install the independent runtime before the test suite so its
conformance test cannot silently skip there.

## Completion checklist

PRD 5 can move from proposed to implemented when:

1. The version 1 SDK surface and supported value types are documented.
2. Every intrinsic rejects normal Dart VM execution clearly.
3. The compiler lowers stdout, stderr, stdin, arguments, environment, and exit.
4. Encoding, ownership, size limits, EOF, errno, and missing-value behavior are
   documented and tested.
5. All six required fixtures pass through `WasdEngine`.
6. Representative output also runs in an independent WASI runtime.
7. Generated modules import no unintended capabilities.

## Why we need to know this

Layered tests distinguish an SDK design bug, compiler bug, malformed Wasm
module, WASI integration bug, and host regression. They also keep PRD 5's
claims limited to behavior the project can demonstrate.

## References

- [PRD 05 — Minimal Dart WASI Guest SDK](../prds/05-dart-wasi-guest-sdk.md)
- [Wasmtime CLI](https://docs.wasmtime.dev/cli-options.html)
