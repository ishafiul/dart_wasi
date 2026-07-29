# 23 — Artifact Security and Testing

Every uploaded Wasm artifact must be treated as untrusted input.

It may be:

- Invalid.
- Very large.
- Designed to consume too many resources.
- Designed to trigger an engine bug.
- Different from the metadata supplied by the uploader.

## Safe registration order

A basic safe flow is:

```text
1. Check upload size
2. Copy the bytes
3. Calculate the hash
4. Validate through WasdEngine
5. Read metadata through WasdEngine
6. Save one complete artifact record
```

Rejecting size first avoids spending time hashing or compiling an upload that
is already too large.

## Names are not file paths

A workload name such as:

```text
../../important-file
```

must never be used directly as a filesystem path. If we later store artifacts
on disk, trusted code should build paths from controlled artifact IDs.

## Do not trust supplied metadata

The platform derives:

- Hash.
- Size.
- Imports.
- Exports.
- Compatibility facts.

A checksum supplied by the uploader can be checked, but it cannot replace our
own hash.

## Important tests

PRD 3 should prove:

- Same bytes produce the same artifact.
- Different bytes produce different artifacts.
- Changing the caller's byte list cannot change stored content.
- Invalid modules are not stored.
- Metadata matches the engine adapter.
- Concurrent identical uploads remain idempotent.
- Activation and rollback are atomic.
- Duplicate revision conflicts are predictable.
- Oversized input is rejected early.
- Repository rules can be tested with a fake engine.

## Validation is not a full sandbox

A valid module can still loop forever, grow memory, or print too much.
Execution limits and stronger isolation belong to later PRDs.

## References

- [OWASP file upload guidance](https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html)
- [NIST secure software development framework](https://csrc.nist.gov/Projects/ssdf)
