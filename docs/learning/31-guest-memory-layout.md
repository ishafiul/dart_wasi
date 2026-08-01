# 31 — Guest Memory Layout and Allocation

Once the guest can receive runtime bytes, it needs safe places to store them.
Linear memory is one large byte array, so the compiler must prevent different
uses from overlapping.

## Divide memory into regions

A simple first layout could look like this:

```text
low addresses
┌──────────────────────────────┐
│ WASI structs and result slots│
├──────────────────────────────┤
│ constant descriptors         │
├──────────────────────────────┤
│ constant UTF-8 data          │
├──────────────────────────────┤
│ dynamic descriptors          │
├──────────────────────────────┤
│ dynamic input bytes          │
├──────────────────────────────┤
│ unused capacity              │
└──────────────────────────────┘
high addresses
```

The exact addresses are less important than having one documented layout
calculated by the compiler instead of scattering magic offsets throughout code
generation.

## Alignment

WASI Preview 1 uses 32-bit pointers and lengths for these APIs. Keeping
descriptor fields aligned to four-byte boundaries makes loads and stores easy
to understand.

WebAssembly supports unaligned memory access, but consistent alignment reduces
mistakes.

## Fixed buffers versus allocation

A fixed input buffer is the simplest design:

```text
reserve 16 KiB
reject input that exceeds 16 KiB
```

It is easy to test but wastes space and imposes one hard limit.

A bump allocator keeps a pointer to the next unused address:

```text
allocate(size):
  result = next
  next = align(next + size)
  return result
```

It does not free individual values. That is acceptable when one fresh guest
instance handles one bounded command and all memory is discarded afterward.

PRD 5 does not need a general-purpose heap or garbage collector.

## Bounds and overflow

Before reserving a range, check the whole calculation:

```text
start >= 0
length >= 0
start + length does not overflow
start + length <= memory size
```

The same rule applies when multiplying counts by descriptor sizes. For
example, `argumentCount * 4` must be checked before allocating an argument
pointer array.

## Memory growth

The first SDK can choose either:

- One fixed Wasm page with strict input limits.
- Bounded `memory.grow` when more space is required.

If growth is allowed, the module must declare a maximum and handle a failed
growth operation. Host limits still take priority.

## Do not overwrite live data

A scratch area may be reused only after all values pointing into it are dead.
This program would be unsafe if the second read overwrote the first value:

```dart
final first = Wasi.stdin.readChunk();
final second = Wasi.stdin.readChunk();
Wasi.stdout.write(first);
```

The SDK can avoid this problem by copying each retained value or by exposing an
API whose lifetime rules make reuse explicit.

## Learning checkpoint

Create a memory-layout document or constants table that defines:

1. Reserved WASI scratch addresses.
2. Constant-data start and end.
3. Dynamic-allocation start.
4. Alignment rules.
5. Maximum stdin, argument, and environment sizes.
6. Growth and out-of-memory behavior.
7. When memory can be reclaimed.

## Why we need to know this

The current compiler uses fixed offsets for one output iovec and constant
strings. PRD 5 adds host-controlled data, so overlapping ranges or unchecked
sizes could corrupt guest memory or turn malformed input into traps.

## References

- [WebAssembly memory instructions](https://webassembly.github.io/spec/core/syntax/instructions.html#memory-instructions)
- [WASI Preview 1 specification](https://github.com/WebAssembly/WASI/blob/main/legacy/preview1/docs.md)
