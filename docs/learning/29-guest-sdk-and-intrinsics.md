# 29 — Guest SDK and Compiler Intrinsics

The `dart_wasi` package looks like a normal Dart library, but its operations
have special meaning to `dart2wasi`.

For example:

```dart
Wasi.stdout.write('Hello');
```

is not executed by the Dart VM. The compiler recognizes the call and replaces
it with WebAssembly instructions that eventually call WASI Preview 1
`fd_write`.

This kind of compiler-recognized operation is called an **intrinsic**.

## The three sides of the contract

Every guest operation must agree across three layers:

```text
Dart source API
→ dart2wasi recognition and lowering
→ WASI import supplied by the host
```

If one layer disagrees with the others, a program may compile but fail when it
runs. The SDK and compiler therefore need one explicit, versioned contract.

## Keep the API honest

The first SDK must expose only behavior the compiler actually supports.

For example, returning a normal `List<String>` from `Wasi.arguments` would
suggest support for ordinary Dart lists and strings. That would be misleading
unless the compiler also implements the relevant list and string behavior.

A smaller API can expose only the required operations:

```text
argument count
argument at an index
environment lookup
read stdin
write stdout or stderr
exit
```

The exact Dart types must be chosen after defining the runtime text and byte
representation in step 30.

## Versioning

The SDK already exposes a guest API version. The compiler must also know which
version it accepts.

Version checking should answer:

- Which intrinsic names exist in this version?
- What parameter and result types does each intrinsic use?
- What happens when source expects a newer SDK?
- Can a generated artifact record the contract version for diagnostics?

An unsupported version should produce a clear compile-time diagnostic instead
of silently generating incompatible Wasm.

## Normal Dart VM behavior

Compiler-only operations must fail clearly when run normally:

```dart
void write(String text) {
  throw UnsupportedError(
    'This operation is available only in a dart2wasi-compiled guest.',
  );
}
```

This prevents a test on the Dart VM from appearing to exercise behavior that
only exists after compilation.

Pure helper code may still run normally, but the boundary between portable
Dart and compiler-only guest behavior must be documented.

## Compiler validation

The compiler should recognize an intrinsic by its resolved SDK identity, API
version, receiver, method, and types—not merely because the source contains a
matching sequence of words.

The current restricted parser cannot resolve Dart libraries like a full Dart
frontend. For the proof of concept, it should still validate as much of the
contract as possible and reject unsupported forms consistently.

Important invalid cases include:

- Missing or unsupported arguments.
- Using a result as the wrong type.
- Calling through `dynamic` or a tear-off.
- Importing an unsupported API version.
- Calling an SDK method the compiler does not lower.

## Learning checkpoint

Before implementing the remaining SDK operations, write down:

1. The complete version 1 API surface.
2. The parameter and result type of every operation.
3. Which operations never return.
4. Which failures are compile errors, guest errors, or WASI errors.
5. How every operation behaves on the normal Dart VM.

## Why we need to know this

PRD 5 is a contract between user code, the experimental compiler, and the WASI
host. Making that contract explicit prevents the SDK from promising ordinary
Dart behavior that the generated guest cannot provide.

## References

- [PRD 05 — Minimal Dart WASI Guest SDK](../prds/05-dart-wasi-guest-sdk.md)
- [Dart libraries and imports](https://dart.dev/language/libraries)
