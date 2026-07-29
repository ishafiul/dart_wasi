# 02 — Bytes and Hexadecimal

## Bits and bytes

Bit has two possible values:

```text
0
1
```

Byte contains eight bits:

```text
00000000
11111111
```

Unsigned byte range:

```text
binary 00000000 = decimal 0
binary 11111111 = decimal 255
```

## Hexadecimal notation

Hexadecimal uses base 16:

```text
0 1 2 3 4 5 6 7 8 9 A B C D E F
```

One hexadecimal digit represents four bits. Two hexadecimal digits represent one byte:

```text
0x00 = 00000000
0x7F = 01111111
0x80 = 10000000
0xFF = 11111111
```

## Dart hexadecimal integers

```dart
final zero = 0x00;
final maximumByte = 0xFF;
```

Hex syntax changes representation, not value:

```dart
print(0x61); // 97
print(0xFF); // 255
```

## Converting to hexadecimal

```dart
final value = 97;
final hex = value.toRadixString(16);

print(hex); // 61
```

Two-digit byte formatting:

```dart
final hex = value.toRadixString(16).padLeft(2, '0');
print('0x$hex');
```

## Wasm byte display

WebAssembly specifications and hex dumps usually show bytes in hex:

```text
00 61 73 6D 01 00 00 00
```

Each pair is one byte. Byte position matters.

## References

- [Dart API: int.toRadixString](https://api.dart.dev/dart-core/int/toRadixString.html)
- [WebAssembly binary conventions](https://webassembly.github.io/spec/core/binary/conventions.html)

