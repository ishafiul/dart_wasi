# 15 — WebAssembly Linear Memory

Linear memory is a large list of bytes owned by a WebAssembly instance.

```text
address: 0  1  2  3  4  5 ...
byte:   72 101 108 108 111 0 ...
```

Those bytes could represent the text `Hello`, numbers, request data, or any
other guest data.

## Pages

Memory is measured in pages.

```text
1 WebAssembly page = 64 KiB
```

A module can declare an initial size and an optional maximum.

## Pointers

WASI functions receive numbers that point to locations in guest memory:

```text
pointer = 100
length  = 5
```

This means “read five bytes beginning at address 100.”

The host must check that the whole range is inside memory. Invalid memory access
causes a trap or WASI error.

## Growing memory

`memory.grow` asks for more pages. It can fail when the declared maximum or a
host limit would be exceeded.

## Data sections

Data sections place initial bytes into memory when an instance is created.
They are commonly used for constants such as strings.

## Why instance reuse is dangerous

Memory is mutable. One request can leave data behind for the next request.
Fresh instances are therefore the safe default for request isolation.

## Why we need to know this

`wasd` manages memory. Our platform needs this model for isolation, memory
policy, security decisions, and interpreting WASI pointers.

## References

- [WebAssembly memory](https://webassembly.github.io/spec/core/syntax/modules.html#memories)
- [Memory instructions](https://webassembly.github.io/spec/core/syntax/instructions.html#memory-instructions)
