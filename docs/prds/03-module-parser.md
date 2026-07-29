# PRD 03 — Workload Artifacts and Metadata

## Status

Implemented

## Validation notes

- Artifact IDs are lowercase SHA-256 digests of exact copied Wasm bytes.
- Registration enforces a configurable size limit before hashing or engine
  work, validates and compiles through `WasmEngine`, derives import/export
  metadata, records engine compatibility, and single-flights concurrent
  identical registrations.
- `WorkloadRepository` is the replaceable persistence boundary;
  `InMemoryWorkloadRepository` supplies deterministic proof-of-concept storage.
- Revisions are immutable and idempotent for the same artifact. Reusing a
  workload name and revision number for different content is rejected.
- Activation and rollback update only the active revision pointer and preserve
  immutable revision history.

## Depends on

PRD 02

## Goal

Represent immutable, versioned Wasm workloads independently of storage and
execution.

## Requirements

- Content-addressed artifact ID from the exact Wasm bytes.
- Logical workload name and immutable revision.
- Artifact size, creation time, engine compatibility, imports, and exports.
- Validation and metadata extraction through the engine adapter.
- In-memory artifact repository interface with replaceable persistence.
- Reject duplicate revisions with different content.

## Acceptance criteria

- Registering identical bytes is idempotent.
- Invalid modules are rejected before becoming active.
- Required imports and available exports are queryable without reimplementing a
  Wasm parser.
- A workload revision can be activated and rolled back.

## Non-goals

- Remote object storage.
- Package signing and provenance.
- Execution or scheduling.
