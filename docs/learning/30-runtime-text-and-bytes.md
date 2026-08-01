# 30 — Runtime Text and Byte Values

PRD 4 can write a constant string because the compiler knows its bytes before
the program starts:

```dart
Wasi.stdout.write('Hello');
```

The compiler places `Hello` directly in the Wasm data section.

PRD 5 introduces text that is not known at compile time:

```text
stdin supplied by the host
arguments supplied by the host
environment values supplied by the host
```

The guest needs a runtime representation for these values.

## Bytes first, text second

WASI reads and writes bytes. It does not know about Dart strings.

```text
host bytes → guest linear memory → optional UTF-8 decoding → guest value
```

Keeping a byte-oriented boundary is useful because stdin and output are not
guaranteed to contain valid UTF-8. A text API must state what happens when
decoding fails.

Possible policies include:

- Reject invalid UTF-8.
- Replace invalid byte sequences.
- Expose raw bytes and let the guest opt into text decoding.

The first SDK should choose one policy explicitly.

## Pointer and length

A minimal runtime value can be represented by two 32-bit numbers:

```text
pointer → first byte in linear memory
length  → number of bytes
```

For example:

```text
descriptor at 100:
  bytes 100..103 = data pointer 200
  bytes 104..107 = byte length 5

data at 200:
  72 101 108 108 111 = "Hello"
```

The compiler could pass the pair directly, pack it into a wider value, or pass
a pointer to the descriptor. The first implementation should use one
representation consistently.

## Restricted string behavior

Using the Dart type name `String` does not require implementing every Dart
string operation. The compiler may initially allow a runtime string only to:

- Receive it from a supported intrinsic.
- Store it in a local variable.
- Pass it to a supported function.
- Write it to stdout or stderr.

Concatenation, interpolation of runtime values, indexing, regular expressions,
and arbitrary `String` methods can remain unsupported.

An alternative is an explicit compiler-only type such as `WasiText` or
`WasiBytes`. That avoids implying full `String` compatibility but makes guest
code less familiar. PRD 5 should record which tradeoff it chooses.

## Ownership and lifetime

Every runtime value needs an owner and a lifetime.

Questions to answer include:

- Can the host change the bytes after `fd_read` returns?
- Can two guest values point to the same bytes?
- Can a later read overwrite an earlier value?
- Does a value remain valid until `_start` finishes?
- Are returned values immutable?

For a one-command-per-instance proof of concept, a simple rule is:

```text
The guest owns copied bytes until that guest execution finishes.
```

This avoids dangling pointers and cross-request sharing.

## Empty values

An empty value still needs a valid representation. Common choices are:

```text
pointer = 0, length = 0
```

or a pointer to a shared empty buffer. Code must never read from the pointer
when the length is zero.

## Learning checkpoint

Define and test:

1. The runtime descriptor layout.
2. Whether public APIs expose bytes, text, or both.
3. The UTF-8 error policy.
4. Which operations are supported on runtime values.
5. Ownership, mutability, and lifetime.
6. The representation of empty values.

## Why we need to know this

Echo, arguments, and environment fixtures cannot work with compile-time string
constants alone. Runtime text and byte values are the bridge between WASI
memory and the supported Dart subset.

## References

- [WebAssembly linear memory](https://webassembly.github.io/spec/core/syntax/modules.html#memories)
- [UTF-8](https://www.rfc-editor.org/rfc/rfc3629)
