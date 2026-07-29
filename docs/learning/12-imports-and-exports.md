# 12 — Imports and Exports

Imports and exports describe the boundary between a WebAssembly module and its
host.

Think of a module as a small machine:

- Imports are sockets where the host plugs things in.
- Exports are buttons the host is allowed to press.

## Imports

An import is something the guest needs but does not implement itself.

Every import has:

- A module name.
- A value name.
- A kind, such as function or memory.
- A required type.

Example:

```text
module: wasi_snapshot_preview1
name:   proc_exit
kind:   function
```

The host must provide a matching value when creating the instance.

## Exports

An export makes an internal value available by name.

```text
name: "_start"
kind: function
```

Exports can also be memory, globals, tables, or tags. We must check the kind
before trying to call an export as a function.

## Linking

Linking connects imports to host-provided values.

The following must match:

```text
module name
import name
kind
type
```

If any required import is missing or incompatible, the module cannot be
instantiated.

## Why we need to know this

Imports tell our platform what capabilities a workload asks for. Exports tell
us how we can enter the workload. PRD 3 records both as artifact metadata.

## References

- [WebAssembly imports](https://webassembly.github.io/spec/core/syntax/modules.html#imports)
- [WebAssembly exports](https://webassembly.github.io/spec/core/syntax/modules.html#exports)
