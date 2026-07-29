# PRD 15 — Optional Kubernetes Deployment PoC

## Status

Optional; start only after PRD 14

## Depends on

PRD 14

## Goal

Run the Dart host as a containerized Kubernetes workload and demonstrate
deployment of Dart-authored Workers.

## Requirements

- Container image for the compiled Dart host.
- Ingress, Service, Deployment, health checks, and autoscaling configuration.
- Replaceable object storage and metadata persistence.
- Upload, activate, route, roll back, drain, and deactivate flow.

## Acceptance criteria

- Dart source compiles to a WASI artifact and is deployed to the cluster.
- An HTTP request executes the Worker and returns its response.
- Deactivation drains traffic and returns workload instances to zero.

## Non-goals

- Production multi-tenancy, billing, global edge routing, or security
  certification.
