# PRD 11 — Observability and Failure Classification

## Status

Proposed

## Depends on

PRD 10

## Goal

Make compilation, activation, execution, and guest behavior diagnosable.

## Requirements

- Correlation IDs and structured lifecycle events.
- Compile, instantiate, execute, cache, queue, and failure metrics.
- Stable platform failure taxonomy.
- Bounded and redacted guest logs.

## Acceptance criteria

- One request has correlated timings from route to response.
- Metrics separate compiler, host, engine, protocol, and guest failures.
