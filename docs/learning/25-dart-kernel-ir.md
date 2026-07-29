# 25 — Dart Kernel IR

A compiler usually does not translate source text directly into machine
instructions in one step.

```text
Dart source
→ parsed and type checked
→ intermediate representation
→ target code
```

Dart Kernel is an intermediate representation used by Dart tools. It describes
libraries, classes, functions, expressions, statements, and resolved types in a
form that is easier for a compiler backend to process than raw source text.

Using Kernel could let `dart2wasi` reuse Dart's parser and type checker. The
cost is that compiler-facing Dart SDK APIs may be complex or unstable.

An alternative is a deliberately tiny source parser, but that would need to
reimplement Dart syntax and type rules.

## Questions for the feasibility milestone

- Can supported source be produced as Kernel with public or maintainable tools?
- Which Kernel nodes are needed for the first fixture?
- How will unsupported nodes produce source-friendly diagnostics?
- How tightly would the package couple to one Dart SDK version?

## Why we need to know this

PRD 4 must choose a frontend before it can generate WebAssembly.

## References

- [Dart SDK repository](https://github.com/dart-lang/sdk)
