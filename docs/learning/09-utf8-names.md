# 09 — UTF-8 Names

## Name encoding

WebAssembly names encode as byte vectors:

```text
byte length encoded as unsigned LEB128
UTF-8 bytes
```

Example:

```text
03 61 64 64
```

Meaning:

```text
03       three bytes
61 64 64 UTF-8 bytes for "add"
```

## Dart decoding

```dart
String readName() {
  final length = readVarUint32();
  final nameBytes = readBytes(length);

  return utf8.decode(
    nameBytes,
    allowMalformed: false,
  );
}
```

Strict decoding matters. Malformed UTF-8 makes module malformed where specification requires valid name.

## Byte length versus character count

Length prefix counts encoded bytes, not Unicode characters.

One non-ASCII character may use multiple UTF-8 bytes.

## References

- [Dart API: Utf8Codec](https://api.dart.dev/dart-convert/Utf8Codec-class.html)
- [WebAssembly binary values: names](https://webassembly.github.io/spec/core/binary/values.html#names)

