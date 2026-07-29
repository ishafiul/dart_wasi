# 08 — Signed LEB128

## Purpose

Signed LEB128 encodes positive and negative integers with variable byte count.

WebAssembly uses signed LEB128 for values including:

- `i32.const`.
- `i64.const`.
- Some block-type encodings.

## Sign information

Final payload byte uses bit `0x40` as sign indicator:

```text
0x40 clear = non-negative
0x40 set   = negative
```

## Sign extension

After combining payload bits, negative value needs high bits filled with ones:

```dart
if (shift < 32 && (byte & 0x40) != 0) {
  result |= -(1 << shift);
}
```

## Decoder shape

```dart
int readVarInt32() {
  var result = 0;
  var shift = 0;
  var byte = 0;

  while (true) {
    byte = readByte();
    result |= (byte & 0x7F) << shift;
    shift += 7;

    if ((byte & 0x80) == 0) {
      break;
    }
  }

  if (shift < 32 && (byte & 0x40) != 0) {
    result |= -(1 << shift);
  }

  return result;
}
```

Production decoder must enforce target width, maximum byte count, valid terminal bits, and truncation checks.

## Example

```text
C0 BB 78 → -123456
```

## Unsigned versus signed

Same byte sequence may decode differently depending on expected type. Decoder must know whether grammar requires `u32`, `i32`, `u64`, or `i64`.

## References

- [WebAssembly binary values](https://webassembly.github.io/spec/core/binary/values.html)
- [LEB128](https://en.wikipedia.org/wiki/LEB128)

