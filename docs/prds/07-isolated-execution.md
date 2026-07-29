# PRD 07 — Isolated Request Execution

## Status

Proposed

## Depends on

PRD 06

## Goal

Run one request with fresh instance and WASI state and return a structured
platform result.

## Requirements

- New WASI context and instance for each request by default.
- Request-specific stdin, arguments, environment, stdout, and stderr.
- Structured response, exit, timing, and failure result.
- Cancellation and wall-clock timeout at the host boundary.
- No ambient host environment or filesystem access.

## Acceptance criteria

- Concurrent requests cannot observe each other's mutable state.
- Guest exit and guest trap remain distinct.
- Execution is testable with a fake engine.
