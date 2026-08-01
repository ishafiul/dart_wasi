# 34 — WASI Environment Variables

The host can provide key/value configuration to a WASI command:

```text
MODE=production
LOG_LEVEL=debug
```

The guest retrieves it through:

```text
environ_sizes_get
environ_get
```

The layout is similar to WASI arguments.

## Size query and copy

`environ_sizes_get` reports:

```text
environment entry count
total bytes required for all entries
```

`environ_get` then fills:

```text
an array of pointers
a byte buffer containing null-terminated KEY=value entries
```

For example:

```text
environ pointers:
  [300, 316]

buffer:
  300: "MODE=production\0"
  316: "LOG_LEVEL=debug\0"
```

## Parsing an entry

Split an entry at its first `=` byte:

```text
NAME=value=with=equals
```

becomes:

```text
name  = NAME
value = value=with=equals
```

The parser should define what happens when an entry contains no `=` or has an
empty name.

## Lookup without a general Map

The SDK does not need to expose a normal Dart `Map<String, String>`. A smaller
surface could provide:

```text
contains a name
read a value by name
```

The missing-value behavior must be unambiguous. Possibilities include:

- A nullable result, if the supported subset includes nullability.
- Separate `contains` and `value` operations.
- A required lookup that produces a documented guest failure.

The first version should choose one behavior instead of treating missing and
empty values as the same thing.

## Duplicate names

The current Dart host accepts a map, so it cannot supply duplicate keys through
that API. The guest representation should still define a deterministic rule if
another WASI host supplies duplicates, such as rejecting them or choosing the
first entry.

## Configuration is untrusted input

Environment names and values come from outside the guest. Apply limits before
allocation and do not log values automatically because they may contain
sensitive information.

The SDK should define:

- Maximum entry count.
- Maximum name and value sizes.
- Maximum total bytes.
- UTF-8 policy.
- Missing and malformed entry behavior.
- Duplicate-name behavior.

## Safe loading sequence

1. Call `environ_sizes_get`.
2. Check count and total bytes.
3. Allocate the pointer array and byte buffer.
4. Call `environ_get`.
5. Validate pointers and zero terminators.
6. Split each entry at the first `=`.
7. Perform bounded lookup without unnecessary copies.

## Learning checkpoint

Test at least:

- Empty environment.
- Present and missing keys.
- Empty values.
- Values containing `=`.
- UTF-8 names or values according to the selected policy.
- Oversized and malformed entries.
- A fixture that writes one environment value to stdout.

## Why we need to know this

Environment values use a low-level memory representation, not a Dart map.
Understanding that representation lets the SDK provide a deliberately small
and honest configuration API.

## References

- [WASI Preview 1 `environ_sizes_get`](https://github.com/WebAssembly/WASI/blob/main/legacy/preview1/docs.md#-environ_sizes_get---resultsize-errno)
- [WASI Preview 1 `environ_get`](https://github.com/WebAssembly/WASI/blob/main/legacy/preview1/docs.md#-environ_get---result-errno)
