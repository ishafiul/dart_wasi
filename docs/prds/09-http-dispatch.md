# PRD 09 — HTTP Server and Workload Dispatch

## Status

In progress

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
