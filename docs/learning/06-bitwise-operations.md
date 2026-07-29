# 06 — Bitwise Operations

## Purpose

Bitwise operations manipulate integer bits directly. Binary decoding uses them to extract flags, combine byte payloads, and extend signed values.

## AND: `&`

Keeps bits set in both values:

```dart
final payload = byte & 0x7F;
```

`0x7F` clears high continuation bit and preserves lower seven bits.

## OR: `|`

Combines set bits:

```dart
result |= payload << shift;
```

Used to assemble LEB128 chunks.

## XOR: `^`

Sets bits that differ:

```dart
final result = left ^ right;
```

Not central to initial reader, but common in runtime numeric instructions.

## Left shift: `<<`

Moves bits left:

```dart
final positioned = payload << shift;
```

Each left shift by one multiplies unsigned value by two when no overflow matters.

## Right shift: `>>`

Moves bits right:

```dart
final shifted = value >> 7;
```

Dart right shift preserves sign. `>>>` performs unsigned right shift.

## Masks

Common LEB128 masks:

```text
0x7F = payload bits 0–6
0x80 = continuation bit 7
0x40 = sign bit inside seven-bit payload
```

## References

- [Dart language operators](https://dart.dev/language/operators)
- [Dart API: int](https://api.dart.dev/dart-core/int-class.html)

