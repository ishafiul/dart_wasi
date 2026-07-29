# 16 — WASI Preview 1

WebAssembly itself can calculate values, but it has no built-in way to read
input, print output, access files, or exit a process.

WASI provides those host services.

## A command module

A WASI Preview 1 command module normally exports:

```text
_start
```

The host creates the module with WASI imports and calls `_start`.

## Standard input and output

WASI follows familiar file-descriptor conventions:

```text
0 → stdin
1 → stdout
2 → stderr
```

The guest passes memory pointers and lengths to WASI functions. The host moves
the bytes between guest memory and the outside world.

## Arguments and environment

WASI can provide:

```text
arguments:   ["worker", "--mode", "fast"]
environment: {"MODE": "production"}
```

The host writes these strings into guest memory when the guest requests them.

## Exiting

`proc_exit(42)` reports exit code 42. With `wasd` configured to return on exit,
this must return control to our platform instead of terminating the Dart host.

## Capabilities

WASI can expose clocks, randomness, files, directories, and sockets. The guest
does not automatically receive all host access. The host decides what to
provide.

## Why we need to know this

Our first workload model runs one WASI command per request. Each request needs
its own input, arguments, environment, capabilities, output, and exit result.

## References

- [WASI Preview 1 specification](https://github.com/WebAssembly/WASI/blob/main/legacy/preview1/docs.md)
- [WASI](https://wasi.dev/)
