# 28 — Wasm Code Generation and WASI Lowering

The compiler output is a normal core WebAssembly module.

For “Hello from Dart”, it needs:

```text
type section
import section for fd_write and proc_exit
function section
memory section
export section for _start and memory
code section
data section containing UTF-8 bytes
```

The generated `_start` function must:

```text
find the string bytes in memory
build the fd_write iovec
call fd_write for stdout
handle the WASI result
return or call proc_exit
```

## Testing layers

1. Compare generated section metadata with expectations.
2. Validate through `WasdEngine`.
3. Execute through `wasd`.
4. Validate or run in an independent WASI runtime when available.
5. Keep a golden fixture for deterministic output.

The compiler owns generation. The host must not special-case or repair malformed
compiler output.

## Why we need to know this

This is the final bridge from the supported Dart program to a genuine WASI
Preview 1 artifact.

## References

- [WebAssembly binary format](https://webassembly.github.io/spec/core/binary/index.html)
- [WASI Preview 1](https://github.com/WebAssembly/WASI/tree/main/legacy/preview1)
