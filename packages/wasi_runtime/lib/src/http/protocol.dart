import 'dart:convert';
import 'dart:typed_data';

import '../errors.dart';
import 'models.dart';

/// Version 1 of the bounded HTTP-over-WASI stdin/stdout protocol.
///
/// Both envelope kinds begin with `DWHP`, an 8-bit version, an 8-bit kind,
/// and two reserved zero bytes. Integers are unsigned 32-bit little-endian.
/// Header fields are stored as length-prefixed UTF-8 name/value pairs.
abstract final class WasiHttpProtocol {
  static const int version = 1;
  static const int maximumEnvelopeBytes = 16 * 1024;
  static const int maximumBodyBytes = 12 * 1024;
  static const int maximumMethodBytes = 16;
  static const int maximumPathBytes = 4 * 1024;
  static const int maximumQueryBytes = 4 * 1024;
  static const int maximumHeaderCount = 64;
  static const int maximumHeaderNameBytes = 128;
  static const int maximumHeaderValueBytes = 4 * 1024;

  static const List<int> _magic = [0x44, 0x57, 0x48, 0x50];
  static const int _requestKind = 1;
  static const int _responseKind = 2;

  /// Encodes [request] for a guest's stdin.
  static Uint8List encodeRequest(WasiHttpRequest request) {
    final method = _encodeText(
      request.method,
      field: 'method',
      maximumBytes: maximumMethodBytes,
      allowEmpty: false,
    );
    final path = _encodeText(
      request.path,
      field: 'path',
      maximumBytes: maximumPathBytes,
      allowEmpty: false,
    );
    final query = _encodeText(
      request.query,
      field: 'query',
      maximumBytes: maximumQueryBytes,
    );
    final headers = _encodeHeaders(request.headers);
    final body = _copyBody(request.body);

    final output = BytesBuilder(copy: false)
      ..add(_prefix(_requestKind))
      ..add(_uint32(method.length))
      ..add(_uint32(path.length))
      ..add(_uint32(query.length))
      ..add(_uint32(request.headers.length))
      ..add(_uint32(body.length))
      ..add(method)
      ..add(path)
      ..add(query)
      ..add(headers)
      ..add(body);
    return _boundedEnvelope(output.takeBytes());
  }

  /// Decodes a request envelope, primarily for protocol adapters and tests.
  static WasiHttpRequest decodeRequest(List<int> envelope) {
    final reader = _EnvelopeReader(envelope);
    _readPrefix(reader, _requestKind);
    final methodLength = reader.readUint32('method length');
    final pathLength = reader.readUint32('path length');
    final queryLength = reader.readUint32('query length');
    final headerCount = reader.readUint32('header count');
    final bodyLength = reader.readUint32('body length');
    _checkCount(headerCount);
    _checkBodyLength(bodyLength);

    final method = reader.readText(
      methodLength,
      field: 'method',
      maximumBytes: maximumMethodBytes,
      allowEmpty: false,
    );
    final path = reader.readText(
      pathLength,
      field: 'path',
      maximumBytes: maximumPathBytes,
      allowEmpty: false,
    );
    final query = reader.readText(
      queryLength,
      field: 'query',
      maximumBytes: maximumQueryBytes,
    );
    final headers = _decodeHeaders(reader, headerCount);
    final body = reader.readBytes(bodyLength, 'body');
    reader.requireEnd();
    return WasiHttpRequest(
      method: method,
      path: path,
      query: query,
      headers: headers,
      body: body,
    );
  }

  /// Encodes [response]. Useful for independent protocol implementations.
  static Uint8List encodeResponse(WasiHttpResponse response) {
    _checkStatus(response.status);
    final headers = _encodeHeaders(response.headers);
    final body = _copyBody(response.body);
    final output = BytesBuilder(copy: false)
      ..add(_prefix(_responseKind))
      ..add(_uint32(response.status))
      ..add(_uint32(response.headers.length))
      ..add(_uint32(body.length))
      ..add(headers)
      ..add(body);
    return _boundedEnvelope(output.takeBytes());
  }

  /// Decodes a response written to a host's stdout.
  static WasiHttpResponse decodeResponse(List<int> envelope) {
    final reader = _EnvelopeReader(envelope);
    _readPrefix(reader, _responseKind);
    final status = reader.readUint32('status');
    final headerCount = reader.readUint32('header count');
    final bodyLength = reader.readUint32('body length');
    _checkStatus(status);
    _checkCount(headerCount);
    _checkBodyLength(bodyLength);
    final headers = _decodeHeaders(reader, headerCount);
    final body = reader.readBytes(bodyLength, 'body');
    reader.requireEnd();
    return WasiHttpResponse(status: status, headers: headers, body: body);
  }

  static Uint8List _prefix(int kind) =>
      Uint8List.fromList([..._magic, version, kind, 0, 0]);

  static void _readPrefix(_EnvelopeReader reader, int expectedKind) {
    for (final expectedByte in _magic) {
      if (reader.readUint8('magic') != expectedByte) {
        throw const WasiHttpProtocolException(
          'Envelope has an invalid DWHP magic value.',
        );
      }
    }
    final actualVersion = reader.readUint8('version');
    if (actualVersion != version) {
      throw WasiHttpProtocolException(
        'Unsupported HTTP-over-WASI protocol version $actualVersion; '
        'expected $version.',
      );
    }
    final actualKind = reader.readUint8('kind');
    if (actualKind != expectedKind) {
      throw WasiHttpProtocolException(
        'Unexpected envelope kind $actualKind; expected $expectedKind.',
      );
    }
    if (reader.readUint8('reserved byte') != 0 ||
        reader.readUint8('reserved byte') != 0) {
      throw const WasiHttpProtocolException(
        'Envelope reserved bytes must be zero.',
      );
    }
  }

  static Uint8List _encodeHeaders(List<WasiHttpHeader> headers) {
    _checkCount(headers.length);
    final output = BytesBuilder(copy: false);
    for (final header in headers) {
      final name = _encodeText(
        header.name,
        field: 'header name',
        maximumBytes: maximumHeaderNameBytes,
        allowEmpty: false,
      );
      final value = _encodeText(
        header.value,
        field: 'header value',
        maximumBytes: maximumHeaderValueBytes,
      );
      _rejectHeaderControlCharacters(header.name, header.value);
      output
        ..add(_uint32(name.length))
        ..add(_uint32(value.length))
        ..add(name)
        ..add(value);
    }
    return output.takeBytes();
  }

  static List<WasiHttpHeader> _decodeHeaders(
    _EnvelopeReader reader,
    int count,
  ) {
    final headers = <WasiHttpHeader>[];
    for (var index = 0; index < count; index++) {
      final nameLength = reader.readUint32('header name length');
      final valueLength = reader.readUint32('header value length');
      final name = reader.readText(
        nameLength,
        field: 'header name',
        maximumBytes: maximumHeaderNameBytes,
        allowEmpty: false,
      );
      final value = reader.readText(
        valueLength,
        field: 'header value',
        maximumBytes: maximumHeaderValueBytes,
      );
      _rejectHeaderControlCharacters(name, value);
      headers.add(WasiHttpHeader(name, value));
    }
    return List.unmodifiable(headers);
  }

  static Uint8List _encodeText(
    String value, {
    required String field,
    required int maximumBytes,
    bool allowEmpty = true,
  }) {
    final bytes = Uint8List.fromList(utf8.encode(value));
    _checkTextLength(
      bytes.length,
      field: field,
      maximumBytes: maximumBytes,
      allowEmpty: allowEmpty,
    );
    return bytes;
  }

  static void _checkTextLength(
    int length, {
    required String field,
    required int maximumBytes,
    required bool allowEmpty,
  }) {
    if (!allowEmpty && length == 0) {
      throw WasiHttpProtocolException('$field must not be empty.');
    }
    if (length > maximumBytes) {
      throw WasiHttpProtocolException(
        '$field contains $length bytes; maximum is $maximumBytes.',
      );
    }
  }

  static void _checkCount(int count) {
    if (count > maximumHeaderCount) {
      throw WasiHttpProtocolException(
        'Envelope contains $count headers; maximum is $maximumHeaderCount.',
      );
    }
  }

  static Uint8List _copyBody(List<int> body) {
    _checkBodyLength(body.length);
    return Uint8List.fromList(body);
  }

  static void _checkBodyLength(int length) {
    if (length > maximumBodyBytes) {
      throw WasiHttpProtocolException(
        'Body contains $length bytes; maximum is $maximumBodyBytes.',
      );
    }
  }

  static void _checkStatus(int status) {
    if (status < 100 || status > 599) {
      throw WasiHttpProtocolException(
        'HTTP response status $status is outside 100 through 599.',
      );
    }
  }

  static void _rejectHeaderControlCharacters(String name, String value) {
    if (name.contains('\r') ||
        name.contains('\n') ||
        name.contains('\u0000') ||
        value.contains('\r') ||
        value.contains('\n') ||
        value.contains('\u0000')) {
      throw const WasiHttpProtocolException(
        'Header names and values cannot contain CR, LF, or NUL.',
      );
    }
  }

  static Uint8List _boundedEnvelope(Uint8List bytes) {
    if (bytes.length > maximumEnvelopeBytes) {
      throw WasiHttpProtocolException(
        'Envelope contains ${bytes.length} bytes; maximum is '
        '$maximumEnvelopeBytes.',
      );
    }
    return bytes;
  }

  static Uint8List _uint32(int value) {
    final bytes = ByteData(4)..setUint32(0, value, Endian.little);
    return bytes.buffer.asUint8List();
  }
}

final class _EnvelopeReader {
  _EnvelopeReader(List<int> source) : _bytes = Uint8List.fromList(source) {
    if (_bytes.length > WasiHttpProtocol.maximumEnvelopeBytes) {
      throw WasiHttpProtocolException(
        'Envelope contains ${_bytes.length} bytes; maximum is '
        '${WasiHttpProtocol.maximumEnvelopeBytes}.',
      );
    }
  }

  final Uint8List _bytes;
  var _offset = 0;

  int readUint8(String field) {
    _requireAvailable(1, field);
    return _bytes[_offset++];
  }

  int readUint32(String field) {
    _requireAvailable(4, field);
    final value = ByteData.sublistView(
      _bytes,
      _offset,
      _offset + 4,
    ).getUint32(0, Endian.little);
    _offset += 4;
    return value;
  }

  Uint8List readBytes(int length, String field) {
    _requireAvailable(length, field);
    final value = Uint8List.fromList(_bytes.sublist(_offset, _offset + length));
    _offset += length;
    return value;
  }

  String readText(
    int length, {
    required String field,
    required int maximumBytes,
    bool allowEmpty = true,
  }) {
    WasiHttpProtocol._checkTextLength(
      length,
      field: field,
      maximumBytes: maximumBytes,
      allowEmpty: allowEmpty,
    );
    final bytes = readBytes(length, field);
    try {
      return utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      throw WasiHttpProtocolException('$field is not valid UTF-8.');
    }
  }

  void requireEnd() {
    if (_offset != _bytes.length) {
      throw WasiHttpProtocolException(
        'Envelope has ${_bytes.length - _offset} trailing bytes.',
      );
    }
  }

  void _requireAvailable(int length, String field) {
    if (length < 0 || _offset + length > _bytes.length) {
      throw WasiHttpProtocolException('Envelope ended while reading $field.');
    }
  }
}
