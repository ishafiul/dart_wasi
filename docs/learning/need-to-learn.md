# What We Still Need to Learn

This project uses `wasd` as its WebAssembly and WASI engine. The topics below
remain important for debugging, security decisions, protocol design, capacity
planning, and evaluating upstream behavior. They are not a plan to reimplement
the engine.

## Dart binary data

- `Uint8List`, `ByteBuffer`, `ByteData`, views versus copies, and mutation.
- Bytes, hexadecimal notation, bit masks, shifts, and signed versus unsigned
  interpretation.
- Cursor-based reads, atomic bounds checks, offsets, and typed malformed-input
  errors.
- Little-endian integers.
- Unsigned and signed LEB128, width limits, overflow, and sign extension.
- Length-prefixed vectors and strict UTF-8 WebAssembly names.

## WebAssembly binary format

- Magic bytes, version 1, section IDs, section lengths, and custom sections.
- Type, import, function, table, memory, global, export, start, element, code,
  and data sections.
- Index spaces and why function declarations must align with code bodies.
- Validation versus decoding versus instantiation.
- Feature detection and explicit rejection of unsupported proposals.

## WebAssembly execution model

- Typed values, operand stack, locals, call frames, and traps.
- Structured control flow: blocks, loops, labels, branches, and stack
  unwinding.
- Direct and indirect calls.
- Linear memory pages, bounds, growth, data segments, unaligned access, and
  little-endian loads/stores.
- Imports, exports, start functions, instance-local globals, tables, and
  memory.
- Difference between a compiled module and mutable instance state.

## WASI Preview 1

- `wasi_snapshot_preview1` command modules and the `_start` convention.
- stdin/stdout/stderr descriptors and scatter/gather I/O vectors.
- Arguments and environment memory layouts.
- Exit codes and `proc_exit` without terminating the Dart host.
- Clocks, randomness, preopened directories, capabilities, and errno values.
- Why every execution needs isolated WASI state.
- Differences among Preview 1, Preview 2, Preview 3, and the Component Model.

## `wasd` integration

- Public entry points from `package:wasd/wasd.dart`.
- `WebAssembly.validate`, `compile`, and `instantiate`.
- `Module.imports` and `Module.exports`.
- Import maps and exported-function wrappers.
- Constructing `WASI`, passing its imports, and calling `wasi.start(instance)`.
- Capturing or redirecting WASI input, output, environment, and filesystem
  capabilities using public APIs.
- Publicly available cancellation, memory, and execution-limit controls.
- Exception and trap behavior that the platform adapter must normalize.
- Compatibility changes across pinned `wasd` versions.
- Why `package:wasd/src` must never become an integration dependency.

## Isolation and security

- In-process interpreter isolation versus operating-system process isolation.
- Capability allowlists and deny-by-default host access.
- Timeouts that stop waiting versus cancellation that actually stops work.
- Infinite loops, recursion, memory growth, output amplification, and queue
  exhaustion.
- Limits enforceable by the platform, limits enforceable by `wasd`, and limits
  that require a process boundary.
- Handling compromised, malformed, or adversarial guest modules.

## Workload protocol

- HTTP semantics that must survive a JSON/stdin/stdout boundary.
- Binary body encoding, duplicate headers, hop-by-hop headers, and size limits.
- Versioned envelopes and forward compatibility.
- Guest stderr, exit codes, malformed output, and partial writes.
- Streaming limitations of the initial command-per-request design.

## Caching and lifecycle

- Content addressing, immutable revisions, and engine-version cache keys.
- Single-flight compilation and cache eviction.
- Compiled-module reuse versus instance reuse.
- State leakage risks in pooled instances.
- Cold starts, warming, draining, backpressure, and scale-to-zero.
- Safe revision rollout and rollback with in-flight requests.

## Observability and benchmarking

- Separating validation, compile, instantiate, execute, and protocol timings.
- Cold versus warm latency and tail percentiles.
- Per-workload concurrency, queues, cache hits, failures, and memory.
- Stable platform failure categories over engine-specific exceptions.
- Redaction and bounded guest logs.
- Genuine C/Rust WASI fixtures and reproducible benchmark methodology.

## Dart guest code

- Official Dart Wasm output targets WasmGC/browser environments rather than
  standard WASI command modules.
- Dart-authored guest workloads require a separate Dart-to-WASI toolchain or
  runtime effort.
- Native Dart callbacks are host functions, not sandboxed Wasm guest code.

## Step-by-step learning sequence

Read the numbered notes in order. Each step assumes the concepts introduced by
the earlier steps.

### Binary foundation

1. [`01-uint8list.md`](01-uint8list.md) — byte storage, buffers, copies, and
   views.
2. [`02-bytes-and-hexadecimal.md`](02-bytes-and-hexadecimal.md) — binary and
   hexadecimal notation.
3. [`03-cursor-based-reading.md`](03-cursor-based-reading.md) — sequential
   binary reads.
4. [`04-bounds-checking.md`](04-bounds-checking.md) — safe malformed-input
   handling.
5. [`05-little-endian.md`](05-little-endian.md) — byte order.
6. [`06-bitwise-operations.md`](06-bitwise-operations.md) — masks and shifts.
7. [`07-unsigned-leb128.md`](07-unsigned-leb128.md) — variable-width unsigned
   integers.
8. [`08-signed-leb128.md`](08-signed-leb128.md) — signed values and sign
   extension.
9. [`09-utf8-names.md`](09-utf8-names.md) — length-prefixed Wasm names.
10. [`10-wasm-header-and-sections.md`](10-wasm-header-and-sections.md) — module
    preamble and section envelopes.

### Runtime concepts required to understand PRD 2

11. [`11-module-sections.md`](11-module-sections.md) — typed section roles and
    index relationships.
12. [`12-imports-and-exports.md`](12-imports-and-exports.md) — host
    requirements and guest entry points.
13. [`13-validation-compilation-instantiation.md`](13-validation-compilation-instantiation.md)
    — the three distinct engine stages.
14. [`14-execution-model.md`](14-execution-model.md) — stack execution,
    structured control flow, and traps.
15. [`15-linear-memory.md`](15-linear-memory.md) — pages, pointers, growth, and
    instance state.
16. [`16-wasi-preview1.md`](16-wasi-preview1.md) — command modules, `_start`,
    descriptors, and capabilities.
17. [`17-wasd-public-api.md`](17-wasd-public-api.md) — the selected engine's
    supported public integration surface.
18. [`18-engine-adapters-and-errors.md`](18-engine-adapters-and-errors.md) —
    dependency isolation and stable failure categories.

### Artifact concepts required for PRD 3

19. [`19-content-addressed-artifacts.md`](19-content-addressed-artifacts.md) —
    immutable identity derived from bytes.
20. [`20-immutable-workload-revisions.md`](20-immutable-workload-revisions.md)
    — logical workloads, activation, and rollback.
21. [`21-repositories-and-concurrency.md`](21-repositories-and-concurrency.md)
    — storage boundaries, atomic updates, and races.
22. [`22-metadata-and-compatibility.md`](22-metadata-and-compatibility.md) —
    engine-derived facts and compatibility decisions.
23. [`23-artifact-security-and-testing.md`](23-artifact-security-and-testing.md)
    — untrusted input, integrity, and PRD 3 verification.

### Compiler concepts required for PRD 4

24. [`24-dart-wasm-targets.md`](24-dart-wasm-targets.md) — why official Dart
    Wasm output is not a WASI Preview 1 command module.
25. [`25-dart-kernel-ir.md`](25-dart-kernel-ir.md) — a possible reusable Dart
    frontend representation.
26. [`26-compiler-pipeline.md`](26-compiler-pipeline.md) — subset validation,
    lowering, and code-generation stages.
27. [`27-minimal-dart-runtime.md`](27-minimal-dart-runtime.md) — runtime support
    required by accepted Dart features.
28. [`28-wasm-codegen-and-wasi-lowering.md`](28-wasm-codegen-and-wasi-lowering.md)
    — generating core Wasm and lowering guest operations to WASI calls.

Later learning notes should continue at step 29. Do not insert a later PRD topic
before its prerequisites merely because its implementation is scheduled next.
