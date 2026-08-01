# PRD 09 — HTTP Server and Workload Dispatch

## Status

Implemented

## Depends on

PRD 08

## Goal

Receive HTTP requests in the Dart host and route them to active Dart-authored
WASI Workers.

## Requirements

- Hostname/path route table.
- Request/response protocol conversion.
- Workload-level concurrency limits and backpressure.
- Platform failure-to-HTTP mapping.
- Concurrent isolated dispatch.

## Acceptance criteria

- A Dart HTTP server routes to a Dart-authored Wasm Worker.
- Missing routes, guest failures, invalid responses, and timeouts map to
  documented statuses.

## Implementation

- `WasiHttpDispatcher` routes case-insensitive hostnames and path prefixes to
  active workloads through `WorkloadExecutor`, retaining its request isolation.
- `WasiHttpServer` adapts the dispatcher to `dart:io`'s `HttpServer`.
- Per-workload, fail-fast concurrency limits return `503`; aliases for the
  same workload share the same limit.
- Missing routes return `404`; guest exits, traps, failures, and malformed
  worker responses return `502`; timeouts return `504`; and host-side request
  cancellation returns `499`.
