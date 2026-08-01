# Dart and WASI experiment

I am experimenting with WASI in Dart and learning how WebAssembly works.

The main goal is to prove that a user can write a small Worker program in Dart,
compile it into a standard WASI Preview 1 `.wasm` file, and run it inside a Dart
host through `wasd`.

```text
Dart Worker source
→ experimental dart2wasi compiler
→ WASI Preview 1 module
→ Dart host
→ wasd
→ response
```

This is a learning project and proof of concept, not a production-ready
compiler, runtime, or platform.

## Workspace

- `packages/dart2wasi`: experimental Dart-to-WASI compiler research.
- `packages/dart_wasi`: minimal APIs available to Dart guest programs.
- `packages/wasi_runtime`: Dart host and `wasd` integration.

The compiler supports a deliberately restricted Dart subset with typed
integers, booleans, opaque runtime bytes, direct functions, branches, loops,
stdout, stderr, bounded stdin, arguments, environment lookup, exit, and a
versioned HTTP `fetch` entrypoint. It emits standard WASI Preview 1 command
modules and imports only the capabilities used by each guest. The host can
validate, inspect, version, and execute those modules with request-scoped input
and captured output.

```shell
dart run dart2wasi examples/hello.dart /tmp/hello.wasm
dart run examples/run_hello.dart
dart run examples/run_wasm.dart /tmp/hello.wasm

dart run dart2wasi examples/subset.dart /tmp/subset.wasm
dart run examples/run_wasm.dart /tmp/subset.wasm

dart run examples/run_guest_io.dart
dart run examples/run_http_worker.dart
dart run examples/http_api_server.dart
```

`examples/run_guest_io.dart` demonstrates arguments, environment, stdin,
stdout, and stderr together. `examples/run_wasm.dart` runs an existing artifact
with empty host inputs and writes captured guest output before the exit code.
`examples/run_http_worker.dart` compiles a Dart `fetch` handler, sends a
versioned request envelope through WASI, and decodes its JSON response.

`examples/http_api_server.dart` runs a local multi-worker API at
`http://localhost:8080`: `GET /health`, `POST /api/echo`, and `GET /api/info`.
The route-specific workers live in `examples/http_api/`; they demonstrate JSON
responses, a binary request-body echo, and a second JSON endpoint.

## Intended result

If the proof of concept succeeds, a user will be able to:

- Write a small request handler in the supported Dart subset.
- Compile it into a WASI artifact.
- Upload and version that artifact.
- Route a request to the active revision.
- Execute the Dart-authored Worker only when requested.
- Return its response and release idle workload instances.
