# 05 — Little-Endian Integers

## Byte order

Multi-byte number needs byte-order convention.

Value:

```text
0x12345678
```

Big-endian:

```text
12 34 56 78
```

Little-endian:

```text
78 56 34 12
```

Least-significant byte appears first in little-endian encoding.

## WebAssembly usage

WebAssembly fixed-width integers and floating-point bit patterns use little-endian byte order. Module version bytes:

```text
01 00 00 00
```

decode to integer `1`.

## Reading with ByteData

```dart
final data = ByteData.sublistView(bytes);
final value = data.getUint32(
  offset,
  Endian.little,
);
```

## Manual assembly

```dart
final value = b0 |
    (b1 << 8) |
    (b2 << 16) |
    (b3 << 24);
```

Each byte shifts into correct bit position.

## Fixed width versus LEB128

Little-endian fixed-width values always use known byte count. LEB128 uses variable byte count and separate decoding rules.

## References

- [Dart API: Endian](https://api.dart.dev/dart-typed_data/Endian-class.html)
- [Dart API: ByteData.getUint32](https://api.dart.dev/dart-typed_data/ByteData/getUint32.html)
- [WebAssembly binary values](https://webassembly.github.io/spec/core/binary/values.html)

