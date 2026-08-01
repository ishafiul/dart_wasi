# 37 — HTTP-over-WASI Envelopes

A WASI Preview 1 command receives bytes on stdin and writes bytes to stdout.
It does not receive an HTTP request object directly. PRD 6 defines a small,
versioned binary envelope so the host and guest agree on what those bytes mean.

## Transport roles

The three standard descriptors have distinct jobs:

```text
stdin   -> one request envelope
stdout  <- one response envelope
stderr  <- guest diagnostics only
```

Keeping diagnostics away from stdout is important. A log line on stdout would
corrupt the response envelope, so the compiler rejects direct stdout and stdin
intrinsics in an HTTP worker.

## Common prefix

Every envelope begins with eight bytes:

| Offset | Size | Meaning |
|---|---:|---|
| 0 | 4 | ASCII magic `DWHP` |
| 4 | 1 | Protocol version, currently `1` |
| 5 | 1 | Kind: `1` request or `2` response |
| 6 | 2 | Reserved zero bytes |

All following integers are unsigned 32-bit little-endian values. Text fields
are UTF-8 and bodies are arbitrary bytes.

## Request envelope

After the prefix, a request stores lengths for method, path, query, header
count, and body. The payload then contains method, path, query, each header,
and the body in that order.

Each header is encoded as:

```text
name byte length | value byte length | name bytes | value bytes
```

The generated guest adapter validates every length before a handler can access
the request. Indexed header access cannot read outside the validated envelope.

## Response envelope

A response stores status, header count, and body length after the common
prefix, followed by headers and body. The current guest SDK factories emit one
`content-type` header. The host codec itself supports an ordered list of
headers, which leaves room for later SDK growth without changing version 1.

## Guest entrypoint

An HTTP guest replaces `void main()` with one exact handler:

```dart
WasiHttpResponse fetch(WasiHttpRequest request) {
  return WasiHttpResponse.json(200, '{"ok":true}');
}
```

The compiler generates `_start`. That adapter reads stdin, validates the
request version and bounds, passes a request handle to `fetch`, encodes its
response on stdout, and exits with zero. Malformed runtime data exits with
status 70.

## Bounded by construction

Version 1 allows at most:

- 16 KiB per request or response envelope.
- 12 KiB per body.
- 64 headers.
- 16 method bytes.
- 4 KiB each for path, query, and a header value.
- 128 bytes for a header name.

These are protocol limits, not promises of production-scale HTTP support.
Streaming, WebSockets, and sockets remain outside PRD 6.

## Why this matters

A version byte prevents a new decoder from silently misreading an old layout.
Bounds protect fixed guest memory from untrusted lengths. Separate host and
guest codecs make malformed data a stable protocol error instead of a range
exception or engine trap.

## Related

- [PRD 06 — HTTP-over-WASI Guest Protocol](../prds/06-http-over-wasi-protocol.md)
- [32 — WASI Descriptor I/O](32-wasi-descriptor-io.md)
- [31 — Guest Memory Layout](31-guest-memory-layout.md)
