# 07 — Unsigned LEB128

## Purpose

LEB128 stores integers using variable number of bytes. Small values use fewer bytes.

WebAssembly uses unsigned LEB128 for values such as:

- Section sizes.
- Vector lengths.
- Type indices.
- Function indices.
- Memory limits.

## Byte structure

Each byte contains:

```text
bit 7     continuation flag
bits 0–6  seven payload bits
```

```text
0xxxxxxx = final byte
1xxxxxxx = another byte follows
```

## Decoding

```dart
int readVarUint32() {
  var result = 0;
  var shift = 0;

  while (true) {
    final byte = readByte();
    final payload = byte & 0x7F;

    result |= payload << shift;

    if ((byte & 0x80) == 0) {
      return result;
    }

    shift += 7;
  }
}
```

Production decoder must also enforce:

- Maximum encoded byte count.
- Target integer width.
- Valid unused high bits.
- Truncated-input detection.

## Example

```text
E5 8E 26 → 624485
```

Payloads:

```text
E5 & 7F = 65
8E & 7F = 0E
26 & 7F = 26
```

Combined:

```text
0x65 << 0
0x0E << 7
0x26 << 14
```

## References

- [WebAssembly binary values](https://webassembly.github.io/spec/core/binary/values.html)
- [LEB128](https://en.wikipedia.org/wiki/LEB128)

