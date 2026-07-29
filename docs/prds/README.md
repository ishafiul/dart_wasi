# Dart-authored WASI Proof-of-Concept PRDs

The primary goal is to prove that a supported subset of Dart can compile into a
standard WASI Preview 1 command module and run through a Dart host using `wasd`.

The repository contains three packages:

```text
dart2wasi   Dart source → WASI .wasm
dart_wasi   guest-facing Dart APIs
wasi_runtime WASI .wasm → execution through wasd
```

| PRD | Outcome |
|---|---|
| [PRD 01](01-package-foundation.md) | Workspace and package boundaries |
| [PRD 02](02-binary-reader.md) | `wasd` engine adapter |
| [PRD 03](03-module-parser.md) | Versioned workload artifacts and metadata |
| [PRD 04](04-dart-to-wasi-feasibility.md) | First Dart-authored WASI module |
| [PRD 05](05-dart-wasi-guest-sdk.md) | Minimal Dart WASI guest API |
| [PRD 06](06-http-over-wasi-protocol.md) | Dart `fetch` protocol over WASI |
| [PRD 07](07-isolated-execution.md) | Isolated request execution |
| [PRD 08](08-compilation-cache.md) | Compilation cache and revision lifecycle |
| [PRD 09](09-http-dispatch.md) | HTTP server and dispatch |
| [PRD 10](10-capability-policy.md) | Capability policy and bounded execution |
| [PRD 11](11-observability.md) | Observability and failure classification |
| [PRD 12](12-scale-to-zero.md) | Warm capacity and scale-to-zero |
| [PRD 13](13-developer-cli.md) | Compiler and host CLI |
| [PRD 14](14-conformance.md) | Fixtures, compatibility, and benchmarks |
| [PRD 15](15-deployment-poc.md) | Optional Kubernetes deployment PoC |

PRDs 04 and 05 are hard gates. The Worker-platform PRDs must not claim
Dart-authored guests until compiler feasibility is proven.

Every PR must pass:

```shell
dart format --output=none --set-exit-if-changed .
dart analyze
dart test packages/dart2wasi/test
dart test packages/dart_wasi/test
dart test packages/wasi_runtime/test
```
