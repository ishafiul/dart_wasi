# 11 — WebAssembly Module Sections

A `.wasm` file is like a box containing several labeled compartments. Each
compartment stores one kind of information.

```text
Wasm module
├── Types
├── Imports
├── Functions
├── Memory
├── Exports
└── Code
```

## Type section

Describes the shapes of functions: their inputs and outputs.

```text
takes:   two i32 numbers
returns: one i32 number
```

This describes a function but does not contain its instructions.

## Import section

Lists things the module needs the host to provide.

```text
wasi_snapshot_preview1.proc_exit
```

This means: “I need a function named `proc_exit` from the module
`wasi_snapshot_preview1`.”

## Function and code sections

The function section connects each locally defined function to a type:

```text
function 0 uses type 0
```

The code section contains the actual instructions. The two sections must have
the same number of locally defined functions and bodies.

## Memory, global, and data sections

- Memory describes the guest's byte-addressed linear memory.
- Globals contain module-level typed values.
- Data contains bytes copied into memory during instantiation.

## Export section

Lists values the host may access by name:

```text
export function "_start"
export function "add"
export memory "memory"
```

An export may be a function, memory, table, global, or tag.

## Start section

Optionally identifies a function that runs automatically during instantiation.
This is different from the WASI `_start` export, which a WASI host calls.

## Table and element sections

A table stores references, commonly function references. The element section
provides its initial contents. Together they support indirect calls.

## Custom sections

Store optional information such as names, debug data, or compiler metadata.
Unknown custom sections can normally be ignored.

## How sections connect

For an exported `add` function:

```text
Type section     says: (i32, i32) → i32
Function section says: function 0 uses that type
Code section     contains: load, load, add
Export section   exposes function 0 as "add"
```

Sections refer to one another using numeric indexes.

## Why we need to know this

`wasd` parses these sections for us. We still need the mental model to
understand module metadata, imports, exports, validation errors, and workload
compatibility.

## References

- [WebAssembly binary modules](https://webassembly.github.io/spec/core/binary/modules.html)
- [WebAssembly validation](https://webassembly.github.io/spec/core/valid/index.html)
