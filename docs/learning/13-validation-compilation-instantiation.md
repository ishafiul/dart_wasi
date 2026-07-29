# 13 — Validation, Compilation, and Instantiation

These are three different stages. A useful analogy is preparing a recipe.

```text
Validation    → check that the recipe makes sense
Compilation   → prepare an efficient cooking plan
Instantiation → create one real meal from the plan
```

## Validation

Validation checks that the Wasm module follows the rules.

It checks things such as:

- Referenced functions and types exist.
- Instructions use values of the correct types.
- Function declarations match function bodies.
- Memory limits are valid.

Valid does not mean safe, fast, or compatible with our platform. It only means
the module is structurally and type correct.

## Compilation

Compilation turns valid bytes into an engine-owned module that is ready to
instantiate.

With an interpreter, “compile” may mean decoding and preparing instructions
rather than generating machine code.

The compiled module is immutable and can be reused.

## Instantiation

Instantiation creates mutable runtime state:

- Links imports.
- Creates memory, tables, and globals.
- Initializes data.
- Creates callable functions.
- Runs the WebAssembly start function when one exists.

Two instances created from one compiled module have separate mutable state.

## Why we need to know this

PRD 3 stores immutable artifact bytes and metadata. Later we can cache
compilation, but each request should normally receive fresh instance and WASI
state.

## References

- [WebAssembly validation](https://webassembly.github.io/spec/core/valid/index.html)
- [WebAssembly instantiation](https://webassembly.github.io/spec/core/exec/modules.html#instantiation)
