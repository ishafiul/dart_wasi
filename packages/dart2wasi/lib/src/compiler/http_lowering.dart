part of '../compiler.dart';

/// Wire offsets and limits shared by the generated HTTP adapter.
abstract final class _HttpWire {
  static const int magic = 0x50485744; // `DWHP` as little-endian i32.
  static const int requestPrefix = 0x00000101; // version 1, request kind 1.
  static const int responsePrefix = 0x00000201; // version 1, response kind 2.

  static const int requestFixedBytes = 28;
  static const int requestMethodLengthOffset = 8;
  static const int requestPathLengthOffset = 12;
  static const int requestQueryLengthOffset = 16;
  static const int requestHeaderCountOffset = 20;
  static const int requestBodyLengthOffset = 24;

  static const int maximumEnvelopeBytes = 16 * 1024;
  static const int maximumBodyBytes = 12 * 1024;
  static const int maximumMethodBytes = 16;
  static const int maximumPathBytes = 4 * 1024;
  static const int maximumQueryBytes = 4 * 1024;
  static const int maximumHeaderCount = 64;
  static const int maximumHeaderNameBytes = 128;
  static const int maximumHeaderValueBytes = 4 * 1024;
  static const int maximumResponseContentTypeBytes = 128;

  static const int responseFixedBytes = 40;
}

extension _HttpLowering on _WasiModuleWriter {
  List<_DefinedFunction> _buildHttpRuntimeFunctions() => [
    _buildHttpValidateRequestFunction(),
    _buildHttpRequestMethodFunction(),
    _buildHttpRequestPathFunction(),
    _buildHttpRequestQueryFunction(),
    _buildHttpRequestBodyFunction(),
    _buildHttpHeaderAtFunction(),
    _buildHttpHeaderAccessorFunction(
      name: _httpHeaderNameAtFunction,
      selectValue: false,
    ),
    _buildHttpHeaderAccessorFunction(
      name: _httpHeaderValueAtFunction,
      selectValue: true,
    ),
    _buildHttpCreateResponseFunction(),
    _buildHttpWriteResponseFunction(),
  ];

  _DefinedFunction _buildHttpValidateRequestFunction() {
    return _DefinedFunction(
      name: _httpValidateRequestFunction,
      signature: const _FunctionSignature([
        _WasmValueType.i64,
      ], _WasmValueType.i32),
      locals: const [
        _WasmValueType.i32, // pointer
        _WasmValueType.i32, // length
        _WasmValueType.i32, // end
        _WasmValueType.i32, // cursor
        _WasmValueType.i32, // header count
        _WasmValueType.i32, // header index
        _WasmValueType.i32, // name length
        _WasmValueType.i32, // value length
      ],
      buildBody: (layout) {
        const pointer = 1;
        const length = 2;
        const end = 3;
        const cursor = 4;
        const headerCount = 5;
        const headerIndex = 6;
        const nameLength = 7;
        const valueLength = 8;
        final code = _Instructions();

        _emitBytesPointer(code, 0);
        code.localTee(pointer);
        code.i32Const(_GuestMemory.stdinBuffer);
        code.i32NotEqual();
        _emitRuntimeErrorIf(code, layout);
        _emitBytesLength(code, 0);
        code.localTee(length);
        code.i32Const(_HttpWire.requestFixedBytes);
        code.i32LessUnsigned();
        _emitRuntimeErrorIf(code, layout);
        code.localGet(length);
        code.i32Const(_HttpWire.maximumEnvelopeBytes);
        code.i32GreaterUnsigned();
        _emitRuntimeErrorIf(code, layout);
        code.localGet(pointer);
        code.localGet(length);
        code.i32Add();
        code.localSet(end);

        _emitI32FieldEquals(code, layout, pointer, 0, _HttpWire.magic);
        _emitI32FieldEquals(code, layout, pointer, 4, _HttpWire.requestPrefix);
        _emitFieldAtMost(
          code,
          layout,
          pointer,
          _HttpWire.requestMethodLengthOffset,
          _HttpWire.maximumMethodBytes,
        );
        _emitFieldAtMost(
          code,
          layout,
          pointer,
          _HttpWire.requestPathLengthOffset,
          _HttpWire.maximumPathBytes,
        );
        _emitFieldAtMost(
          code,
          layout,
          pointer,
          _HttpWire.requestQueryLengthOffset,
          _HttpWire.maximumQueryBytes,
        );
        _emitFieldAtMost(
          code,
          layout,
          pointer,
          _HttpWire.requestBodyLengthOffset,
          _HttpWire.maximumBodyBytes,
        );
        code.localGet(pointer);
        code.i32Load(offset: _HttpWire.requestMethodLengthOffset);
        code.i32EqualZero();
        _emitRuntimeErrorIf(code, layout);
        code.localGet(pointer);
        code.i32Load(offset: _HttpWire.requestPathLengthOffset);
        code.i32EqualZero();
        _emitRuntimeErrorIf(code, layout);

        code.localGet(pointer);
        code.i32Load(offset: _HttpWire.requestHeaderCountOffset);
        code.localTee(headerCount);
        code.i32Const(_HttpWire.maximumHeaderCount);
        code.i32GreaterUnsigned();
        _emitRuntimeErrorIf(code, layout);

        code.localGet(pointer);
        code.i32Const(_HttpWire.requestFixedBytes);
        code.i32Add();
        for (final offset in const [
          _HttpWire.requestMethodLengthOffset,
          _HttpWire.requestPathLengthOffset,
          _HttpWire.requestQueryLengthOffset,
        ]) {
          code.localGet(pointer);
          code.i32Load(offset: offset);
          code.i32Add();
        }
        code.localTee(cursor);
        code.localGet(end);
        code.i32GreaterUnsigned();
        _emitRuntimeErrorIf(code, layout);

        code.i32Const(0);
        code.localSet(headerIndex);
        code.block();
        code.loop();
        code.localGet(headerIndex);
        code.localGet(headerCount);
        code.i32GreaterEqualUnsigned();
        code.branchIf(1);
        _emitRequireRemaining(code, layout, cursor, end, 8);
        code.localGet(cursor);
        code.i32Load();
        code.localTee(nameLength);
        code.i32EqualZero();
        _emitRuntimeErrorIf(code, layout);
        code.localGet(nameLength);
        code.i32Const(_HttpWire.maximumHeaderNameBytes);
        code.i32GreaterUnsigned();
        _emitRuntimeErrorIf(code, layout);
        code.localGet(cursor);
        code.i32Load(offset: 4);
        code.localTee(valueLength);
        code.i32Const(_HttpWire.maximumHeaderValueBytes);
        code.i32GreaterUnsigned();
        _emitRuntimeErrorIf(code, layout);
        code.localGet(cursor);
        code.i32Const(8);
        code.i32Add();
        code.localGet(nameLength);
        code.i32Add();
        code.localGet(valueLength);
        code.i32Add();
        code.localTee(cursor);
        code.localGet(end);
        code.i32GreaterUnsigned();
        _emitRuntimeErrorIf(code, layout);
        code.localGet(headerIndex);
        code.i32Const(1);
        code.i32Add();
        code.localSet(headerIndex);
        code.branch(0);
        code.end();
        code.end();

        code.localGet(cursor);
        code.localGet(pointer);
        code.i32Load(offset: _HttpWire.requestBodyLengthOffset);
        code.i32Add();
        code.localGet(end);
        code.i32NotEqual();
        _emitRuntimeErrorIf(code, layout);
        code.localGet(pointer);
        return code.bytes;
      },
    );
  }

  _DefinedFunction _buildHttpRequestMethodFunction() {
    return _buildPackedRequestFieldFunction(
      name: _httpRequestMethodFunction,
      lengthOffset: _HttpWire.requestMethodLengthOffset,
      precedingLengthOffsets: const [],
    );
  }

  _DefinedFunction _buildHttpRequestPathFunction() {
    return _buildPackedRequestFieldFunction(
      name: _httpRequestPathFunction,
      lengthOffset: _HttpWire.requestPathLengthOffset,
      precedingLengthOffsets: const [_HttpWire.requestMethodLengthOffset],
    );
  }

  _DefinedFunction _buildHttpRequestQueryFunction() {
    return _buildPackedRequestFieldFunction(
      name: _httpRequestQueryFunction,
      lengthOffset: _HttpWire.requestQueryLengthOffset,
      precedingLengthOffsets: const [
        _HttpWire.requestMethodLengthOffset,
        _HttpWire.requestPathLengthOffset,
      ],
    );
  }

  _DefinedFunction _buildPackedRequestFieldFunction({
    required String name,
    required int lengthOffset,
    required List<int> precedingLengthOffsets,
  }) {
    return _DefinedFunction(
      name: name,
      signature: const _FunctionSignature([
        _WasmValueType.i32,
      ], _WasmValueType.i64),
      locals: const [],
      buildBody: (_) {
        final code = _Instructions();
        _emitPackedBytes(
          code,
          pointer: () {
            code.localGet(0);
            code.i32Const(_HttpWire.requestFixedBytes);
            code.i32Add();
            for (final offset in precedingLengthOffsets) {
              code.localGet(0);
              code.i32Load(offset: offset);
              code.i32Add();
            }
          },
          length: () {
            code.localGet(0);
            code.i32Load(offset: lengthOffset);
          },
        );
        return code.bytes;
      },
    );
  }

  _DefinedFunction _buildHttpRequestBodyFunction() {
    return _DefinedFunction(
      name: _httpRequestBodyFunction,
      signature: const _FunctionSignature([
        _WasmValueType.i32,
      ], _WasmValueType.i64),
      locals: const [
        _WasmValueType.i32,
        _WasmValueType.i32,
        _WasmValueType.i32,
      ],
      buildBody: (_) {
        const cursor = 1;
        const count = 2;
        const index = 3;
        final code = _Instructions();
        _emitHeadersStart(code, 0);
        code.localSet(cursor);
        code.localGet(0);
        code.i32Load(offset: _HttpWire.requestHeaderCountOffset);
        code.localSet(count);
        code.i32Const(0);
        code.localSet(index);
        code.block();
        code.loop();
        code.localGet(index);
        code.localGet(count);
        code.i32GreaterEqualUnsigned();
        code.branchIf(1);
        _emitAdvanceHeader(code, cursor);
        code.localGet(index);
        code.i32Const(1);
        code.i32Add();
        code.localSet(index);
        code.branch(0);
        code.end();
        code.end();
        _emitPackedBytes(
          code,
          pointer: () => code.localGet(cursor),
          length: () {
            code.localGet(0);
            code.i32Load(offset: _HttpWire.requestBodyLengthOffset);
          },
        );
        return code.bytes;
      },
    );
  }

  _DefinedFunction _buildHttpHeaderAtFunction() {
    return _DefinedFunction(
      name: _httpHeaderAtFunction,
      signature: const _FunctionSignature([
        _WasmValueType.i32,
        _WasmValueType.i32,
        _WasmValueType.i32,
      ], _WasmValueType.i64),
      locals: const [_WasmValueType.i32, _WasmValueType.i32],
      buildBody: (layout) {
        const cursor = 3;
        const index = 4;
        final code = _Instructions();
        code.localGet(1);
        code.i32Const(0);
        code.i32LessSigned();
        _emitRuntimeErrorIf(code, layout);
        code.localGet(1);
        code.localGet(0);
        code.i32Load(offset: _HttpWire.requestHeaderCountOffset);
        code.i32GreaterEqualUnsigned();
        _emitRuntimeErrorIf(code, layout);
        _emitHeadersStart(code, 0);
        code.localSet(cursor);
        code.i32Const(0);
        code.localSet(index);
        code.block();
        code.loop();
        code.localGet(index);
        code.localGet(1);
        code.i32GreaterEqualUnsigned();
        code.branchIf(1);
        _emitAdvanceHeader(code, cursor);
        code.localGet(index);
        code.i32Const(1);
        code.i32Add();
        code.localSet(index);
        code.branch(0);
        code.end();
        code.end();
        code.localGet(2);
        code.ifResult(_WasmValueType.i64);
        _emitPackedBytes(
          code,
          pointer: () {
            code.localGet(cursor);
            code.i32Const(8);
            code.i32Add();
            code.localGet(cursor);
            code.i32Load();
            code.i32Add();
          },
          length: () {
            code.localGet(cursor);
            code.i32Load(offset: 4);
          },
        );
        code.elseClause();
        _emitPackedBytes(
          code,
          pointer: () {
            code.localGet(cursor);
            code.i32Const(8);
            code.i32Add();
          },
          length: () {
            code.localGet(cursor);
            code.i32Load();
          },
        );
        code.end();
        return code.bytes;
      },
    );
  }

  _DefinedFunction _buildHttpHeaderAccessorFunction({
    required String name,
    required bool selectValue,
  }) {
    return _DefinedFunction(
      name: name,
      signature: const _FunctionSignature([
        _WasmValueType.i32,
        _WasmValueType.i32,
      ], _WasmValueType.i64),
      locals: const [],
      buildBody: (layout) {
        final code = _Instructions();
        code.localGet(0);
        code.localGet(1);
        code.i32Const(selectValue ? 1 : 0);
        code.call(layout.functionIndex(_httpHeaderAtFunction));
        return code.bytes;
      },
    );
  }

  _DefinedFunction _buildHttpCreateResponseFunction() {
    return _DefinedFunction(
      name: _httpCreateResponseFunction,
      signature: const _FunctionSignature([
        _WasmValueType.i32,
        _WasmValueType.i64,
        _WasmValueType.i64,
      ], _WasmValueType.i32),
      locals: const [_WasmValueType.i32, _WasmValueType.i32],
      buildBody: (layout) {
        const contentTypeLength = 3;
        const bodyLength = 4;
        final code = _Instructions();
        code.localGet(0);
        code.i32Const(100);
        code.i32LessSigned();
        _emitRuntimeErrorIf(code, layout);
        code.localGet(0);
        code.i32Const(599);
        code.i32GreaterSigned();
        _emitRuntimeErrorIf(code, layout);
        _emitBytesLength(code, 1);
        code.localTee(contentTypeLength);
        code.i32EqualZero();
        _emitRuntimeErrorIf(code, layout);
        code.localGet(contentTypeLength);
        code.i32Const(_HttpWire.maximumResponseContentTypeBytes);
        code.i32GreaterUnsigned();
        _emitRuntimeErrorIf(code, layout);
        _emitBytesLength(code, 2);
        code.localTee(bodyLength);
        code.i32Const(_HttpWire.maximumBodyBytes);
        code.i32GreaterUnsigned();
        _emitRuntimeErrorIf(code, layout);
        code.localGet(contentTypeLength);
        code.localGet(bodyLength);
        code.i32Add();
        code.i32Const(_HttpWire.responseFixedBytes);
        code.i32Add();
        code.i32Const(_HttpWire.maximumEnvelopeBytes);
        code.i32GreaterUnsigned();
        _emitRuntimeErrorIf(code, layout);

        code.i32Const(_GuestMemory.httpResponseRecord);
        code.localGet(0);
        code.i32Store();
        code.i32Const(_GuestMemory.httpResponseRecord);
        code.localGet(1);
        code.i64Store(offset: 8);
        code.i32Const(_GuestMemory.httpResponseRecord);
        code.localGet(2);
        code.i64Store(offset: 16);
        code.i32Const(_GuestMemory.httpResponseRecord);
        return code.bytes;
      },
    );
  }

  _DefinedFunction _buildHttpWriteResponseFunction() {
    return _DefinedFunction(
      name: _httpWriteResponseFunction,
      signature: const _FunctionSignature([_WasmValueType.i32]),
      locals: const [_WasmValueType.i64, _WasmValueType.i64],
      buildBody: (layout) {
        const contentType = 1;
        const body = 2;
        final code = _Instructions();
        code.localGet(0);
        code.i32Const(_GuestMemory.httpResponseRecord);
        code.i32NotEqual();
        _emitRuntimeErrorIf(code, layout);
        code.localGet(0);
        code.i64Load(offset: 8);
        code.localSet(contentType);
        code.localGet(0);
        code.i64Load(offset: 16);
        code.localSet(body);

        _storeI32(code, _GuestMemory.httpResponsePrefix, 0, _HttpWire.magic);
        _storeI32(
          code,
          _GuestMemory.httpResponsePrefix,
          4,
          _HttpWire.responsePrefix,
        );
        code.i32Const(_GuestMemory.httpResponsePrefix);
        code.localGet(0);
        code.i32Load();
        code.i32Store(offset: 8);
        _storeI32(code, _GuestMemory.httpResponsePrefix, 12, 1);
        code.i32Const(_GuestMemory.httpResponsePrefix);
        _emitBytesLength(code, body);
        code.i32Store(offset: 16);
        _storeI32(code, _GuestMemory.httpResponsePrefix, 20, 12);
        code.i32Const(_GuestMemory.httpResponsePrefix);
        _emitBytesLength(code, contentType);
        code.i32Store(offset: 24);
        _storeI32(code, _GuestMemory.httpResponsePrefix, 28, 0x746e6f63);
        _storeI32(code, _GuestMemory.httpResponsePrefix, 32, 0x2d746e65);
        _storeI32(code, _GuestMemory.httpResponsePrefix, 36, 0x65707974);

        code.i32Const(1);
        _emitPackedBytes(
          code,
          pointer: () => code.i32Const(_GuestMemory.httpResponsePrefix),
          length: () => code.i32Const(_HttpWire.responseFixedBytes),
        );
        code.call(layout.functionIndex(_writeFunction));
        code.i32Const(1);
        code.localGet(contentType);
        code.call(layout.functionIndex(_writeFunction));
        code.i32Const(1);
        code.localGet(body);
        code.call(layout.functionIndex(_writeFunction));
        return code.bytes;
      },
    );
  }

  void _emitI32FieldEquals(
    _Instructions code,
    _ModuleLayout layout,
    int pointer,
    int offset,
    int expected,
  ) {
    code.localGet(pointer);
    code.i32Load(offset: offset);
    code.i32Const(expected);
    code.i32NotEqual();
    _emitRuntimeErrorIf(code, layout);
  }

  void _emitFieldAtMost(
    _Instructions code,
    _ModuleLayout layout,
    int pointer,
    int offset,
    int maximum,
  ) {
    code.localGet(pointer);
    code.i32Load(offset: offset);
    code.i32Const(maximum);
    code.i32GreaterUnsigned();
    _emitRuntimeErrorIf(code, layout);
  }

  void _emitRequireRemaining(
    _Instructions code,
    _ModuleLayout layout,
    int cursor,
    int end,
    int requiredBytes,
  ) {
    code.localGet(cursor);
    code.i32Const(requiredBytes);
    code.i32Add();
    code.localGet(end);
    code.i32GreaterUnsigned();
    _emitRuntimeErrorIf(code, layout);
  }

  void _emitHeadersStart(_Instructions code, int requestLocal) {
    code.localGet(requestLocal);
    code.i32Const(_HttpWire.requestFixedBytes);
    code.i32Add();
    for (final offset in const [
      _HttpWire.requestMethodLengthOffset,
      _HttpWire.requestPathLengthOffset,
      _HttpWire.requestQueryLengthOffset,
    ]) {
      code.localGet(requestLocal);
      code.i32Load(offset: offset);
      code.i32Add();
    }
  }

  void _emitAdvanceHeader(_Instructions code, int cursor) {
    code.localGet(cursor);
    code.i32Const(8);
    code.i32Add();
    code.localGet(cursor);
    code.i32Load();
    code.i32Add();
    code.localGet(cursor);
    code.i32Load(offset: 4);
    code.i32Add();
    code.localSet(cursor);
  }

  void _storeI32(_Instructions code, int pointer, int offset, int value) {
    code.i32Const(pointer);
    code.i32Const(value);
    code.i32Store(offset: offset);
  }
}
