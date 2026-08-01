# wasi_runtime

Experimental Dart host package for validating, registering, versioning, and
running standard WASI modules through `wasd`.

This package does not compile Dart source to WASI. That research belongs to the
neighboring `dart2wasi` package.

The package also owns the version 1 HTTP-over-WASI host contract:

- Immutable request, response, and ordered header models.
- A bounded `DWHP` binary envelope codec.
- Stable protocol and guest-execution failures.
- `CompiledModule.runHttp` for request-scoped execution with captured stderr.
