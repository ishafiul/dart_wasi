# 01 — Uint8List

## What it is

`Uint8List` is a fixed-length list of unsigned 8-bit integers from `dart:typed_data`.

```dart
import 'dart:typed_data';

final bytes = Uint8List.fromList([
  0,
  1,
  127,
  128,
  255,
]);
```

Each element represents one byte:

```text
Minimum: 0   = 0x00 = 00000000
Maximum: 255 = 0xFF = 11111111
```

Official Dart definition:

> A fixed-length list of 8-bit unsigned integers.

## Why binary parsers need it

A `.wasm` file contains bytes, not text:

```text
00 61 73 6D 01 00 00 00
```

`Uint8List` stores these bytes directly:

```dart
final wasmBytes = Uint8List.fromList([
  0x00,
  0x61,
  0x73,
  0x6D,
  0x01,
  0x00,
  0x00,
  0x00,
]);
```

Binary parser uses it to:

- Load raw `.wasm` data.
- Read one byte at a time.
- Compare header bytes.
- Decode multi-byte integers.
- Extract section payloads.
- Track byte offsets.
- Detect truncated input.

## Loading file bytes

Do not load Wasm as text:

```dart
final text = await File('module.wasm').readAsString();
```

Arbitrary binary data may not be valid UTF-8.

Load bytes:

```dart
import 'dart:io';
import 'dart:typed_data';

final Uint8List bytes =
    await File('module.wasm').readAsBytes();
```

`File.readAsBytes()` returns `Future<Uint8List>`.

## Why not plain `List<int>`

Plain `List<int>` can contain arbitrary integers:

```dart
final values = <int>[-100, 255, 999999];
```

`Uint8List` communicates binary-data constraints:

- Each element represents one byte.
- Each value is unsigned.
- Values occupy range `0` through `255`.
- Length is fixed.
- Storage is optimized for byte data.

## Fixed length

```dart
final bytes = Uint8List(4);

bytes[0] = 10;
bytes[1] = 20;
```

List length cannot grow after creation.

## Eight-bit truncation

Stored values keep low eight bits:

```dart
final bytes = Uint8List(2);

bytes[0] = 255;
bytes[1] = 256;

print(bytes[0]); // 255
print(bytes[1]); // 0
```

Parser must still validate logical ranges. Silent truncation must not hide malformed input.

## Byte indexing

```dart
final bytes = Uint8List.fromList([
  0x00,
  0x61,
  0x73,
  0x6D,
]);

print(bytes[0]); // 0
print(bytes[1]); // 97
```

Convert byte to two-digit hex:

```dart
final hex = bytes[1].toRadixString(16).padLeft(2, '0');
print('0x$hex'); // 0x61
```

## Copies and views

`sublist` creates independent copy:

```dart
final copy = bytes.sublist(1, 3);
```

`Uint8List.sublistView` shares underlying buffer:

```dart
final source = Uint8List.fromList([10, 20, 30, 40]);
final view = Uint8List.sublistView(source, 1, 3);

view[0] = 99;

print(source); // [10, 99, 30, 40]
```

Use copy when data needs independence. Use view to inspect ranges without copying.

## ByteBuffer and ByteData

`Uint8List` is a typed view over `ByteBuffer`:

```dart
final buffer = bytes.buffer;
print(buffer.lengthInBytes);
```

`ByteData` reads fixed-width numeric values from same bytes:

```dart
final bytes = Uint8List.fromList([
  0x01,
  0x00,
  0x00,
  0x00,
]);

final data = ByteData.sublistView(bytes);
final version = data.getUint32(0, Endian.little);

print(version); // 1
```

`ByteData` helps with fixed-width integers. LEB128 still requires byte-by-byte decoding.

## References

- [Dart API: Uint8List](https://api.dart.dev/dart-typed_data/Uint8List-class.html)
- [Dart API: dart:typed_data](https://api.dart.dev/dart-typed_data/)
- [Dart API: File.readAsBytes](https://api.dart.dev/dart-io/File/readAsBytes.html)
- [Dart API: Uint8List.sublist](https://api.dart.dev/dart-typed_data/Uint8List/sublist.html)
- [Dart API: Uint8List.sublistView](https://api.dart.dev/dart-typed_data/Uint8List/Uint8List.sublistView.html)
- [Dart API: Uint8List.view](https://api.dart.dev/dart-typed_data/Uint8List/Uint8List.view.html)
- [Dart API: ByteData](https://api.dart.dev/dart-typed_data/ByteData-class.html)
- [Dart API: TypedData](https://api.dart.dev/dart-typed_data/TypedData-class.html)
- [Dart core libraries](https://dart.dev/libraries)
- [Uint8List (Technique of the Week) — Flutter](https://www.youtube.com/watch?v=9lhN5QXyZQc)

