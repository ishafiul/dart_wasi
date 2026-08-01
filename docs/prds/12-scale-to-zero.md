# PRD 12 — Warm Capacity and Scale-to-Zero

## Status

In progress

## Depends on

PRD 11

## Goal

Keep frequently used workloads responsive and retire inactive workload
instances to zero.

## Requirements

- Inactive, compiling, warm, busy, draining, and failed states.
- Single-flight cold activation.
- Bounded queues, desired concurrency, and idle eviction.
- Safe revision draining.
- Deterministic scheduler clock.

## Acceptance criteria

- First demand activates once.
- Bursts expand within limits.
- Idle workloads return to zero instances.
- Old revisions drain without interrupting requests.
