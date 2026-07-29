# PRD 06 — HTTP-over-WASI Guest Protocol

## Status

Proposed

## Depends on

PRD 05

## Goal

Define a versioned request/response protocol and expose a small Dart
`fetch(request)`-style guest API over it.

## Requirements

- Request and response envelopes for method, path, query, headers, status, and
  body.
- Binary-body representation and size limits.
- Stdin/stdout transport with stderr reserved for diagnostics.
- Dart guest SDK request, response, and `fetch` entry-point types.
- Generated `_start` adapter that decodes, invokes, encodes, and exits.

## Acceptance criteria

- A Worker written in the supported Dart subset returns a JSON HTTP response.
- Text and binary bodies round-trip.
- Malformed or unsupported protocol versions fail clearly.

## Non-goals

- Streaming, WebSockets, or direct socket listening.
