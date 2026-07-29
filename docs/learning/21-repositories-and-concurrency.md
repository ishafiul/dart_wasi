# 21 — Repository and Concurrency Design

A repository is an interface for saving and finding domain objects.

```dart
abstract interface class WorkloadRepository {
  Future<WorkloadArtifact?> findArtifact(String id);
  Future<WorkloadArtifact> registerArtifact(Uint8List bytes);
  Future<void> activate(String workload, int revision);
}
```

The first implementation can keep records in memory. Later, the same interface
can use a database or object store.

## Why not expose a database directly?

The repository protects rules such as:

- Artifacts are immutable.
- Identical content is registered once.
- Only existing revisions can be activated.
- Activation changes atomically.

These are product rules, not database details.

## Concurrent registration

Two requests might upload the same bytes at the same time:

```text
request A ─┐
           ├→ same artifact
request B ─┘
```

Both should receive the same result. We should not create duplicates or perform
the same expensive work twice.

## Concurrent activation

Two users might activate different revisions at the same time.

We need a clear rule, such as:

- Process updates one at a time.
- Require the caller to provide the expected current revision.
- Use a storage transaction.

## Partial failure

Activation must never point to:

- Missing bytes.
- An invalid module.
- A revision that was only partly saved.

Failed operations should leave the previous valid state unchanged.

## Why we need to know this

PRD 3 needs predictable in-memory behavior now and rules a future persistent
repository can preserve.

## References

- [Repository pattern](https://martinfowler.com/eaaCatalog/repository.html)
- [Optimistic concurrency control](https://en.wikipedia.org/wiki/Optimistic_concurrency_control)
