# PRD 14 — Fixtures, Compatibility, and Benchmarks

## Status

Proposed

## Depends on

PRD 13

## Goal

Provide honest evidence for the supported Dart subset and host behavior.

## Requirements

- Dart guest fixtures for output, input, control flow, HTTP, exits, and errors.
- Compatibility matrix for Dart SDK, compiler subset, generated Wasm features,
  `wasd`, and WASI Preview 1.
- Cold compile, cold request, warm request, throughput, and memory benchmarks.
- Independent validation of generated Wasm where possible.

## Acceptance criteria

- Every supported Dart feature has a fixture.
- Unsupported features fail explicitly.
- Benchmarks and fixture builds are reproducible.
