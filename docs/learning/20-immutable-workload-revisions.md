# 20 — Immutable Workload Revisions

An artifact and a workload are not the same thing.

- Artifact: exact Wasm bytes.
- Workload: logical service, such as `image-resizer`.
- Revision: one version of that workload.

```text
workload: image-resizer
revision 1 → artifact abc123
revision 2 → artifact def456
active     → revision 2
```

## Why revisions should not change

Suppose revision 2 changes after deployment. We would no longer know:

- What code handled an old request.
- What “roll back to revision 2” means.
- Which logs and metrics belong to which code.

Instead, every change creates a new revision.

## Activation

Activation changes which revision receives new requests:

```text
before: active → revision 1
after:  active → revision 2
```

The artifact and revision records do not change.

## Rollback

Rollback moves the active pointer to an older revision:

```text
active → revision 1
```

Because revisions are immutable, the old code and configuration are still
known.

## In-flight requests

A request already using revision 1 may finish while new requests use revision
2. We should not delete the old revision immediately.

## Why we need to know this

PRD 3 introduces revision creation, activation, and rollback. Later PRDs use
revisions for routing, caching, policy, draining, and metrics.

## References

- [Immutable infrastructure](https://martinfowler.com/bliki/ImmutableServer.html)
- [Deployment concepts](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
