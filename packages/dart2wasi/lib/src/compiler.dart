// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Experimental boundary for a compiler that produces a WASI Preview 1 module
/// from a supported subset of Dart.
abstract interface class DartToWasiCompiler {
  Future<Uint8List> compile(Uri entrypoint);
}

/// Minimal compiler for the first Dart-to-WASI feasibility fixture.
///
/// It recognizes one `void main()` containing exactly one
/// `Wasi.stdout.write('constant text')` call. The output is a core WebAssembly
/// version 1 command module importing WASI `fd_write` and `proc_exit`.
final class MinimalDartToWasiCompiler implements DartToWasiCompiler {
  const MinimalDartToWasiCompiler();

  @override
  Future<Uint8List> compile(Uri entrypoint) async {
    if (!entrypoint.isScheme('file')) {
      throw UnsupportedDartFeatureException(
        'Only file entrypoints are supported during compiler feasibility.',
      );
    }
    return compileSource(await File.fromUri(entrypoint).readAsString());
  }

  /// Compiles [source] using the deliberately small PRD 04 guest subset.
  Uint8List compileSource(String source) {
    return _WasiModuleWriter(_SubsetParser(source).parse()).write();
  }
}

/// A Dart program uses syntax or libraries outside the supported guest subset.
final class UnsupportedDartFeatureException implements Exception {
  const UnsupportedDartFeatureException(this.message);

  final String message;

  @override
  String toString() => 'UnsupportedDartFeatureException: $message';
}

final class _WasiModuleWriter {
  _WasiModuleWriter(this._program);

  final _Program _program;
  final List<List<int>> _strings = [];

  Uint8List write() {
    final bytes = <int>[0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00];
    _section(bytes, 1, _types());
    _section(bytes, 2, _imports());
    _section(bytes, 3, _functions());
    _section(bytes, 5, [1, 0, 1]);
    _section(bytes, 7, _exports());
    _section(bytes, 10, _code());
    _section(bytes, 11, _data());
    return Uint8List.fromList(bytes);
  }

  List<int> _types() => [
    3 + _program.functions.length,
    0x60,
    4,
    0x7f,
    0x7f,
    0x7f,
    0x7f,
    1,
    0x7f,
    0x60,
    1,
    0x7f,
    0,
    0x60,
    0,
    0,
    for (final function in _program.functions) ...[
      0x60,
      function.parameters.length,
      ...List.filled(function.parameters.length, 0x7f),
      function.returnType == _Type.voidType ? 0 : 1,
      if (function.returnType != _Type.voidType) 0x7f,
    ],
  ];

  List<int> _functions() => [
    1 + _program.functions.length,
    2,
    for (var index = 0; index < _program.functions.length; index++) 3 + index,
  ];

  List<int> _imports() => [
    2,
    ..._name('wasi_snapshot_preview1'),
    ..._name('fd_write'),
    0,
    0,
    ..._name('wasi_snapshot_preview1'),
    ..._name('proc_exit'),
    0,
    1,
  ];

  List<int> _exports() => [
    2,
    ..._name('_start'),
    0,
    2,
    ..._name('memory'),
    2,
    0,
  ];

  List<int> _code() {
    final bodies = <List<int>>[_startBody()];
    for (final function in _program.functions) {
      bodies.add(_FunctionWriter(this, function).write());
    }
    final code = <int>[bodies.length];
    for (final body in bodies) {
      code.addAll(_unsigned(body.length));
      code.addAll(body);
    }
    return code;
  }

  List<int> _startBody() {
    final mainIndex = _program.functions.indexWhere(
      (value) => value.name == 'main',
    );
    return [0, 0x10, 3 + mainIndex, 0x41, 0, 0x10, 1, 0x0b];
  }

  int addString(String value) {
    _strings.add(utf8.encode(value));
    return _strings.length - 1;
  }

  int stringOffset(int index) =>
      8 + _strings.take(index).fold<int>(0, (sum, value) => sum + value.length);

  List<int> writeString(int index) {
    final text = _strings[index];
    return [
      0x41,
      0,
      0x41,
      ..._signed(stringOffset(index)),
      0x36,
      2,
      0,
      0x41,
      0,
      0x41,
      ..._signed(text.length),
      0x36,
      2,
      4,
      0x41,
      1,
      0x41,
      0,
      0x41,
      1,
      0x41,
      4,
      0x10,
      0,
      0x1a,
    ];
  }

  List<int> _data() => [
    _strings.length,
    for (var index = 0; index < _strings.length; index++) ...[
      0,
      0x41,
      ..._signed(stringOffset(index)),
      0x0b,
      ..._unsigned(_strings[index].length),
      ..._strings[index],
    ],
  ];
}

void _section(List<int> bytes, int id, List<int> contents) {
  bytes.add(id);
  bytes.addAll(_unsigned(contents.length));
  bytes.addAll(contents);
}

List<int> _name(String value) {
  final bytes = value.codeUnits;
  return [..._unsigned(bytes.length), ...bytes];
}

List<int> _unsigned(int value) {
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

List<int> _signed(int value) {
  final bytes = <int>[];
  var more = true;
  while (more) {
    var byte = value & 0x7f;
    value >>= 7;
    more =
        !((value == 0 && (byte & 0x40) == 0) ||
            (value == -1 && (byte & 0x40) != 0));
    if (more) byte |= 0x80;
    bytes.add(byte);
  }
  return bytes;
}

enum _Type { voidType, intType, boolType }

final class _Program {
  const _Program(this.functions);
  final List<_Function> functions;
}

final class _Function {
  const _Function(this.name, this.returnType, this.parameters, this.body);
  final String name;
  final _Type returnType;
  final List<_Parameter> parameters;
  final List<_Statement> body;
}

final class _Parameter {
  const _Parameter(this.name, this.type);
  final String name;
  final _Type type;
}

sealed class _Statement {}

final class _VariableStatement extends _Statement {
  _VariableStatement(this.name, this.type, this.value);
  final String name;
  final _Type type;
  final _Expression value;
}

final class _AssignStatement extends _Statement {
  _AssignStatement(this.name, this.value);
  final String name;
  final _Expression value;
}

final class _WriteStatement extends _Statement {
  _WriteStatement(this.value);
  final String value;
}

final class _ExpressionStatement extends _Statement {
  _ExpressionStatement(this.value);
  final _Expression value;
}

final class _ReturnStatement extends _Statement {
  _ReturnStatement(this.value);
  final _Expression? value;
}

final class _IfStatement extends _Statement {
  _IfStatement(this.condition, this.thenBody, this.elseBody);
  final _Expression condition;
  final List<_Statement> thenBody;
  final List<_Statement>? elseBody;
}

final class _WhileStatement extends _Statement {
  _WhileStatement(this.condition, this.body);
  final _Expression condition;
  final List<_Statement> body;
}

sealed class _Expression {}

final class _NumberExpression extends _Expression {
  _NumberExpression(this.value);
  final int value;
}

final class _BooleanExpression extends _Expression {
  _BooleanExpression(this.value);
  final bool value;
}

final class _VariableExpression extends _Expression {
  _VariableExpression(this.name);
  final String name;
}

final class _CallExpression extends _Expression {
  _CallExpression(this.name, this.arguments);
  final String name;
  final List<_Expression> arguments;
}

final class _UnaryExpression extends _Expression {
  _UnaryExpression(this.operator, this.value);
  final String operator;
  final _Expression value;
}

final class _BinaryExpression extends _Expression {
  _BinaryExpression(this.left, this.operator, this.right);
  final _Expression left;
  final String operator;
  final _Expression right;
}

final class _FunctionWriter {
  _FunctionWriter(this.module, this.function)
    : _functions = {
        for (var i = 0; i < module._program.functions.length; i++)
          module._program.functions[i].name: i,
      };
  final _WasiModuleWriter module;
  final _Function function;
  final Map<String, int> _functions;
  final Map<String, int> _locals = {};
  final List<_Type> _localTypes = [];

  List<int> write() {
    for (var i = 0; i < function.parameters.length; i++)
      _locals[function.parameters[i].name] = i;
    _collect(function.body);
    final code = <int>[];
    for (final statement in function.body) _statement(code, statement);
    code.add(0x0b);
    final declarations = _localTypes.isEmpty
        ? <int>[0]
        : <int>[1, ..._unsigned(_localTypes.length), 0x7f];
    return [...declarations, ...code];
  }

  void _collect(List<_Statement> statements) {
    for (final statement in statements) {
      if (statement case _VariableStatement(:final name)) {
        if (_locals.containsKey(name)) _unsupported('Duplicate local "$name".');
        _locals[name] = function.parameters.length + _localTypes.length;
        _localTypes.add(_Type.intType);
      } else if (statement case _IfStatement(
        :final thenBody,
        :final elseBody,
      )) {
        _collect(thenBody);
        if (elseBody != null) _collect(elseBody);
      } else if (statement case _WhileStatement(:final body))
        _collect(body);
    }
  }

  void _statement(List<int> code, _Statement statement) {
    switch (statement) {
      case _VariableStatement(:final name, :final value):
        _expression(code, value);
        code.addAll([0x21, ..._unsigned(_locals[name]!)]);
      case _AssignStatement(:final name, :final value):
        final local = _locals[name];
        if (local == null) _unsupported('Unknown local "$name".');
        _expression(code, value);
        code.addAll([0x21, ..._unsigned(local)]);
      case _WriteStatement(:final value):
        code.addAll(module.writeString(module.addString(value)));
      case _ExpressionStatement(:final value):
        _expression(code, value);
        if (_expressionType(value) != _Type.voidType) code.add(0x1a);
      case _ReturnStatement(:final value):
        if (value != null) _expression(code, value);
        code.add(0x0f);
      case _IfStatement(:final condition, :final thenBody, :final elseBody):
        _expression(code, condition);
        code.addAll([0x04, 0x40]);
        for (final child in thenBody) _statement(code, child);
        if (elseBody != null) {
          code.add(0x05);
          for (final child in elseBody) _statement(code, child);
        }
        code.add(0x0b);
      case _WhileStatement(:final condition, :final body):
        code.addAll([0x02, 0x40, 0x03, 0x40]);
        _expression(code, condition);
        code.addAll([0x45, 0x0d, 1]);
        for (final child in body) _statement(code, child);
        code.addAll([0x0c, 0, 0x0b, 0x0b]);
    }
  }

  void _expression(List<int> code, _Expression expression) {
    switch (expression) {
      case _NumberExpression(:final value):
        code.addAll([0x41, ..._signed(value)]);
      case _BooleanExpression(:final value):
        code.addAll([0x41, value ? 1 : 0]);
      case _VariableExpression(:final name):
        final local = _locals[name];
        if (local == null) _unsupported('Unknown local "$name".');
        code.addAll([0x20, ..._unsigned(local)]);
      case _CallExpression(:final name, :final arguments):
        final index = _functions[name];
        if (index == null) _unsupported('Unknown function "$name".');
        for (final argument in arguments) _expression(code, argument);
        code.addAll([0x10, ..._unsigned(3 + index)]);
      case _UnaryExpression(:final operator, :final value):
        if (operator == '-') code.addAll([0x41, 0]);
        _expression(code, value);
        code.add(operator == '-' ? 0x6b : 0x45);
      case _BinaryExpression(:final left, :final operator, :final right):
        _expression(code, left);
        _expression(code, right);
        code.add(_operator(operator));
    }
  }

  _Type _expressionType(_Expression expression) => switch (expression) {
    _CallExpression(:final name) =>
      module._program.functions[_functions[name]!].returnType,
    _BooleanExpression() ||
    _UnaryExpression(operator: '!') ||
    _BinaryExpression(
      operator: '==' || '!=' || '<' || '>' || '<=' || '>=',
    ) => _Type.boolType,
    _ => _Type.intType,
  };

  int _operator(String value) => switch (value) {
    '+' => 0x6a,
    '-' => 0x6b,
    '*' => 0x6c,
    '/' => 0x6d,
    '==' => 0x46,
    '!=' => 0x47,
    '<' => 0x48,
    '>' => 0x4a,
    '<=' => 0x4c,
    '>=' => 0x4e,
    '&&' => 0x71,
    '||' => 0x72,
    _ => _unsupported('Unsupported operator "$value".'),
  };
}

Never _unsupported(String message) =>
    throw UnsupportedDartFeatureException(message);

final class _SubsetParser {
  _SubsetParser(String source) : _tokens = _Lexer(source).scan();
  final List<_Token> _tokens;
  var _index = 0;

  _Program parse() {
    while (_match('import')) {
      final uri = _consumeString();
      if (uri != 'package:dart_wasi/dart_wasi.dart')
        _unsupported('Only package:dart_wasi/dart_wasi.dart may be imported.');
      _expect(';');
    }
    final functions = <_Function>[];
    while (!_atEnd) functions.add(_function());
    final mains = functions.where((value) => value.name == 'main').toList();
    if (mains.length != 1 ||
        mains.single.returnType != _Type.voidType ||
        mains.single.parameters.isNotEmpty) {
      _unsupported('Exactly one void main() entrypoint is required.');
    }
    return _Program(functions);
  }

  _Function _function() {
    final type = _type();
    final name = _consumeIdentifier();
    _expect('(');
    final parameters = <_Parameter>[];
    if (!_check(')')) {
      do {
        parameters.add(
          _Parameter(_consumeIdentifier(afterType: true), _lastType!),
        );
      } while (_match(','));
    }
    _expect(')');
    return _Function(name, type, parameters, _block());
  }

  _Type? _lastType;
  _Type _type() {
    if (_match('void')) return _Type.voidType;
    if (_match('int')) return _Type.intType;
    if (_match('bool')) return _Type.boolType;
    _unsupported('Expected a supported type (void, int, or bool).');
  }

  String _consumeIdentifier({bool afterType = false}) {
    if (afterType) {
      final type = _type();
      if (type == _Type.voidType)
        _unsupported('Parameters cannot have type void.');
      _lastType = type;
    }
    final token = _advance();
    if (token.kind != _TokenKind.identifier)
      _unsupported('Expected an identifier near "${token.lexeme}".');
    return token.lexeme;
  }

  List<_Statement> _block() {
    _expect('{');
    final values = <_Statement>[];
    while (!_check('}')) {
      if (_atEnd) _unsupported('Unterminated block.');
      values.add(_statement());
    }
    _expect('}');
    return values;
  }

  _Statement _statement() {
    if (_match('int') || _match('bool') || _match('var')) {
      final type = _previous.lexeme == 'bool' ? _Type.boolType : _Type.intType;
      final name = _consumeIdentifier();
      _expect('=');
      final value = _expression();
      _expect(';');
      return _VariableStatement(name, type, value);
    }
    if (_match('if')) {
      _expect('(');
      final condition = _expression();
      _expect(')');
      final thenBody = _block();
      final elseBody = _match('else') ? _block() : null;
      return _IfStatement(condition, thenBody, elseBody);
    }
    if (_match('while')) {
      _expect('(');
      final condition = _expression();
      _expect(')');
      return _WhileStatement(condition, _block());
    }
    if (_match('return')) {
      final value = _check(';') ? null : _expression();
      _expect(';');
      return _ReturnStatement(value);
    }
    if (_check('Wasi') &&
        _peek(1).lexeme == '.' &&
        _peek(2).lexeme == 'stdout' &&
        _peek(3).lexeme == '.') {
      _advance();
      _advance();
      _advance();
      _advance();
      _expect('write');
      _expect('(');
      final value = _consumeString();
      _expect(')');
      _expect(';');
      return _WriteStatement(value);
    }
    if (_peek().kind == _TokenKind.identifier && _peek(1).lexeme == '=') {
      final name = _advance().lexeme;
      _advance();
      final value = _expression();
      _expect(';');
      return _AssignStatement(name, value);
    }
    final value = _expression();
    _expect(';');
    return _ExpressionStatement(value);
  }

  _Expression _expression() => _binary(0);
  _Expression _binary(int minimum) {
    var left = _unary();
    while (_precedence(_peek().lexeme) >= minimum) {
      final op = _advance().lexeme;
      final precedence = _precedence(op);
      final right = _binary(precedence + 1);
      left = _BinaryExpression(left, op, right);
    }
    return left;
  }

  _Expression _unary() {
    if (_match('!') || _match('-'))
      return _UnaryExpression(_previous.lexeme, _unary());
    return _primary();
  }

  _Expression _primary() {
    if (_match('true')) return _BooleanExpression(true);
    if (_match('false')) return _BooleanExpression(false);
    if (_peek().kind == _TokenKind.number)
      return _NumberExpression(int.parse(_advance().lexeme));
    if (_peek().kind == _TokenKind.identifier) {
      final name = _advance().lexeme;
      if (_match('(')) {
        final args = <_Expression>[];
        if (!_check(')')) {
          do {
            args.add(_expression());
          } while (_match(','));
        }
        _expect(')');
        return _CallExpression(name, args);
      }
      return _VariableExpression(name);
    }
    if (_match('(')) {
      final value = _expression();
      _expect(')');
      return value;
    }
    _unsupported('Expected an expression near "${_peek().lexeme}".');
  }

  int _precedence(String value) => switch (value) {
    '||' => 1,
    '&&' => 2,
    '==' || '!=' => 3,
    '<' || '>' || '<=' || '>=' => 4,
    '+' || '-' => 5,
    '*' || '/' => 6,
    _ => -1,
  };
  bool _match(String value) {
    if (!_check(value)) return false;
    _advance();
    return true;
  }

  bool _check(String value) => !_atEnd && _peek().lexeme == value;
  void _expect(String value) {
    if (!_match(value))
      _unsupported('Expected "$value" near "${_peek().lexeme}".');
  }

  String _consumeString() {
    final token = _advance();
    if (token.kind != _TokenKind.string)
      _unsupported('Expected a string literal.');
    return token.lexeme;
  }

  _Token _advance() => _tokens[_index++];
  _Token _peek([int offset = 0]) =>
      _tokens[(_index + offset).clamp(0, _tokens.length - 1)];
  _Token get _previous => _tokens[_index - 1];
  bool get _atEnd => _peek().kind == _TokenKind.end;
}

enum _TokenKind { identifier, number, string, symbol, end }

final class _Token {
  const _Token(this.kind, this.lexeme);
  final _TokenKind kind;
  final String lexeme;
}

final class _Lexer {
  _Lexer(this.source);
  final String source;
  var index = 0;
  List<_Token> scan() {
    final tokens = <_Token>[];
    while (index < source.length) {
      final char = source[index];
      if (char.trim().isEmpty) {
        index++;
        continue;
      }
      if (char == '/' && _char(1) == '/') {
        while (index < source.length && source[index] != '\n') index++;
        continue;
      }
      if (_letter(char)) {
        final start = index++;
        while (index < source.length &&
            (_letter(source[index]) || _digit(source[index])))
          index++;
        tokens.add(
          _Token(_TokenKind.identifier, source.substring(start, index)),
        );
        continue;
      }
      if (_digit(char)) {
        final start = index++;
        while (index < source.length && _digit(source[index])) index++;
        tokens.add(_Token(_TokenKind.number, source.substring(start, index)));
        continue;
      }
      if (char == "'" || char == '"') {
        tokens.add(_Token(_TokenKind.string, _string(char)));
        continue;
      }
      final pair = '$char${_char(1)}';
      if (const {'==', '!=', '<=', '>=', '&&', '||'}.contains(pair)) {
        tokens.add(_Token(_TokenKind.symbol, pair));
        index += 2;
        continue;
      }
      if ('(){};,.=+-*/!<>'.contains(char)) {
        tokens.add(_Token(_TokenKind.symbol, char));
        index++;
        continue;
      }
      _unsupported('Unsupported character "$char".');
    }
    tokens.add(const _Token(_TokenKind.end, '<end>'));
    return tokens;
  }

  String _string(String quote) {
    index++;
    final output = StringBuffer();
    while (index < source.length && source[index] != quote) {
      if (source[index] != '\\') {
        output.write(source[index++]);
        continue;
      }
      index++;
      if (index >= source.length) _unsupported('Unterminated string escape.');
      switch (source[index++]) {
        case 'n':
          output.write('\n');
        case 'r':
          output.write('\r');
        case 't':
          output.write('\t');
        case '\\':
          output.write('\\');
        case "'":
          output.write("'");
        case '"':
          output.write('"');
        default:
          _unsupported('Unsupported string escape.');
      }
    }
    if (index >= source.length) _unsupported('Unterminated string.');
    index++;
    return output.toString();
  }

  String _char(int offset) =>
      index + offset < source.length ? source[index + offset] : '';
  bool _letter(String value) => RegExp(r'[A-Za-z_]').hasMatch(value);
  bool _digit(String value) => RegExp(r'[0-9]').hasMatch(value);
}
