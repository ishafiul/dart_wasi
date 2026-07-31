# Implemented Proposal: Request-Scoped WASI Output Sinks

> Status: implemented on the `wasi-output-sinks` branch consumed by this
> workspace. This document records the original contribution requirements.

I would like to contribute an optional, request-scoped stdout/stderr capture API
to `wasd`'s public WASI Preview 1 interface.

## Problem

`wasd` currently implements `wasi_snapshot_preview1.fd_write` by writing guest
bytes directly to host-process stdout/stderr. That works for command-line use,
but a Dart host embedding `wasd` cannot reliably capture a WASI guest's stdout
or stderr through the public API.

This blocks common embedding use cases:

- Running a WASI guest as an HTTP handler.
- Returning guest-generated JSON or text as an HTTP response.
- Separating stdout response data from stderr diagnostics.
- Enforcing a host-defined output-size limit.
- Recording structured guest logs or telemetry.
- Safely running multiple guests with independent output buffers.

For example, when a guest calls `fd_write` for stdout, an embedding host needs
those bytes as data, not only as terminal output.

## Goal

Add an optional public output-sink API to WASI so an embedding host can receive
raw bytes written to guest stdout and stderr.

## Desired Usage

```dart
final stdout = BytesBuilder();
final stderr = BytesBuilder();

final wasi = WASI(
  stdoutSink: stdout.add,
  stderrSink: stderr.add,
);

final instance = await WebAssembly.instantiateModule(module, wasi.imports);
final exitCode = wasi.start(instance);

final response = utf8.decode(stdout.toBytes());
final diagnostics = utf8.decode(stderr.toBytes());
```

The exact API naming and types are open to maintainers' preference.

## Requirements

1. Preserve existing behavior by default.

   If no sink is supplied, guest stdout and stderr must continue to go to host
   stdout and stderr as they do today.

2. Use byte-oriented output.

   WASI `fd_write` writes bytes, not necessarily UTF-8 text. The callback or
   sink should receive `List<int>` or `Uint8List`, not decoded strings.

3. Keep stdout and stderr independent.

   The host must be able to capture them separately.

4. Keep the write path synchronous.

   `fd_write` is synchronous. The sink should be synchronous too, for example:

   ```dart
   typedef WASIOutputSink = void Function(List<int> bytes);
   ```

   It should not make `fd_write` wait for asynchronous callbacks.

5. Avoid global I/O interception.

   Capture must belong to one `WASI` instance. It should not require
   `IOOverrides`, replacing process-global stdout, or a subprocess.

6. Support concurrent embeddings.

   Separate `WASI` instances must retain separate output sinks so concurrent
   guest executions cannot mix output.

7. Apply consistently across supported platforms.

   The public `WASI` factory and native/JavaScript implementations should
   expose equivalent behavior where possible.

8. Leave buffering policy to the host.

   `wasd` should forward chunks. The embedding host decides whether to buffer,
   stream, truncate, reject oversized output, or forward elsewhere.

## Likely Implementation Direction

Where `fd_write` currently routes output directly to the process streams:

```dart
io.stdout.add(output);
```

or:

```dart
io.stderr.add(output);
```

route through optional instance-level sinks first:

```dart
if (stdioKind == stdout) {
  final sink = _stdoutSink;
  if (sink != null) {
    sink(output);
  } else {
    io.stdout.add(output);
  }
}
```

Apply the corresponding behavior for stderr.

## Tests to Include

- A stdout sink receives the exact bytes from `fd_write`.
- A stderr sink receives the exact bytes from `fd_write`.
- Stdout and stderr do not mix.
- Existing default behavior remains unchanged when no sink is supplied.
- Empty writes remain no-ops.
- Multiple WASI instances keep captured output isolated.
- Native and JavaScript/web behavior remains aligned where applicable.

## Why This Matters

This makes `wasd` more useful as an embeddable WASI runtime, not only a
command-runner. It enables request-scoped JSON/text responses, structured
logging, observability, test assertions, and bounded output handling without
changing guest modules or relying on private `wasd` internals.
