# 19 — Content-Addressed Artifacts

An artifact is the exact `.wasm` file uploaded to our platform.

Instead of giving it a random ID, we calculate an ID from its bytes.

```text
artifact ID = SHA-256(exact Wasm bytes)
```

## Simple example

Imagine:

```text
module A bytes → hash abc123
module A bytes → hash abc123
module B bytes → hash def456
```

Uploading the same bytes twice produces the same artifact ID. Changing even one
byte produces a different ID.

## Why this is useful

- Duplicate uploads become one artifact.
- Stored bytes can be checked for corruption.
- Cache entries can refer to exact content.
- Revisions can point to immutable artifacts.
- Rollback always returns to known bytes.

## Copy before storing

`Uint8List` is mutable. The repository must copy uploaded bytes.

Without a copy:

```text
1. hash bytes
2. caller changes bytes
3. stored content no longer matches its hash
```

## What does not belong in the hash?

Do not include:

- Workload name.
- Creation time.
- Active revision.
- Engine version.

Those values can change without changing the artifact itself.

## Why we need to know this

PRD 3 uses content hashes for immutable identity and idempotent registration.

## References

- [Content-addressable storage](https://en.wikipedia.org/wiki/Content-addressable_storage)
- [SHA-2](https://csrc.nist.gov/projects/hash-functions)
