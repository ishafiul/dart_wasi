part of '../compiler.dart';

const String _wasiNamespace = 'wasi_snapshot_preview1';
const String _fdWriteImport = 'fd_write';
const String _fdReadImport = 'fd_read';
const String _argsSizesGetImport = 'args_sizes_get';
const String _argsGetImport = 'args_get';
const String _environSizesGetImport = 'environ_sizes_get';
const String _environGetImport = 'environ_get';
const String _procExitImport = 'proc_exit';

const String _startFunction = r'$_start';
const String _writeFunction = r'$_wasiWrite';
const String _readAllFunction = r'$_wasiReadAll';
const String _loadArgumentsFunction = r'$_wasiLoadArguments';
const String _argumentAtFunction = r'$_wasiArgumentAt';
const String _loadEnvironmentFunction = r'$_wasiLoadEnvironment';
const String _findEnvironmentFunction = r'$_wasiFindEnvironment';
const String _environmentContainsFunction = r'$_wasiEnvironmentContains';
const String _environmentValueOrFunction = r'$_wasiEnvironmentValueOr';
const String _checkedExitFunction = r'$_wasiCheckedExit';
const String _httpValidateRequestFunction = r'$_httpValidateRequest';
const String _httpRequestMethodFunction = r'$_httpRequestMethod';
const String _httpRequestPathFunction = r'$_httpRequestPath';
const String _httpRequestQueryFunction = r'$_httpRequestQuery';
const String _httpRequestBodyFunction = r'$_httpRequestBody';
const String _httpHeaderNameAtFunction = r'$_httpHeaderNameAt';
const String _httpHeaderValueAtFunction = r'$_httpHeaderValueAt';
const String _httpHeaderAtFunction = r'$_httpHeaderAt';
const String _httpCreateResponseFunction = r'$_httpCreateResponse';
const String _httpWriteResponseFunction = r'$_httpWriteResponse';

abstract final class _GuestMemory {
  static const int ioVector = 0;
  static const int ioCount = 8;
  static const int vectorCount = 12;
  static const int vectorBytes = 16;

  static const int httpResponseRecord = 64;
  static const int httpResponsePrefix = 96;

  static const int staticDataStart = 256;
  static const int staticDataLimit = 8192;

  static const int stdinBuffer = 8192;
  static const int maxStdinBytes = 16 * 1024;
  static const int stdinCapacity = maxStdinBytes + 1;

  static const int argumentPointers = 24580;
  static const int maxArgumentCount = 64;
  static const int argumentBuffer = 24836;
  static const int maxArgumentBytes = 8 * 1024;

  static const int environmentPointers = 33028;
  static const int maxEnvironmentCount = 64;
  static const int environmentBuffer = 33284;
  static const int maxEnvironmentBytes = 16 * 1024;

  static const int pageCount = 1;
}

final class _WasiModuleWriter {
  _WasiModuleWriter(this._program, this._semantics)
    : _usage = _WasiUsage.fromProgram(_program),
      _staticData = _StaticDataPool.fromProgram(_program);

  final _Program _program;
  final _ProgramSemantics _semantics;
  final _WasiUsage _usage;
  final _StaticDataPool _staticData;

  Uint8List write() {
    final imports = _buildImports();
    final functions = [
      _buildStartFunction(),
      ..._buildRuntimeFunctions(),
      ..._buildUserFunctions(),
    ];
    final layout = _ModuleLayout(imports, functions);
    final types = _TypeRegistry();
    for (final import in imports) {
      types.register(import.signature);
    }
    for (final function in functions) {
      types.register(function.signature);
    }

    final module = <int>[0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00];
    _appendSection(module, 0, [
      ..._wasmName('dart_wasi.sdk'),
      ..._unsignedLeb128(supportedDartWasiGuestApiVersion),
    ]);
    _appendSection(module, 1, types.encode());
    _appendSection(module, 2, _encodeImports(imports, types));
    _appendSection(module, 3, _encodeFunctionTypes(functions, types));
    _appendSection(module, 5, [1, 1, _GuestMemory.pageCount, 1]);
    _appendSection(module, 7, _encodeExports(layout));
    _appendSection(module, 10, _encodeCode(functions, layout));
    _appendSection(module, 11, _staticData.encodeDataSection());
    return Uint8List.fromList(module);
  }

  List<_ImportFunction> _buildImports() {
    const ioSignature = _FunctionSignature([
      _WasmValueType.i32,
      _WasmValueType.i32,
      _WasmValueType.i32,
      _WasmValueType.i32,
    ], _WasmValueType.i32);
    const pairToErrno = _FunctionSignature([
      _WasmValueType.i32,
      _WasmValueType.i32,
    ], _WasmValueType.i32);
    final imports = <_ImportFunction>[];
    if (_usage.writes) {
      imports.add(const _ImportFunction(_fdWriteImport, ioSignature));
    }
    if (_usage.readsStdin) {
      imports.add(const _ImportFunction(_fdReadImport, ioSignature));
    }
    if (_usage.readsArguments) {
      imports.add(const _ImportFunction(_argsSizesGetImport, pairToErrno));
      imports.add(const _ImportFunction(_argsGetImport, pairToErrno));
    }
    if (_usage.readsEnvironment) {
      imports.add(const _ImportFunction(_environSizesGetImport, pairToErrno));
      imports.add(const _ImportFunction(_environGetImport, pairToErrno));
    }
    imports.add(
      const _ImportFunction(
        _procExitImport,
        _FunctionSignature([_WasmValueType.i32]),
      ),
    );
    return imports;
  }

  _DefinedFunction _buildStartFunction() {
    return _DefinedFunction(
      name: _startFunction,
      signature: const _FunctionSignature([]),
      locals: const [],
      buildBody: (layout) {
        final code = _Instructions();
        if (_semantics.httpEntrypoint) {
          code.call(layout.functionIndex(_readAllFunction));
          code.call(layout.functionIndex(_httpValidateRequestFunction));
          code.call(layout.functionIndex('fetch'));
          code.call(layout.functionIndex(_httpWriteResponseFunction));
        } else {
          code.call(layout.functionIndex('main'));
        }
        code.i32Const(0);
        code.call(layout.functionIndex(_procExitImport));
        code.unreachable();
        return code.bytes;
      },
    );
  }

  List<_DefinedFunction> _buildRuntimeFunctions() {
    return [
      if (_usage.writes) _buildWriteFunction(),
      if (_usage.readsStdin) _buildReadAllFunction(),
      if (_usage.readsArguments) _buildLoadArgumentsFunction(),
      if (_usage.readsArgumentValue) _buildArgumentAtFunction(),
      if (_usage.readsEnvironment) _buildLoadEnvironmentFunction(),
      if (_usage.readsEnvironment) _buildFindEnvironmentFunction(),
      if (_usage.checksEnvironment) _buildEnvironmentContainsFunction(),
      if (_usage.readsEnvironmentValue) _buildEnvironmentValueOrFunction(),
      if (_usage.exits) _buildCheckedExitFunction(),
      if (_usage.httpWorker) ..._buildHttpRuntimeFunctions(),
    ];
  }

  List<_DefinedFunction> _buildUserFunctions() {
    return [
      for (final function in _program.functions)
        _DefinedFunction(
          name: function.name,
          signature: _signatureFor(function),
          locals: _userLocals(function),
          buildBody: (layout) => _UserFunctionWriter(
            function: function,
            semantics: _semantics.functions[function]!,
            program: _program,
            staticData: _staticData,
            layout: layout,
          ).write(),
        ),
    ];
  }

  List<_WasmValueType> _userLocals(_Function function) {
    final semantics = _semantics.functions[function]!;
    final entries =
        semantics.localIndices.entries
            .where((entry) => entry.value >= function.parameters.length)
            .toList()
          ..sort((left, right) => left.value.compareTo(right.value));
    return [
      for (final entry in entries)
        _wasmValueType(semantics.localTypes[entry.key]!),
    ];
  }

  List<int> _encodeImports(List<_ImportFunction> imports, _TypeRegistry types) {
    return [
      ..._unsignedLeb128(imports.length),
      for (final import in imports) ...[
        ..._wasmName(_wasiNamespace),
        ..._wasmName(import.name),
        0,
        ..._unsignedLeb128(types.register(import.signature)),
      ],
    ];
  }

  List<int> _encodeFunctionTypes(
    List<_DefinedFunction> functions,
    _TypeRegistry types,
  ) {
    return [
      ..._unsignedLeb128(functions.length),
      for (final function in functions)
        ..._unsignedLeb128(types.register(function.signature)),
    ];
  }

  List<int> _encodeExports(_ModuleLayout layout) {
    return [
      2,
      ..._wasmName('_start'),
      0,
      ..._unsignedLeb128(layout.functionIndex(_startFunction)),
      ..._wasmName('memory'),
      2,
      0,
    ];
  }

  List<int> _encodeCode(
    List<_DefinedFunction> functions,
    _ModuleLayout layout,
  ) {
    return [
      ..._unsignedLeb128(functions.length),
      for (final function in functions)
        ..._encodeFunctionBody(function.locals, function.buildBody(layout)),
    ];
  }

  _DefinedFunction _buildWriteFunction() {
    return _DefinedFunction(
      name: _writeFunction,
      signature: const _FunctionSignature([
        _WasmValueType.i32,
        _WasmValueType.i64,
      ]),
      locals: const [
        _WasmValueType.i32,
        _WasmValueType.i32,
        _WasmValueType.i32,
        _WasmValueType.i32,
      ],
      buildBody: (layout) {
        const pointer = 2;
        const remaining = 3;
        const written = 4;
        const errno = 5;
        final code = _Instructions();
        _emitBytesPointer(code, 1);
        code.localSet(pointer);
        _emitBytesLength(code, 1);
        code.localSet(remaining);

        code.block();
        code.loop();
        code.localGet(remaining);
        code.i32EqualZero();
        code.branchIf(1);

        _emitIovec(code, pointer, remaining);
        code.localGet(0);
        code.i32Const(_GuestMemory.ioVector);
        code.i32Const(1);
        code.i32Const(_GuestMemory.ioCount);
        code.call(layout.functionIndex(_fdWriteImport));
        code.localSet(errno);
        _emitErrnoCheck(code, layout, errno);

        code.i32Const(_GuestMemory.ioCount);
        code.i32Load();
        code.localSet(written);
        code.localGet(written);
        code.i32EqualZero();
        _emitRuntimeErrorIf(code, layout);
        code.localGet(written);
        code.localGet(remaining);
        code.i32GreaterUnsigned();
        _emitRuntimeErrorIf(code, layout);

        code.localGet(pointer);
        code.localGet(written);
        code.i32Add();
        code.localSet(pointer);
        code.localGet(remaining);
        code.localGet(written);
        code.i32Subtract();
        code.localSet(remaining);
        code.branch(0);
        code.end();
        code.end();
        return code.bytes;
      },
    );
  }

  _DefinedFunction _buildReadAllFunction() {
    return _DefinedFunction(
      name: _readAllFunction,
      signature: const _FunctionSignature([], _WasmValueType.i64),
      locals: const [
        _WasmValueType.i32,
        _WasmValueType.i32,
        _WasmValueType.i32,
      ],
      buildBody: (layout) {
        const total = 0;
        const read = 1;
        const errno = 2;
        final code = _Instructions();
        code.i32Const(0);
        code.localSet(total);

        code.block();
        code.loop();
        code.i32Const(_GuestMemory.ioVector);
        code.i32Const(_GuestMemory.stdinBuffer);
        code.localGet(total);
        code.i32Add();
        code.i32Store();
        code.i32Const(_GuestMemory.ioVector);
        code.i32Const(_GuestMemory.stdinCapacity);
        code.localGet(total);
        code.i32Subtract();
        code.i32Store(offset: 4);

        code.i32Const(0);
        code.i32Const(_GuestMemory.ioVector);
        code.i32Const(1);
        code.i32Const(_GuestMemory.ioCount);
        code.call(layout.functionIndex(_fdReadImport));
        code.localSet(errno);
        _emitErrnoCheck(code, layout, errno);

        code.i32Const(_GuestMemory.ioCount);
        code.i32Load();
        code.localSet(read);
        code.localGet(read);
        code.i32EqualZero();
        code.branchIf(1);
        code.localGet(total);
        code.localGet(read);
        code.i32Add();
        code.localTee(total);
        code.i32Const(_GuestMemory.maxStdinBytes);
        code.i32GreaterUnsigned();
        _emitRuntimeErrorIf(code, layout);
        code.branch(0);
        code.end();
        code.end();

        _emitPackedBytes(
          code,
          pointer: () => code.i32Const(_GuestMemory.stdinBuffer),
          length: () => code.localGet(total),
        );
        return code.bytes;
      },
    );
  }

  _DefinedFunction _buildLoadArgumentsFunction() {
    return _DefinedFunction(
      name: _loadArgumentsFunction,
      signature: const _FunctionSignature([], _WasmValueType.i32),
      locals: const [
        _WasmValueType.i32,
        _WasmValueType.i32,
        _WasmValueType.i32,
      ],
      buildBody: (layout) {
        const count = 0;
        const byteCount = 1;
        const errno = 2;
        final code = _Instructions();
        code.i32Const(_GuestMemory.vectorCount);
        code.i32Const(_GuestMemory.vectorBytes);
        code.call(layout.functionIndex(_argsSizesGetImport));
        code.localSet(errno);
        _emitErrnoCheck(code, layout, errno);

        code.i32Const(_GuestMemory.vectorCount);
        code.i32Load();
        code.localTee(count);
        code.i32Const(_GuestMemory.maxArgumentCount);
        code.i32GreaterUnsigned();
        _emitRuntimeErrorIf(code, layout);
        code.i32Const(_GuestMemory.vectorBytes);
        code.i32Load();
        code.localTee(byteCount);
        code.i32Const(_GuestMemory.maxArgumentBytes);
        code.i32GreaterUnsigned();
        _emitRuntimeErrorIf(code, layout);

        code.i32Const(_GuestMemory.argumentPointers);
        code.i32Const(_GuestMemory.argumentBuffer);
        code.call(layout.functionIndex(_argsGetImport));
        code.localSet(errno);
        _emitErrnoCheck(code, layout, errno);
        code.localGet(count);
        return code.bytes;
      },
    );
  }

  _DefinedFunction _buildArgumentAtFunction() {
    return _DefinedFunction(
      name: _argumentAtFunction,
      signature: const _FunctionSignature([
        _WasmValueType.i32,
      ], _WasmValueType.i64),
      locals: const [
        _WasmValueType.i32,
        _WasmValueType.i32,
        _WasmValueType.i32,
        _WasmValueType.i32,
      ],
      buildBody: (layout) {
        const count = 1;
        const pointer = 2;
        const cursor = 3;
        const end = 4;
        final code = _Instructions();
        code.call(layout.functionIndex(_loadArgumentsFunction));
        code.localSet(count);
        code.localGet(0);
        code.i32Const(0);
        code.i32LessSigned();
        _emitRuntimeErrorIf(code, layout);
        code.localGet(0);
        code.localGet(count);
        code.i32GreaterEqualUnsigned();
        _emitRuntimeErrorIf(code, layout);

        code.i32Const(_GuestMemory.argumentPointers);
        code.localGet(0);
        code.i32Const(4);
        code.i32Multiply();
        code.i32Add();
        code.i32Load();
        code.localTee(pointer);
        code.i32Const(_GuestMemory.argumentBuffer);
        code.i32LessUnsigned();
        _emitRuntimeErrorIf(code, layout);
        code.i32Const(_GuestMemory.argumentBuffer);
        code.i32Const(_GuestMemory.vectorBytes);
        code.i32Load();
        code.i32Add();
        code.localTee(end);
        code.localGet(pointer);
        code.i32LessEqualUnsigned();
        _emitRuntimeErrorIf(code, layout);

        code.localGet(pointer);
        code.localSet(cursor);
        _emitNullTerminatedScan(code, layout, cursor, end);
        _emitPackedBytes(
          code,
          pointer: () => code.localGet(pointer),
          length: () {
            code.localGet(cursor);
            code.localGet(pointer);
            code.i32Subtract();
          },
        );
        return code.bytes;
      },
    );
  }

  _DefinedFunction _buildLoadEnvironmentFunction() {
    return _DefinedFunction(
      name: _loadEnvironmentFunction,
      signature: const _FunctionSignature([], _WasmValueType.i32),
      locals: const [
        _WasmValueType.i32,
        _WasmValueType.i32,
        _WasmValueType.i32,
      ],
      buildBody: (layout) {
        const count = 0;
        const byteCount = 1;
        const errno = 2;
        final code = _Instructions();
        code.i32Const(_GuestMemory.vectorCount);
        code.i32Const(_GuestMemory.vectorBytes);
        code.call(layout.functionIndex(_environSizesGetImport));
        code.localSet(errno);
        _emitErrnoCheck(code, layout, errno);

        code.i32Const(_GuestMemory.vectorCount);
        code.i32Load();
        code.localTee(count);
        code.i32Const(_GuestMemory.maxEnvironmentCount);
        code.i32GreaterUnsigned();
        _emitRuntimeErrorIf(code, layout);
        code.i32Const(_GuestMemory.vectorBytes);
        code.i32Load();
        code.localTee(byteCount);
        code.i32Const(_GuestMemory.maxEnvironmentBytes);
        code.i32GreaterUnsigned();
        _emitRuntimeErrorIf(code, layout);

        code.i32Const(_GuestMemory.environmentPointers);
        code.i32Const(_GuestMemory.environmentBuffer);
        code.call(layout.functionIndex(_environGetImport));
        code.localSet(errno);
        _emitErrnoCheck(code, layout, errno);
        code.localGet(count);
        return code.bytes;
      },
    );
  }

  _DefinedFunction _buildFindEnvironmentFunction() {
    return _DefinedFunction(
      name: _findEnvironmentFunction,
      signature: const _FunctionSignature([
        _WasmValueType.i64,
      ], _WasmValueType.i64),
      locals: const [
        _WasmValueType.i32,
        _WasmValueType.i32,
        _WasmValueType.i32,
        _WasmValueType.i32,
        _WasmValueType.i32,
        _WasmValueType.i32,
        _WasmValueType.i32,
        _WasmValueType.i32,
        _WasmValueType.i32,
        _WasmValueType.i32,
        _WasmValueType.i32,
        _WasmValueType.i32,
      ],
      buildBody: (layout) {
        const count = 1;
        const byteCount = 2;
        const namePointer = 3;
        const nameLength = 4;
        const index = 5;
        const entryPointer = 6;
        const cursor = 7;
        const keyLength = 8;
        const compareIndex = 9;
        const matches = 10;
        const valuePointer = 11;
        const end = 12;
        final code = _Instructions();

        code.call(layout.functionIndex(_loadEnvironmentFunction));
        code.localSet(count);
        code.i32Const(_GuestMemory.vectorBytes);
        code.i32Load();
        code.localTee(byteCount);
        code.i32Const(_GuestMemory.environmentBuffer);
        code.i32Add();
        code.localSet(end);
        _emitBytesPointer(code, 0);
        code.localSet(namePointer);
        _emitBytesLength(code, 0);
        code.localSet(nameLength);
        code.i32Const(0);
        code.localSet(index);

        code.block();
        code.loop();
        code.localGet(index);
        code.localGet(count);
        code.i32GreaterEqualUnsigned();
        code.branchIf(1);

        code.i32Const(_GuestMemory.environmentPointers);
        code.localGet(index);
        code.i32Const(4);
        code.i32Multiply();
        code.i32Add();
        code.i32Load();
        code.localTee(entryPointer);
        code.i32Const(_GuestMemory.environmentBuffer);
        code.i32LessUnsigned();
        _emitRuntimeErrorIf(code, layout);
        code.localGet(entryPointer);
        code.localGet(end);
        code.i32GreaterEqualUnsigned();
        _emitRuntimeErrorIf(code, layout);
        code.localGet(entryPointer);
        code.localSet(cursor);

        code.block();
        code.loop();
        code.localGet(cursor);
        code.localGet(end);
        code.i32GreaterEqualUnsigned();
        _emitRuntimeErrorIf(code, layout);
        code.localGet(cursor);
        code.i32Load8Unsigned();
        code.i32Const(61);
        code.i32Equal();
        code.branchIf(1);
        code.localGet(cursor);
        code.i32Load8Unsigned();
        code.i32EqualZero();
        _emitRuntimeErrorIf(code, layout);
        code.localGet(cursor);
        code.i32Const(1);
        code.i32Add();
        code.localSet(cursor);
        code.branch(0);
        code.end();
        code.end();

        code.localGet(cursor);
        code.localGet(entryPointer);
        code.i32Subtract();
        code.localSet(keyLength);
        code.localGet(keyLength);
        code.localGet(nameLength);
        code.i32Equal();
        code.ifVoid();
        code.i32Const(1);
        code.localSet(matches);
        code.i32Const(0);
        code.localSet(compareIndex);
        code.block();
        code.loop();
        code.localGet(compareIndex);
        code.localGet(keyLength);
        code.i32GreaterEqualUnsigned();
        code.branchIf(1);
        code.localGet(entryPointer);
        code.localGet(compareIndex);
        code.i32Add();
        code.i32Load8Unsigned();
        code.localGet(namePointer);
        code.localGet(compareIndex);
        code.i32Add();
        code.i32Load8Unsigned();
        code.i32NotEqual();
        code.ifVoid();
        code.i32Const(0);
        code.localSet(matches);
        code.branch(2);
        code.end();
        code.localGet(compareIndex);
        code.i32Const(1);
        code.i32Add();
        code.localSet(compareIndex);
        code.branch(0);
        code.end();
        code.end();

        code.localGet(matches);
        code.ifVoid();
        code.localGet(cursor);
        code.i32Const(1);
        code.i32Add();
        code.localTee(valuePointer);
        code.localSet(cursor);
        _emitNullTerminatedScan(code, layout, cursor, end);
        _emitPackedBytes(
          code,
          pointer: () => code.localGet(valuePointer),
          length: () {
            code.localGet(cursor);
            code.localGet(valuePointer);
            code.i32Subtract();
          },
        );
        code.returnValue();
        code.end();
        code.end();

        code.localGet(index);
        code.i32Const(1);
        code.i32Add();
        code.localSet(index);
        code.branch(0);
        code.end();
        code.end();
        code.i64Const(-1);
        return code.bytes;
      },
    );
  }

  _DefinedFunction _buildEnvironmentContainsFunction() {
    return _DefinedFunction(
      name: _environmentContainsFunction,
      signature: const _FunctionSignature([
        _WasmValueType.i64,
      ], _WasmValueType.i32),
      locals: const [],
      buildBody: (layout) {
        final code = _Instructions();
        code.localGet(0);
        code.call(layout.functionIndex(_findEnvironmentFunction));
        code.i64Const(-1);
        code.i64Equal();
        code.i32EqualZero();
        return code.bytes;
      },
    );
  }

  _DefinedFunction _buildEnvironmentValueOrFunction() {
    return _DefinedFunction(
      name: _environmentValueOrFunction,
      signature: const _FunctionSignature([
        _WasmValueType.i64,
        _WasmValueType.i64,
      ], _WasmValueType.i64),
      locals: const [_WasmValueType.i64],
      buildBody: (layout) {
        const found = 2;
        final code = _Instructions();
        code.localGet(0);
        code.call(layout.functionIndex(_findEnvironmentFunction));
        code.localTee(found);
        code.i64Const(-1);
        code.i64Equal();
        code.ifResult(_WasmValueType.i64);
        code.localGet(1);
        code.elseClause();
        code.localGet(found);
        code.end();
        return code.bytes;
      },
    );
  }

  _DefinedFunction _buildCheckedExitFunction() {
    return _DefinedFunction(
      name: _checkedExitFunction,
      signature: const _FunctionSignature([_WasmValueType.i32]),
      locals: const [],
      buildBody: (layout) {
        final code = _Instructions();
        code.localGet(0);
        code.i32Const(0);
        code.i32LessSigned();
        _emitRuntimeErrorIf(code, layout);
        code.localGet(0);
        code.i32Const(255);
        code.i32GreaterSigned();
        _emitRuntimeErrorIf(code, layout);
        code.localGet(0);
        code.call(layout.functionIndex(_procExitImport));
        code.unreachable();
        return code.bytes;
      },
    );
  }

  void _emitIovec(_Instructions code, int pointer, int length) {
    code.i32Const(_GuestMemory.ioVector);
    code.localGet(pointer);
    code.i32Store();
    code.i32Const(_GuestMemory.ioVector);
    code.localGet(length);
    code.i32Store(offset: 4);
  }

  void _emitErrnoCheck(_Instructions code, _ModuleLayout layout, int errno) {
    code.localGet(errno);
    code.ifVoid();
    code.localGet(errno);
    code.call(layout.functionIndex(_procExitImport));
    code.unreachable();
    code.end();
  }

  void _emitRuntimeErrorIf(_Instructions code, _ModuleLayout layout) {
    code.ifVoid();
    code.i32Const(dartWasiGuestRuntimeErrorExitCode);
    code.call(layout.functionIndex(_procExitImport));
    code.unreachable();
    code.end();
  }

  void _emitNullTerminatedScan(
    _Instructions code,
    _ModuleLayout layout,
    int cursor,
    int end,
  ) {
    code.block();
    code.loop();
    code.localGet(cursor);
    code.localGet(end);
    code.i32GreaterEqualUnsigned();
    _emitRuntimeErrorIf(code, layout);
    code.localGet(cursor);
    code.i32Load8Unsigned();
    code.i32EqualZero();
    code.branchIf(1);
    code.localGet(cursor);
    code.i32Const(1);
    code.i32Add();
    code.localSet(cursor);
    code.branch(0);
    code.end();
    code.end();
  }

  void _emitBytesPointer(_Instructions code, int local) {
    code.localGet(local);
    code.i32WrapI64();
  }

  void _emitBytesLength(_Instructions code, int local) {
    code.localGet(local);
    code.i64Const(32);
    code.i64ShiftRightUnsigned();
    code.i32WrapI64();
  }

  void _emitPackedBytes(
    _Instructions code, {
    required void Function() pointer,
    required void Function() length,
  }) {
    pointer();
    code.i64ExtendI32Unsigned();
    length();
    code.i64ExtendI32Unsigned();
    code.i64Const(32);
    code.i64ShiftLeft();
    code.i64Or();
  }
}

final class _WasiUsage {
  _WasiUsage.fromProgram(_Program program)
    : httpWorker = program.functions.any(
        (function) => function.name == 'fetch',
      ) {
    for (final function in program.functions) {
      _visitStatements(function.body);
    }
  }

  final Set<_WasiIntrinsic> intrinsics = {};
  final bool httpWorker;

  bool get writes =>
      httpWorker ||
      intrinsics.any(
        const {
          _WasiIntrinsic.stdoutWriteConstant,
          _WasiIntrinsic.stdoutWriteBytes,
          _WasiIntrinsic.stderrWriteConstant,
          _WasiIntrinsic.stderrWriteBytes,
        }.contains,
      );
  bool get readsStdin =>
      httpWorker || intrinsics.contains(_WasiIntrinsic.stdinReadAll);
  bool get readsArguments =>
      readsArgumentValue || intrinsics.contains(_WasiIntrinsic.argumentsLength);
  bool get readsArgumentValue => intrinsics.contains(_WasiIntrinsic.argumentAt);
  bool get readsEnvironment => checksEnvironment || readsEnvironmentValue;
  bool get checksEnvironment =>
      intrinsics.contains(_WasiIntrinsic.environmentContains);
  bool get readsEnvironmentValue =>
      intrinsics.contains(_WasiIntrinsic.environmentValueOr);
  bool get exits => intrinsics.contains(_WasiIntrinsic.exit);

  void _visitStatements(List<_Statement> statements) {
    for (final statement in statements) {
      switch (statement) {
        case _VariableStatement(:final value):
          _visitExpression(value);
        case _AssignStatement(:final value):
          _visitExpression(value);
        case _ExpressionStatement(:final value):
          _visitExpression(value);
        case _ReturnStatement(:final value):
          if (value != null) {
            _visitExpression(value);
          }
        case _IfStatement(:final condition, :final thenBody, :final elseBody):
          _visitExpression(condition);
          _visitStatements(thenBody);
          if (elseBody != null) {
            _visitStatements(elseBody);
          }
        case _WhileStatement(:final condition, :final body):
          _visitExpression(condition);
          _visitStatements(body);
      }
    }
  }

  void _visitExpression(_Expression expression) {
    switch (expression) {
      case _CallExpression(:final arguments):
        for (final argument in arguments) {
          _visitExpression(argument);
        }
      case _MemberExpression(:final receiver, :final arguments):
        _visitExpression(receiver);
        if (arguments != null) {
          for (final argument in arguments) {
            _visitExpression(argument);
          }
        }
      case _UnaryExpression(:final value):
        _visitExpression(value);
      case _BinaryExpression(:final left, :final right):
        _visitExpression(left);
        _visitExpression(right);
      case _IntrinsicExpression(:final intrinsic, :final arguments):
        intrinsics.add(intrinsic);
        for (final argument in arguments) {
          _visitExpression(argument);
        }
      default:
        break;
    }
  }
}

final class _StaticData {
  const _StaticData(this.offset, this.bytes);

  final int offset;
  final List<int> bytes;
}

final class _StaticDataPool {
  _StaticDataPool._();

  factory _StaticDataPool.fromProgram(_Program program) {
    final pool = _StaticDataPool._();
    for (final function in program.functions) {
      pool._visitStatements(function.body);
    }
    return pool;
  }

  final Map<String, _StaticData> _entries = {};
  var _nextOffset = _GuestMemory.staticDataStart;

  _StaticData value(String text) {
    return _entries[text] ??
        _unsupported('Internal compiler error: missing static data.');
  }

  List<int> encodeDataSection() {
    final entries = _entries.values.toList()
      ..sort((left, right) => left.offset.compareTo(right.offset));
    return [
      ..._unsignedLeb128(entries.length),
      for (final entry in entries) ...[
        0,
        0x41,
        ..._signedLeb128(entry.offset),
        0x0b,
        ..._unsignedLeb128(entry.bytes.length),
        ...entry.bytes,
      ],
    ];
  }

  void _add(String text) {
    if (_entries.containsKey(text)) {
      return;
    }
    final bytes = utf8.encode(text);
    final end = _nextOffset + bytes.length;
    if (end > _GuestMemory.staticDataLimit) {
      _unsupported(
        'Compile-time strings exceed the '
        '${_GuestMemory.staticDataLimit - _GuestMemory.staticDataStart} byte '
        'guest limit.',
      );
    }
    _entries[text] = _StaticData(_nextOffset, List.unmodifiable(bytes));
    _nextOffset = end;
  }

  void _visitStatements(List<_Statement> statements) {
    for (final statement in statements) {
      switch (statement) {
        case _VariableStatement(:final value):
          _visitExpression(value);
        case _AssignStatement(:final value):
          _visitExpression(value);
        case _ExpressionStatement(:final value):
          _visitExpression(value);
        case _ReturnStatement(:final value):
          if (value != null) {
            _visitExpression(value);
          }
        case _IfStatement(:final condition, :final thenBody, :final elseBody):
          _visitExpression(condition);
          _visitStatements(thenBody);
          if (elseBody != null) {
            _visitStatements(elseBody);
          }
        case _WhileStatement(:final condition, :final body):
          _visitExpression(condition);
          _visitStatements(body);
      }
    }
  }

  void _visitExpression(_Expression expression) {
    switch (expression) {
      case _CallExpression(:final arguments):
        for (final argument in arguments) {
          _visitExpression(argument);
        }
      case _MemberExpression(:final receiver, :final arguments):
        _visitExpression(receiver);
        if (arguments != null) {
          for (final argument in arguments) {
            _visitExpression(argument);
          }
        }
      case _UnaryExpression(:final value):
        _visitExpression(value);
      case _BinaryExpression(:final left, :final right):
        _visitExpression(left);
        _visitExpression(right);
      case _IntrinsicExpression(
        :final intrinsic,
        :final arguments,
        :final stringArguments,
      ):
        if (intrinsic == _WasiIntrinsic.environmentContains ||
            intrinsic == _WasiIntrinsic.environmentValueOr) {
          _validateEnvironmentName(stringArguments.first);
        }
        if (intrinsic == _WasiIntrinsic.httpResponseJson) {
          _add('application/json');
        } else if (intrinsic == _WasiIntrinsic.httpResponseText) {
          _add('text/plain; charset=utf-8');
        } else if (intrinsic == _WasiIntrinsic.httpResponseBinary) {
          _validateHttpContentType(stringArguments.single);
        }
        for (final value in stringArguments) {
          _add(value);
        }
        for (final argument in arguments) {
          _visitExpression(argument);
        }
      default:
        break;
    }
  }

  void _validateEnvironmentName(String name) {
    if (name.isEmpty || name.contains('=') || name.contains('\u0000')) {
      _unsupported(
        'Environment names must be non-empty and cannot contain = or NUL.',
      );
    }
  }

  void _validateHttpContentType(String value) {
    final byteLength = utf8.encode(value).length;
    if (byteLength == 0 ||
        byteLength > _HttpWire.maximumResponseContentTypeBytes ||
        value.contains('\r') ||
        value.contains('\n') ||
        value.contains('\u0000')) {
      _unsupported(
        'HTTP content type must contain 1 through '
        '${_HttpWire.maximumResponseContentTypeBytes} UTF-8 bytes and cannot '
        'contain CR, LF, or NUL.',
      );
    }
  }
}

final class _UserFunctionWriter {
  _UserFunctionWriter({
    required this.function,
    required this.semantics,
    required _Program program,
    required this.staticData,
    required this.layout,
  }) : _functions = {for (final value in program.functions) value.name: value};

  final _Function function;
  final _FunctionSemantics semantics;
  final _StaticDataPool staticData;
  final _ModuleLayout layout;
  final Map<String, _Function> _functions;

  List<int> write() {
    final code = _Instructions();
    for (final statement in function.body) {
      _writeStatement(code, statement);
    }
    return code.bytes;
  }

  void _writeStatement(_Instructions code, _Statement statement) {
    switch (statement) {
      case _VariableStatement(:final name, :final value):
        _writeExpression(code, value);
        code.localSet(semantics.localIndices[name]!);
      case _AssignStatement(:final name, :final value):
        _writeExpression(code, value);
        code.localSet(semantics.localIndices[name]!);
      case _ExpressionStatement(:final value):
        _writeExpression(code, value);
        final type = _expressionType(value);
        if (type != _Type.voidType && type != _Type.neverType) {
          code.drop();
        }
      case _ReturnStatement(:final value):
        if (value != null) {
          _writeExpression(code, value);
        }
        code.returnValue();
      case _IfStatement(:final condition, :final thenBody, :final elseBody):
        _writeExpression(code, condition);
        code.ifVoid();
        for (final child in thenBody) {
          _writeStatement(code, child);
        }
        if (elseBody != null) {
          code.elseClause();
          for (final child in elseBody) {
            _writeStatement(code, child);
          }
        }
        code.end();
      case _WhileStatement(:final condition, :final body):
        code.block();
        code.loop();
        _writeExpression(code, condition);
        code.i32EqualZero();
        code.branchIf(1);
        for (final child in body) {
          _writeStatement(code, child);
        }
        code.branch(0);
        code.end();
        code.end();
    }
  }

  void _writeExpression(_Instructions code, _Expression expression) {
    switch (expression) {
      case _NumberExpression(:final value):
        code.i32Const(value);
      case _BooleanExpression(:final value):
        code.i32Const(value ? 1 : 0);
      case _VariableExpression(:final name):
        code.localGet(semantics.localIndices[name]!);
      case _CallExpression(:final name, :final arguments):
        for (final argument in arguments) {
          _writeExpression(code, argument);
        }
        code.call(layout.functionIndex(name));
      case _MemberExpression():
        _writeMember(code, expression);
      case _UnaryExpression(:final operator, :final value):
        if (operator == '-') {
          code.i32Const(0);
        }
        _writeExpression(code, value);
        if (operator == '-') {
          code.i32Subtract();
        } else {
          code.i32EqualZero();
        }
      case _BinaryExpression(:final left, :final operator, :final right):
        _writeBinary(code, left, operator, right);
      case _IntrinsicExpression():
        _writeIntrinsic(code, expression);
    }
  }

  void _writeMember(_Instructions code, _MemberExpression expression) {
    _writeExpression(code, expression.receiver);
    switch (expression.member) {
      case 'method':
        code.call(layout.functionIndex(_httpRequestMethodFunction));
      case 'path':
        code.call(layout.functionIndex(_httpRequestPathFunction));
      case 'query':
        code.call(layout.functionIndex(_httpRequestQueryFunction));
      case 'body':
        code.call(layout.functionIndex(_httpRequestBodyFunction));
      case 'headerCount':
        code.i32Load(offset: _HttpWire.requestHeaderCountOffset);
      case 'headerNameAt':
        _writeExpression(code, expression.arguments!.single);
        code.call(layout.functionIndex(_httpHeaderNameAtFunction));
      case 'headerValueAt':
        _writeExpression(code, expression.arguments!.single);
        code.call(layout.functionIndex(_httpHeaderValueAtFunction));
      default:
        _unsupported('Internal compiler error: unknown request member.');
    }
  }

  void _writeBinary(
    _Instructions code,
    _Expression left,
    String operator,
    _Expression right,
  ) {
    if (operator == '&&') {
      _writeExpression(code, left);
      code.ifResult(_WasmValueType.i32);
      _writeExpression(code, right);
      code.elseClause();
      code.i32Const(0);
      code.end();
      return;
    }
    if (operator == '||') {
      _writeExpression(code, left);
      code.ifResult(_WasmValueType.i32);
      code.i32Const(1);
      code.elseClause();
      _writeExpression(code, right);
      code.end();
      return;
    }
    _writeExpression(code, left);
    _writeExpression(code, right);
    switch (operator) {
      case '+':
        code.i32Add();
      case '-':
        code.i32Subtract();
      case '*':
        code.i32Multiply();
      case '/':
        code.i32DivideSigned();
      case '==':
        code.i32Equal();
      case '!=':
        code.i32NotEqual();
      case '<':
        code.i32LessSigned();
      case '>':
        code.i32GreaterSigned();
      case '<=':
        code.i32LessEqualSigned();
      case '>=':
        code.i32GreaterEqualSigned();
      default:
        _unsupported('Internal compiler error: unsupported operator.');
    }
  }

  void _writeIntrinsic(_Instructions code, _IntrinsicExpression expression) {
    switch (expression.intrinsic) {
      case _WasiIntrinsic.stdoutWriteConstant:
        _writeConstant(code, 1, expression.stringArguments.single);
      case _WasiIntrinsic.stdoutWriteBytes:
        _writeBytes(code, 1, expression.arguments.single);
      case _WasiIntrinsic.stderrWriteConstant:
        _writeConstant(code, 2, expression.stringArguments.single);
      case _WasiIntrinsic.stderrWriteBytes:
        _writeBytes(code, 2, expression.arguments.single);
      case _WasiIntrinsic.stdinReadAll:
        code.call(layout.functionIndex(_readAllFunction));
      case _WasiIntrinsic.argumentsLength:
        code.call(layout.functionIndex(_loadArgumentsFunction));
      case _WasiIntrinsic.argumentAt:
        _writeExpression(code, expression.arguments.single);
        code.call(layout.functionIndex(_argumentAtFunction));
      case _WasiIntrinsic.environmentContains:
        _writeStaticBytes(code, expression.stringArguments.single);
        code.call(layout.functionIndex(_environmentContainsFunction));
      case _WasiIntrinsic.environmentValueOr:
        _writeStaticBytes(code, expression.stringArguments[0]);
        _writeStaticBytes(code, expression.stringArguments[1]);
        code.call(layout.functionIndex(_environmentValueOrFunction));
      case _WasiIntrinsic.httpResponseJson:
        _writeHttpResponse(
          code,
          status: expression.arguments.single,
          contentType: 'application/json',
          bodyText: expression.stringArguments.single,
        );
      case _WasiIntrinsic.httpResponseText:
        _writeHttpResponse(
          code,
          status: expression.arguments.single,
          contentType: 'text/plain; charset=utf-8',
          bodyText: expression.stringArguments.single,
        );
      case _WasiIntrinsic.httpResponseBinary:
        _writeHttpResponse(
          code,
          status: expression.arguments[0],
          contentType: expression.stringArguments.single,
          body: expression.arguments[1],
        );
      case _WasiIntrinsic.exit:
        _writeExpression(code, expression.arguments.single);
        code.call(layout.functionIndex(_checkedExitFunction));
        code.unreachable();
    }
  }

  void _writeHttpResponse(
    _Instructions code, {
    required _Expression status,
    required String contentType,
    String? bodyText,
    _Expression? body,
  }) {
    _writeExpression(code, status);
    _writeStaticBytes(code, contentType);
    if (bodyText != null) {
      _writeStaticBytes(code, bodyText);
    } else {
      _writeExpression(code, body!);
    }
    code.call(layout.functionIndex(_httpCreateResponseFunction));
  }

  void _writeConstant(_Instructions code, int descriptor, String value) {
    code.i32Const(descriptor);
    _writeStaticBytes(code, value);
    code.call(layout.functionIndex(_writeFunction));
  }

  void _writeBytes(_Instructions code, int descriptor, _Expression value) {
    code.i32Const(descriptor);
    _writeExpression(code, value);
    code.call(layout.functionIndex(_writeFunction));
  }

  void _writeStaticBytes(_Instructions code, String value) {
    final data = staticData.value(value);
    code.i32Const(data.offset);
    code.i64ExtendI32Unsigned();
    code.i32Const(data.bytes.length);
    code.i64ExtendI32Unsigned();
    code.i64Const(32);
    code.i64ShiftLeft();
    code.i64Or();
  }

  _Type _expressionType(_Expression expression) => switch (expression) {
    _NumberExpression() => _Type.intType,
    _BooleanExpression() => _Type.boolType,
    _VariableExpression(:final name) => semantics.localTypes[name]!,
    _CallExpression(:final name) => _functions[name]!.returnType,
    _MemberExpression(:final member) => switch (member) {
      'headerCount' => _Type.intType,
      _ => _Type.bytesType,
    },
    _UnaryExpression(operator: '!') => _Type.boolType,
    _UnaryExpression() => _Type.intType,
    _BinaryExpression(operator: '==' || '!=' || '<' || '>' || '<=' || '>=') =>
      _Type.boolType,
    _BinaryExpression(operator: '&&' || '||') => _Type.boolType,
    _BinaryExpression() => _Type.intType,
    _IntrinsicExpression(:final intrinsic) => switch (intrinsic) {
      _WasiIntrinsic.stdoutWriteConstant ||
      _WasiIntrinsic.stdoutWriteBytes ||
      _WasiIntrinsic.stderrWriteConstant ||
      _WasiIntrinsic.stderrWriteBytes => _Type.voidType,
      _WasiIntrinsic.stdinReadAll ||
      _WasiIntrinsic.argumentAt ||
      _WasiIntrinsic.environmentValueOr => _Type.bytesType,
      _WasiIntrinsic.argumentsLength => _Type.intType,
      _WasiIntrinsic.environmentContains => _Type.boolType,
      _WasiIntrinsic.httpResponseJson ||
      _WasiIntrinsic.httpResponseText ||
      _WasiIntrinsic.httpResponseBinary => _Type.httpResponseType,
      _WasiIntrinsic.exit => _Type.neverType,
    },
  };
}
