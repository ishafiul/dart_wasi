part of '../compiler.dart';

enum _WasmValueType {
  i32(0x7f),
  i64(0x7e);

  const _WasmValueType(this.code);

  final int code;
}

final class _FunctionSignature {
  const _FunctionSignature(this.parameters, [this.result]);

  final List<_WasmValueType> parameters;
  final _WasmValueType? result;

  String get key =>
      '${parameters.map((type) => type.code).join(',')}:'
      '${result?.code ?? ''}';
}

final class _TypeRegistry {
  final List<_FunctionSignature> _types = [];
  final Map<String, int> _indices = {};

  int register(_FunctionSignature signature) {
    return _indices.putIfAbsent(signature.key, () {
      _types.add(signature);
      return _types.length - 1;
    });
  }

  List<int> encode() {
    return [
      ..._unsignedLeb128(_types.length),
      for (final type in _types) ...[
        0x60,
        ..._unsignedLeb128(type.parameters.length),
        for (final parameter in type.parameters) parameter.code,
        if (type.result == null) 0 else 1,
        if (type.result != null) type.result!.code,
      ],
    ];
  }
}

final class _ImportFunction {
  const _ImportFunction(this.name, this.signature);

  final String name;
  final _FunctionSignature signature;
}

typedef _FunctionBodyBuilder = List<int> Function(_ModuleLayout layout);

final class _DefinedFunction {
  const _DefinedFunction({
    required this.name,
    required this.signature,
    required this.locals,
    required this.buildBody,
  });

  final String name;
  final _FunctionSignature signature;
  final List<_WasmValueType> locals;
  final _FunctionBodyBuilder buildBody;
}

final class _ModuleLayout {
  _ModuleLayout(this.imports, this.functions)
    : _functionIndices = {
        for (var index = 0; index < imports.length; index++)
          imports[index].name: index,
        for (var index = 0; index < functions.length; index++)
          functions[index].name: imports.length + index,
      };

  final List<_ImportFunction> imports;
  final List<_DefinedFunction> functions;
  final Map<String, int> _functionIndices;

  int functionIndex(String name) {
    return _functionIndices[name] ??
        _unsupported('Internal compiler error: unknown function "$name".');
  }
}

final class _Instructions {
  final List<int> bytes = [];

  void unreachable() => bytes.add(0x00);
  void block() => bytes.addAll([0x02, 0x40]);
  void loop() => bytes.addAll([0x03, 0x40]);
  void ifVoid() => bytes.addAll([0x04, 0x40]);
  void ifResult(_WasmValueType type) => bytes.addAll([0x04, type.code]);
  void elseClause() => bytes.add(0x05);
  void end() => bytes.add(0x0b);
  void branch(int depth) => bytes.addAll([0x0c, ..._unsignedLeb128(depth)]);
  void branchIf(int depth) => bytes.addAll([0x0d, ..._unsignedLeb128(depth)]);
  void returnValue() => bytes.add(0x0f);
  void call(int functionIndex) =>
      bytes.addAll([0x10, ..._unsignedLeb128(functionIndex)]);
  void drop() => bytes.add(0x1a);
  void localGet(int index) => bytes.addAll([0x20, ..._unsignedLeb128(index)]);
  void localSet(int index) => bytes.addAll([0x21, ..._unsignedLeb128(index)]);
  void localTee(int index) => bytes.addAll([0x22, ..._unsignedLeb128(index)]);
  void i32Load({int alignment = 2, int offset = 0}) => bytes.addAll([
    0x28,
    ..._unsignedLeb128(alignment),
    ..._unsignedLeb128(offset),
  ]);
  void i32Load8Unsigned({int offset = 0}) =>
      bytes.addAll([0x2d, 0, ..._unsignedLeb128(offset)]);
  void i32Store({int alignment = 2, int offset = 0}) => bytes.addAll([
    0x36,
    ..._unsignedLeb128(alignment),
    ..._unsignedLeb128(offset),
  ]);
  void i32Const(int value) => bytes.addAll([0x41, ..._signedLeb128(value)]);
  void i64Const(int value) => bytes.addAll([0x42, ..._signedLeb128(value)]);
  void i32EqualZero() => bytes.add(0x45);
  void i32Equal() => bytes.add(0x46);
  void i32NotEqual() => bytes.add(0x47);
  void i32LessSigned() => bytes.add(0x48);
  void i32LessUnsigned() => bytes.add(0x49);
  void i32GreaterSigned() => bytes.add(0x4a);
  void i32GreaterUnsigned() => bytes.add(0x4b);
  void i32LessEqualSigned() => bytes.add(0x4c);
  void i32LessEqualUnsigned() => bytes.add(0x4d);
  void i32GreaterEqualSigned() => bytes.add(0x4e);
  void i32GreaterEqualUnsigned() => bytes.add(0x4f);
  void i64Equal() => bytes.add(0x51);
  void i32Add() => bytes.add(0x6a);
  void i32Subtract() => bytes.add(0x6b);
  void i32Multiply() => bytes.add(0x6c);
  void i32DivideSigned() => bytes.add(0x6d);
  void i32And() => bytes.add(0x71);
  void i32Or() => bytes.add(0x72);
  void i64Or() => bytes.add(0x84);
  void i64ShiftLeft() => bytes.add(0x86);
  void i64ShiftRightUnsigned() => bytes.add(0x88);
  void i32WrapI64() => bytes.add(0xa7);
  void i64ExtendI32Unsigned() => bytes.add(0xad);
}

List<int> _encodeFunctionBody(
  List<_WasmValueType> locals,
  List<int> instructions,
) {
  final declarations = <int>[
    ..._unsignedLeb128(locals.length),
    for (final local in locals) ...[1, local.code],
  ];
  final body = [...declarations, ...instructions, 0x0b];
  return [..._unsignedLeb128(body.length), ...body];
}

void _appendSection(List<int> module, int id, List<int> contents) {
  module.add(id);
  module.addAll(_unsignedLeb128(contents.length));
  module.addAll(contents);
}

List<int> _wasmName(String value) {
  final bytes = utf8.encode(value);
  return [..._unsignedLeb128(bytes.length), ...bytes];
}

List<int> _unsignedLeb128(int value) {
  if (value < 0) {
    _unsupported('Internal compiler error: negative unsigned LEB128 value.');
  }
  final bytes = <int>[];
  do {
    var next = value & 0x7f;
    value >>= 7;
    if (value != 0) {
      next |= 0x80;
    }
    bytes.add(next);
  } while (value != 0);
  return bytes;
}

List<int> _signedLeb128(int value) {
  final bytes = <int>[];
  var more = true;
  while (more) {
    var byte = value & 0x7f;
    value >>= 7;
    more =
        !((value == 0 && (byte & 0x40) == 0) ||
            (value == -1 && (byte & 0x40) != 0));
    if (more) {
      byte |= 0x80;
    }
    bytes.add(byte);
  }
  return bytes;
}

_WasmValueType _wasmValueType(_Type type) => switch (type) {
  _Type.intType || _Type.boolType => _WasmValueType.i32,
  _Type.bytesType => _WasmValueType.i64,
  _Type.voidType || _Type.neverType => _unsupported(
    'Internal compiler error: $type has no Wasm value type.',
  ),
};

_FunctionSignature _signatureFor(_Function function) {
  return _FunctionSignature(
    [
      for (final parameter in function.parameters)
        _wasmValueType(parameter.type),
    ],
    function.returnType == _Type.voidType
        ? null
        : _wasmValueType(function.returnType),
  );
}
