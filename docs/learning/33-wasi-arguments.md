# 33 — WASI Arguments

The host can give a WASI command a sequence of arguments:

```text
["worker", "--mode", "fast"]
```

The guest retrieves them through two WASI Preview 1 calls:

```text
args_sizes_get
args_get
```

## First ask for the sizes

`args_sizes_get` writes two values into guest memory:

```text
argument count
total bytes required for argument strings
```

The total includes the terminating zero byte after every argument.

For the example above, the guest learns how much space it must reserve before
asking the host to copy anything.

## Then receive the arguments

`args_get` receives two guest pointers:

```text
argv pointer   → array of argument-string pointers
buffer pointer → storage for UTF-8 bytes and zero terminators
```

After the call, memory might look like:

```text
argv:
  [200, 207, 214]

buffer:
  200: "worker\0"
  207: "--mode\0"
  214: "fast\0"
```

The guest uses the pointer array to find each string. Runtime values should
record the byte length without the terminating zero.

## Safe loading sequence

1. Call `args_sizes_get`.
2. Check the count and total byte size against SDK limits.
3. Safely calculate `count * 4` for the pointer array.
4. Allocate the pointer array and byte buffer.
5. Call `args_get`.
6. Validate that every pointer and terminating zero is inside the buffer.
7. Build restricted runtime text or byte views.

Even though the host is trusted in the proof of concept, keeping these checks
explicit makes the generated runtime easier to reason about.

## Small SDK surface

The first API can expose operations such as:

```text
argument count
argument at an index
```

This does not require implementing general Dart list behavior. Indexes outside
the valid range need a documented failure policy.

The guest must not assume that the first argument has a particular value. WASI
delivers the argument sequence configured by the host.

## Encoding and limits

The SDK must define:

- UTF-8 decoding behavior.
- Maximum argument count.
- Maximum bytes per argument.
- Maximum total argument bytes.
- Behavior for empty arguments.
- Behavior for an out-of-range index.

Host-side `WasiExecutionOptions.arguments` already provides the sequence. PRD 5
adds the guest/compiler side that can request and use it.

## Learning checkpoint

Test at least:

- No arguments.
- One empty argument.
- Several ASCII arguments.
- A UTF-8 argument.
- An out-of-range index.
- Count and total-byte limits.
- A fixture that writes a selected argument to stdout.

## Why we need to know this

Arguments are not imported as Dart objects. They arrive as a pointer array and
a byte buffer in linear memory, so the compiler must construct safe runtime
values from that layout.

## References

- [WASI Preview 1 `args_sizes_get`](https://github.com/WebAssembly/WASI/blob/main/legacy/preview1/docs.md#-args_sizes_get---resultsize-errno)
- [WASI Preview 1 `args_get`](https://github.com/WebAssembly/WASI/blob/main/legacy/preview1/docs.md#-args_get---result-errno)
