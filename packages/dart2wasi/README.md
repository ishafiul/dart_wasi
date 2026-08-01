# dart2wasi

Experimental compiler for turning a deliberately small Dart subset into a
standard WASI Preview 1 command module.

The supported language subset includes:

- `void`, `int`, `bool`, opaque `WasiBytes`, and the HTTP request/response
  handles.
- Typed locals and parameters.
- Direct declared-function calls.
- Integer arithmetic and comparisons.
- Boolean expressions with short-circuit `&&` and `||`.
- `if`/`else`, `while`, assignment, and `return`.
- Compile-time UTF-8 string literals for supported guest intrinsics.

`int` is a signed WebAssembly `i32`, `bool` uses `i32` values `0` and `1`, and
`WasiBytes` packs a guest pointer and byte length into an `i64`. Runtime string
operations outside the documented intrinsics remain unsupported.

The version 1 `dart_wasi` contract supports stdout, stderr, bounded stdin,
arguments, environment lookup, and exit. Generated modules import only the
WASI Preview 1 capabilities used by the source and record SDK version 1 in the
`dart_wasi.sdk` custom section.

HTTP workers declare
`WasiHttpResponse fetch(WasiHttpRequest request)` instead of `void main()`.
The compiler generates a bounded version 1 request decoder and response
encoder over WASI stdin/stdout. Direct stdin/stdout access is rejected for
these workers; stderr remains available for diagnostics.

Compile a guest with:

```shell
dart run dart2wasi path/to/guest.dart path/to/guest.wasm
```

This is not a general Dart compiler. It does not support `dart:io`, async,
classes, general strings or collections, arbitrary packages, garbage
collection, filesystem access, sockets, or threads.
