# 22 — Metadata and Compatibility

Metadata is information describing an artifact.

For a Wasm artifact, useful metadata includes:

```text
artifact ID
byte size
creation time
imports
exports
```

## Derive metadata from the bytes

Do not trust an uploader who says:

```text
"This module imports nothing."
```

Our engine adapter must inspect the validated module and produce the real import
and export metadata.

## Valid does not mean compatible

A module may be valid WebAssembly but still unusable by our platform.

Examples:

- It requires an import we do not provide.
- It targets a different WASI version.
- It has no `_start` export.
- It requires a disabled capability.
- It uses an unsupported engine feature.

Validation asks:

> Is this valid WebAssembly?

Compatibility asks:

> Can our platform safely run it as this kind of workload?

## Engine versions and caches

The artifact ID depends only on Wasm bytes. A compiled cache entry also depends
on the engine:

```text
cache key =
  artifact ID
  + engine name
  + resolved engine version
```

An engine upgrade may require recompilation even though the artifact ID stays
the same.

## Why we need to know this

PRD 3 stores reliable metadata. Later activation logic uses it to decide whether
the platform can run a revision.

## References

- [Semantic Versioning](https://semver.org/)
- [WebAssembly feature extensions](https://webassembly.org/features/)
