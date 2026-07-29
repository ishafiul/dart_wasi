# 27 — The Minimal Dart Guest Runtime

Dart language features normally rely on runtime behavior such as objects,
strings, allocation, type checks, exceptions, and garbage collection.

Our first WASI module cannot include the full Dart VM. It needs the smallest
runtime that supports the accepted subset.

## First milestone

For a constant string:

```dart
Wasi.stdout.write('Hello from Dart!\n');
```

the compiler can encode the UTF-8 bytes directly into a Wasm data segment. No
general Dart `String` object or garbage collector is required.

As the subset grows, the runtime may need:

- A linear-memory layout.
- Allocation.
- String and byte representations.
- Bounds checks.
- Function calling conventions.
- Error and exit behavior.

Every added Dart feature has a runtime cost. Features should be added only when
their representation and behavior are defined.

## Why we need to know this

Generating Wasm instructions is only part of compiling Dart. We must also
provide the runtime behavior those Dart instructions expect.

## References

- [Dart language overview](https://dart.dev/language)
- [WebAssembly linear memory](https://webassembly.github.io/spec/core/syntax/modules.html#memories)
