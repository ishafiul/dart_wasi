# 18 — Engine Adapters and Error Boundaries

Our application should not spread `wasd` types throughout every feature.
Instead, one adapter stands between the platform and the engine.

```text
Registry ─┐
HTTP ─────┼→ our engine interface → WasdEngine → wasd
Scheduler ┤
Metrics ──┘
```

## Why use an adapter?

- The rest of the platform stays independent of `wasd`.
- An engine upgrade changes one area.
- Tests can use a fake engine.
- We can define stable names for failures.
- A future engine can implement the same interface.

## Platform-owned data

The adapter returns our own simple objects:

- Import and export descriptions.
- Compiled-module interface.
- Instance interface.
- WASI execution options and result.

The real `wasd` objects remain private inside `WasdEngine`.

## Error categories

Different failures mean different things:

```text
validation failure → bad module
link failure       → missing or incompatible import
export failure     → requested function is unavailable
trap               → guest execution failed
WASI exit          → guest ended normally with an exit code
```

The adapter translates public `wasd` errors into these stable platform errors.

## When the engine hides information

Sometimes `wasd` does not expose enough public information to recover a more
specific error. We document that limitation. We do not inspect private engine
classes or guess by matching error-message text.

## Current limitations

In `wasd` 0.3.0:

- Native host-function errors can be hidden inside a private trap wrapper.
- WASI Preview 1 stdout and stderr do not have public injectable output sinks.

## References

- [Adapter pattern](https://refactoring.guru/design-patterns/adapter)
- [Dart library privacy](https://dart.dev/language/libraries)
