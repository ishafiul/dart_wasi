# dart_wasi

Experimental guest-facing APIs for Dart programs compiled by `dart2wasi`.

The version 1 API supports:

- Constant UTF-8 writes to stdout and stderr.
- Raw `WasiBytes` writes to stdout and stderr.
- Bounded stdin reads through EOF.
- Argument count and indexed argument access.
- Environment lookup with an explicit fallback.
- Exit statuses from 0 through 255.
- A versioned HTTP `fetch` entrypoint with request metadata and JSON, text, or
  binary responses.

`WasiBytes` is an opaque pointer-and-length value owned by one guest execution.
It may be stored, passed to supported functions, returned, and written. It does
not imply support for normal Dart `String`, `List`, or collection operations.

stdin is limited to 16 KiB. Arguments are limited to 64 entries and 8 KiB
total, and the environment to 64 entries and 16 KiB total; vector byte limits
include NUL terminators. WASI errno failures exit with the errno value. Invalid
indexes, limits, malformed host data, or invalid dynamic exit statuses use
`dartWasiGuestRuntimeErrorExitCode` (`70`).

All guest operations are compiler intrinsics. Calling them on the normal Dart
VM throws `UnsupportedError`.

An HTTP worker uses this exact entrypoint:

```dart
WasiHttpResponse fetch(WasiHttpRequest request) {
  return WasiHttpResponse.json(200, '{"ok":true}');
}
```

HTTP workers reserve stdin/stdout for version 1 protocol envelopes and use
stderr for diagnostics.
