# PRD 08 — Compilation Cache and Revision Lifecycle

## Status

In progress

## Depends on

PRD 07

## Goal

Reuse compiled modules without sharing request state.

## Requirements

- Key cache entries by artifact ID and resolved engine version.
- Single-flight concurrent compilation.
- Entry and memory budgets with idle eviction.
- Safe revision activation, rollback, and draining.
- Never share request-scoped WASI state.

## Acceptance criteria

- Repeated requests compile once.
- Concurrent cold requests share one compilation.
- Revision changes do not interrupt in-flight requests.
