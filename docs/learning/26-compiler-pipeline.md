# 26 — A Small Compiler Pipeline

Our first compiler can be understood as a sequence:

```text
Dart source
→ frontend representation
→ supported-subset validation
→ simple typed internal model
→ Wasm instructions and sections
→ worker.wasm
```

## Supported-subset validation

The compiler must explicitly accept or reject each language feature. A clear
error is better than generating incorrect code.

The first subset may include:

- `void main()`.
- Integers and booleans.
- Local variables.
- Direct calls.
- Simple `if` and loops.
- Constant strings.
- Known `dart_wasi` intrinsics.

## Lowering

Lowering turns a high-level operation into simpler target operations.

```text
Wasi.stdout.write("Hello")
→ place UTF-8 bytes in linear memory
→ create an iovec
→ call wasi_snapshot_preview1.fd_write
```

## Code generation

The backend creates Wasm types, imports, functions, memory, exports, code, and
data sections. The output must validate before execution.

## Why we need to know this

It divides the compiler into testable stages instead of one large source-to-byte
function.

## References

- [WebAssembly specification](https://webassembly.github.io/spec/core/)
