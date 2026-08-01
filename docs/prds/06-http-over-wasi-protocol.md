# PRD 06 — HTTP-over-WASI Guest Protocol

## Status

Implemented

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

## Implementation record

- `dart_wasi` exposes `WasiHttpRequest`, `WasiHttpResponse`, and the exact
  `WasiHttpResponse fetch(WasiHttpRequest request)` entrypoint contract.
- Requests expose method, path, query, body, header count, and indexed header
  name/value access. Text remains opaque UTF-8 `WasiBytes` in the guest subset.
- Responses use JSON, text, or binary factories. Each response carries one
  compiler-owned `content-type` header and an exact binary body.
- Version 1 `DWHP` envelopes use bounded little-endian fields over stdin and
  stdout. stderr is captured independently for diagnostics.
- The generated `_start` adapter reads and validates the request, invokes
  `fetch`, serializes the response, and exits. A malformed request uses the
  stable guest runtime status `70`.
- The host package owns immutable request/response models, the codec, stable
  protocol/execution errors, and `CompiledModule.runHttp`.
- Limits are 16 KiB per envelope, 12 KiB per body, 64 headers, 16-byte methods,
  4 KiB paths and queries, 128-byte header names, and 4 KiB header values.
- `http_json.dart` and `http_echo.dart` prove JSON/text and binary behavior
  through `wasd`; CI also runs the JSON worker with the independent Wasmtime
  CLI.
