# 17 — The `wasd` Public API

`wasd` is the engine under our platform. It handles WebAssembly parsing,
validation, execution, memory, linking, and WASI.

## Validate bytes

```dart
final valid = WebAssembly.validate(bytes.buffer);
```

This answers whether `wasd` accepts the bytes as a valid module.

## Compile a module

```dart
final module = await WebAssembly.compile(bytes.buffer);
```

The result can be inspected and instantiated more than once.

## Inspect imports and exports

```dart
final imports = Module.imports(module);
final exports = Module.exports(module);
```

Our platform converts these descriptors into its own metadata types.

## Create an instance

```dart
final instance = await WebAssembly.instantiateModule(module, imports);
```

Imports must satisfy everything requested by the guest.

## Call an exported function

```dart
final value = instance.exports['add'];
```

The value must be checked as a function export before it is called.

## Run a WASI command

```dart
final wasi = WASI(
  args: ['worker'],
  env: {'MODE': 'production'},
  returnOnExit: true,
);

final instance = await WebAssembly.instantiateModule(
  module,
  wasi.imports,
);

final exitCode = wasi.start(instance);
```

## Public API rule

We may import:

```dart
package:wasd/wasd.dart
```

We must not import:

```dart
package:wasd/src/...
```

Files under `src` are private implementation details and may change without
warning.

## References

- [`wasd` package](https://pub.dev/packages/wasd)
- [`wasd` repository](https://github.com/medz/wasd)
