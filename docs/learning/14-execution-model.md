# 14 — WebAssembly Execution Model

WebAssembly works like a small stack-based machine.

## The value stack

Instructions place values on a stack and remove values from it.

An addition can be imagined as:

```text
push 20
push 22
add
```

`add` removes the top two values and pushes `42`.

## Function calls

Each function call creates a frame containing:

- Arguments.
- Local variables.
- Where execution should return.

Frames are removed when functions return.

## Control flow

WebAssembly uses structured blocks:

```text
block
loop
if / else
```

Branches target an enclosing block or loop. They do not jump to arbitrary
source-code lines.

## Traps

A trap means execution cannot continue.

Common causes:

- Running `unreachable`.
- Dividing by zero.
- Reading outside memory.
- Calling an indirect function with the wrong type.

A trap is not a normal program exit:

```text
proc_exit(0) → guest completed successfully
trap         → guest execution failed
```

## Why we need to know this

`wasd` executes the instructions. We need to understand traps and mutable call
state so our platform can classify failures, isolate requests, and design
timeouts correctly.

## References

- [WebAssembly execution](https://webassembly.github.io/spec/core/exec/index.html)
- [WebAssembly instructions](https://webassembly.github.io/spec/core/syntax/instructions.html)
