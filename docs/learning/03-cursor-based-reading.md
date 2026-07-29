# 03 — Cursor-Based Binary Reading

## Sequential parsing

Binary formats store fields sequentially. Parser reads value at current position, advances position, then reads next value.

Current position is cursor or offset:

```dart
final class ByteReader {
  ByteReader(this.bytes);

  final Uint8List bytes;
  int offset = 0;
}
```

## Reading one byte

```dart
int readByte() {
  final byte = bytes[offset];
  offset += 1;
  return byte;
}
```

Safe implementation must validate bounds before access.

## Reading multiple bytes

```dart
Uint8List readBytes(int length) {
  final start = offset;
  final end = start + length;

  offset = end;
  return Uint8List.sublistView(bytes, start, end);
}
```

Again, validate `length`, `start`, and `end` before changing offset.

## End-of-input state

```dart
bool get isAtEnd => offset == bytes.length;

int get remaining => bytes.length - offset;
```

`offset > bytes.length` should never occur in correct implementation.

## Nested payload readers

Section payload can use reader limited to exact payload:

```dart
final payload = readBytes(payloadLength);
final payloadReader = ByteReader(payload);
```

This prevents section decoder from consuming bytes belonging to next section.

## References

- [WebAssembly binary conventions](https://webassembly.github.io/spec/core/binary/conventions.html)
- [Dart API: Uint8List.sublistView](https://api.dart.dev/dart-typed_data/Uint8List/Uint8List.sublistView.html)

