# wasi_runtime

Experimental Dart host package for validating, registering, versioning, and
running standard WASI modules through `wasd`.

This package does not compile Dart source to WASI. That research belongs to the
neighboring `dart2wasi` package.

The package also owns the version 1 HTTP-over-WASI host contract:

- Immutable request, response, and ordered header models.
- A bounded `DWHP` binary envelope codec.
- Stable protocol and guest-execution failures.
- `CompiledModule.runHttp` for request-scoped execution with captured stderr.

For generic command modules, `WasiRequestExecutor` creates a fresh WASI
context for every `WasiRequest`, accepts only request-scoped stdin, arguments,
and environment values, and returns a structured result for normal exit,
traps, cancellation, and wall-clock timeout. Timeout and cancellation return at
the host boundary; they cannot preempt an already-running in-process engine.

`CompiledModuleCache` reuses immutable compiled modules by artifact ID and
resolved engine compatibility, with concurrent single-flight compilation and
entry, byte, and idle-eviction budgets. `WorkloadExecutor` snapshots the active
revision before execution and exposes `drain` so a newly activated or rolled
back revision can take traffic while requests on the previous revision finish.
Every execution still delegates to `WasiRequestExecutor`, so no request-scoped
WASI state is shared through the cache.
