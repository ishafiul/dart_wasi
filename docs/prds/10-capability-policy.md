# PRD 10 — Capability Policy and Bounded Execution

## Status

In progress

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
