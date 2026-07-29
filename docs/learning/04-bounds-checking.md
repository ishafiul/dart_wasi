# 04 — Bounds Checking

## Why bounds checks matter

Binary input may be:

- Empty.
- Truncated.
- Corrupted.
- Malicious.
- Incorrectly encoded.

Parser must reject bad input without host crash or accidental `RangeError`.

## Validate before reading

```dart
void requireBytes(int count) {
  if (count < 0) {
    throw FormatException('Negative byte count: $count');
  }

  if (count > bytes.length - offset) {
    throw FormatException(
      'Unexpected end at byte $offset',
    );
  }
}
```

Subtraction form avoids unsafe `offset + count` reasoning:

```dart
count > bytes.length - offset
```

## Atomic cursor behavior

Failed read should not advance cursor:

```dart
Uint8List readBytes(int length) {
  requireBytes(length);

  final start = offset;
  final end = start + length;
  final result = Uint8List.sublistView(bytes, start, end);

  offset = end;
  return result;
}
```

## Error context

Typed parser error should carry:

- Message.
- Byte offset.
- Requested amount.
- Remaining amount where relevant.

```dart
final class WasmFormatException implements Exception {
  const WasmFormatException(this.message, this.offset);

  final String message;
  final int offset;
}
```

Useful error:

```text
Unexpected end at byte 12: requested 4 bytes, 1 available
```

## References

- [Dart API: RangeError](https://api.dart.dev/dart-core/RangeError-class.html)
- [Dart API: FormatException](https://api.dart.dev/dart-core/FormatException-class.html)

