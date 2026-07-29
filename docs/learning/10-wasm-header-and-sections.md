# 10 — WebAssembly Header and Sections

## Module preamble

WebAssembly binary module begins with eight bytes:

```text
00 61 73 6D 01 00 00 00
```

Magic:

```text
00 61 73 6D
```

Version 1:

```text
01 00 00 00
```

Magic identifies data as WebAssembly. Version selects binary-format version.

## Section envelope

After preamble, module contains sections:

```text
section ID      one byte
payload size    unsigned LEB128
payload         exactly payload-size bytes
```

Example:

```text
01 04 01 60 00 00
```

Interpretation:

```text
01          type section ID
04          four payload bytes
01 60 00 00 payload
```

## Section IDs

Core section IDs include:

```text
0  custom
1  type
2  import
3  function
4  table
5  memory
6  global
7  export
8  start
9  element
10 code
11 data
12 data count
13 tag
```

## Payload boundaries

Declared payload size must match actual section contents. Bounded sub-reader prevents section decoder from consuming following section.

```dart
final id = reader.readByte();
final size = reader.readVarUint32();
final payload = reader.readBytes(size);
final payloadReader = ByteReader(payload);
```

## Custom sections

Custom sections use ID `0`. Core runtime may skip uninterpreted custom payload safely. Custom sections may appear at multiple positions.

## Parsing boundary

Header/section-envelope layer identifies:

- Valid preamble.
- Section ID.
- Payload size.
- Exact payload bytes.

Typed interpretation of payload contents belongs to next parser layer.

## References

- [WebAssembly binary conventions](https://webassembly.github.io/spec/core/binary/conventions.html)
- [WebAssembly binary modules](https://webassembly.github.io/spec/core/binary/modules.html)
- [WebAssembly binary values](https://webassembly.github.io/spec/core/binary/values.html)

