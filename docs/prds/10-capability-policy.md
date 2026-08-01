# PRD 10 — Capability Policy and Bounded Execution

## Status

Implemented

## Depends on

PRD 09

## Goal

Run untrusted Workers with explicit capabilities and enforceable budgets.

## Requirements

- Deny filesystem, host environment, and network access by default.
- Bound input, output, concurrency, and wall time.
- Use only resource controls exposed publicly by `wasd`.
- Document limits that require a separate process boundary.
- Attach immutable policy to workload revisions.

## Acceptance criteria

- Disallowed capabilities remain unavailable.
- Enforced and best-effort limits are clearly distinguished.
- Timed-out capacity is quarantined or terminated safely.

## Implementation limits

Each immutable workload revision owns a `WasiCapabilityPolicy`. It denies
environment values by default and the runtime never provides filesystem
preopens, host files, or network capabilities. The host enforces input bytes,
retained stdout/stderr bytes, revision-level concurrency, and a request
deadline.

The deadline is a host-boundary limit: public `wasd` APIs do not provide
execution interruption, CPU metering, linear-memory limits, or a process kill
switch. A request that times out or is cancelled therefore remains counted
against revision capacity until its engine future settles. Strong CPU, memory,
and termination guarantees require a separate process boundary.
