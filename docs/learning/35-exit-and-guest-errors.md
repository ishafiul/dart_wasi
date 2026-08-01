# 35 — Exit and Guest Error Semantics

A WASI command reports its final status with `proc_exit`:

```dart
Wasi.exit(42);
```

The compiler lowers this to:

```text
call wasi_snapshot_preview1.proc_exit(42)
```

The host has `returnOnExit` enabled, so an exit returns a status to the Dart
platform instead of terminating the host process.

## Exit does not return

`proc_exit` ends the guest command. Statements after `Wasi.exit` must not run:

```dart
Wasi.exit(2);
Wasi.stdout.write('unreachable');
```

The SDK can express this with Dart's `Never` type. The compiler must also model
the operation as non-returning so that generated control flow remains valid.

The underlying WASI import has no result value, so code generation may need an
`unreachable` instruction after the call to describe the control-flow fact to
WebAssembly validation.

## Normal completion

The SDK must define the status when `main` returns normally. The conventional
choice is:

```text
normal return → exit code 0
```

An explicit non-zero exit must remain distinguishable from a trap or host
failure.

## Four different failure layers

Do not turn every failure into the same exception or exit code:

1. **Compile-time diagnostic** — unsupported Dart syntax, type, intrinsic, or
   SDK version.
2. **WASI errno** — an imported operation such as `fd_read` or `fd_write`
   reports an ordinary error.
3. **Guest exit** — the program intentionally calls `Wasi.exit(code)`.
4. **WebAssembly trap** — invalid memory access, division by zero,
   `unreachable`, or another runtime fault.

The host may later normalize these into platform failure categories, but the
compiler and SDK should preserve the distinction.

## Choosing an errno policy

The first SDK may not expose errno values directly. It still needs one
documented behavior for intrinsic failures.

For example:

```text
successful operation → continue
non-zero errno       → terminate with an SDK-reserved failure status
```

Another option is a restricted result type. Whichever policy is chosen must be
consistent across stdin, stdout, stderr, arguments, and environment.

Silently dropping errno values makes successful execution indistinguishable
from lost input or truncated output.

## Exit-code range

WASI Preview 1 represents an exit code as an unsigned 32-bit value. The Dart
SDK should define the accepted Dart `int` range and reject values outside it at
compile time when constant or at runtime when dynamic.

If the platform intentionally limits codes further for portability, that
smaller range must be documented.

## VM behavior

Calling `Wasi.exit` on the normal Dart VM must throw `UnsupportedError`; it must
never call `dart:io` `exit`, because that could terminate tests or tooling.

## Learning checkpoint

Define and test:

1. Normal `main` return.
2. Explicit zero and non-zero exit.
3. Code after exit is unreachable.
4. Constant and dynamic invalid exit values.
5. Non-zero WASI errno behavior.
6. Trap behavior remains distinct from guest exit.
7. Normal Dart VM rejection.

## Why we need to know this

PRD 5 requires a non-zero exit fixture and documented error behavior. Clear
semantics prevent expected guest termination from being confused with compiler,
WASI, engine, or platform failures.

## References

- [WASI Preview 1 `proc_exit`](https://github.com/WebAssembly/WASI/blob/main/legacy/preview1/docs.md#-proc_exitrcode-exitcode)
- [Dart `Never`](https://dart.dev/null-safety/understanding-null-safety#never-for-unreachable-code)
