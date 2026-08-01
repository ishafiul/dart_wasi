part of '../compiler.dart';

final class _SubsetParser {
  _SubsetParser(String source) : _tokens = _Lexer(source).scan();

  final List<_Token> _tokens;
  var _index = 0;
  var _importsGuestSdk = false;
  var _usesGuestSdk = false;

  _Program parse() {
    _parseImports();
    final functions = <_Function>[];
    while (!_atEnd) {
      functions.add(_function());
    }
    if (_usesGuestSdk && !_importsGuestSdk) {
      _unsupported(
        'Guest APIs require import '
        "'package:dart_wasi/dart_wasi.dart'.",
      );
    }
    return _Program(functions);
  }

  void _parseImports() {
    while (_match('import')) {
      final uri = _consumeString();
      if (uri != 'package:dart_wasi/dart_wasi.dart') {
        _unsupported('Only package:dart_wasi/dart_wasi.dart may be imported.');
      }
      if (_importsGuestSdk) {
        _unsupported('The dart_wasi guest SDK may only be imported once.');
      }
      _importsGuestSdk = true;
      _expect(';');
    }
  }

  _Function _function() {
    final type = _type(allowVoid: true);
    final name = _consumeIdentifier();
    _expect('(');
    final parameters = <_Parameter>[];
    if (!_check(')')) {
      do {
        final parameterType = _type(allowVoid: false);
        parameters.add(_Parameter(_consumeIdentifier(), parameterType));
        if (!_match(',')) {
          break;
        }
      } while (!_check(')'));
    }
    _expect(')');
    return _Function(name, type, parameters, _block());
  }

  _Type _type({required bool allowVoid}) {
    if (allowVoid && _match('void')) {
      return _Type.voidType;
    }
    if (_match('int')) {
      return _Type.intType;
    }
    if (_match('bool')) {
      return _Type.boolType;
    }
    if (_match('WasiBytes')) {
      _usesGuestSdk = true;
      return _Type.bytesType;
    }
    if (_match('WasiHttpRequest')) {
      _usesGuestSdk = true;
      return _Type.httpRequestType;
    }
    if (_match('WasiHttpResponse')) {
      _usesGuestSdk = true;
      return _Type.httpResponseType;
    }
    final supported = allowVoid
        ? 'void, int, bool, WasiBytes, WasiHttpRequest, or WasiHttpResponse'
        : 'int, bool, WasiBytes, WasiHttpRequest, or WasiHttpResponse';
    _unsupported('Expected a supported type ($supported).');
  }

  List<_Statement> _block() {
    _expect('{');
    final values = <_Statement>[];
    while (!_check('}')) {
      if (_atEnd) {
        _unsupported('Unterminated block.');
      }
      values.add(_statement());
    }
    _expect('}');
    return values;
  }

  _Statement _statement() {
    if (_match('var')) {
      _unsupported('Use an explicit int, bool, or WasiBytes local type.');
    }
    if (_check('int') || _check('bool') || _check('WasiBytes')) {
      final type = _type(allowVoid: false);
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
      final operator = _advance().lexeme;
      final precedence = _precedence(operator);
      final right = _binary(precedence + 1);
      left = _BinaryExpression(left, operator, right);
    }
    return left;
  }

  _Expression _unary() {
    if (_match('!') || _match('-')) {
      return _UnaryExpression(_previous.lexeme, _unary());
    }
    return _primary();
  }

  _Expression _primary() {
    if (_match('true')) {
      return _BooleanExpression(true);
    }
    if (_match('false')) {
      return _BooleanExpression(false);
    }
    if (_peek().kind == _TokenKind.number) {
      return _NumberExpression(int.parse(_advance().lexeme));
    }
    if (_check('Wasi')) {
      return _wasiExpression();
    }
    if (_check('WasiHttpResponse')) {
      return _httpResponseExpression();
    }
    if (_peek().kind == _TokenKind.identifier) {
      final name = _advance().lexeme;
      late _Expression expression;
      if (_match('(')) {
        final arguments = _expressionArguments();
        expression = _CallExpression(name, arguments);
      } else {
        expression = _VariableExpression(name);
      }
      return _postfix(expression);
    }
    if (_match('(')) {
      final value = _expression();
      _expect(')');
      return value;
    }
    _unsupported('Expected an expression near "${_peek().lexeme}".');
  }

  _Expression _postfix(_Expression receiver) {
    var expression = receiver;
    while (_match('.')) {
      final member = _consumeIdentifier();
      final arguments = _match('(') ? _expressionArguments() : null;
      expression = _MemberExpression(expression, member, arguments);
    }
    return expression;
  }

  _Expression _httpResponseExpression() {
    _usesGuestSdk = true;
    _expect('WasiHttpResponse');
    _expect('.');
    final factory = _consumeIdentifier();
    _expect('(');
    final status = _expression();
    _expect(',');
    if (factory == 'json' || factory == 'text') {
      final body = _consumeString();
      _expectClosingParenthesis();
      return _IntrinsicExpression(
        factory == 'json'
            ? _WasiIntrinsic.httpResponseJson
            : _WasiIntrinsic.httpResponseText,
        arguments: [status],
        stringArguments: [body],
      );
    }
    if (factory == 'binary') {
      final body = _expression();
      _expect(',');
      final contentType = _consumeString();
      _expectClosingParenthesis();
      return _IntrinsicExpression(
        _WasiIntrinsic.httpResponseBinary,
        arguments: [status, body],
        stringArguments: [contentType],
      );
    }
    _unsupported('Unsupported guest API WasiHttpResponse.$factory.');
  }

  _Expression _wasiExpression() {
    _usesGuestSdk = true;
    _expect('Wasi');
    _expect('.');
    final area = _consumeIdentifier();
    if (area == 'exit') {
      _expect('(');
      final code = _expression();
      _expectClosingParenthesis();
      return _IntrinsicExpression(_WasiIntrinsic.exit, arguments: [code]);
    }

    _expect('.');
    final operation = _consumeIdentifier();
    return switch ((area, operation)) {
      ('stdout', 'write') => _constantWrite(_WasiIntrinsic.stdoutWriteConstant),
      ('stdout', 'writeBytes') => _singleExpressionIntrinsic(
        _WasiIntrinsic.stdoutWriteBytes,
      ),
      ('stderr', 'write') => _constantWrite(_WasiIntrinsic.stderrWriteConstant),
      ('stderr', 'writeBytes') => _singleExpressionIntrinsic(
        _WasiIntrinsic.stderrWriteBytes,
      ),
      ('stdin', 'readAll') => _noArgumentIntrinsic(_WasiIntrinsic.stdinReadAll),
      ('arguments', 'length') => _IntrinsicExpression(
        _WasiIntrinsic.argumentsLength,
      ),
      ('arguments', 'at') => _singleExpressionIntrinsic(
        _WasiIntrinsic.argumentAt,
      ),
      ('environment', 'contains') => _singleStringIntrinsic(
        _WasiIntrinsic.environmentContains,
      ),
      ('environment', 'valueOr') => _environmentValueOr(),
      _ => _unsupported('Unsupported guest API Wasi.$area.$operation.'),
    };
  }

  _IntrinsicExpression _constantWrite(_WasiIntrinsic intrinsic) {
    _expect('(');
    final value = _consumeString();
    _expectClosingParenthesis();
    return _IntrinsicExpression(intrinsic, stringArguments: [value]);
  }

  _IntrinsicExpression _singleExpressionIntrinsic(_WasiIntrinsic intrinsic) {
    _expect('(');
    final value = _expression();
    _expectClosingParenthesis();
    return _IntrinsicExpression(intrinsic, arguments: [value]);
  }

  _IntrinsicExpression _singleStringIntrinsic(_WasiIntrinsic intrinsic) {
    _expect('(');
    final value = _consumeString();
    _expectClosingParenthesis();
    return _IntrinsicExpression(intrinsic, stringArguments: [value]);
  }

  _IntrinsicExpression _environmentValueOr() {
    _expect('(');
    final name = _consumeString();
    _expect(',');
    final fallback = _consumeString();
    _expectClosingParenthesis();
    return _IntrinsicExpression(
      _WasiIntrinsic.environmentValueOr,
      stringArguments: [name, fallback],
    );
  }

  _IntrinsicExpression _noArgumentIntrinsic(_WasiIntrinsic intrinsic) {
    _expect('(');
    _expect(')');
    return _IntrinsicExpression(intrinsic);
  }

  List<_Expression> _expressionArguments() {
    final arguments = <_Expression>[];
    if (!_check(')')) {
      do {
        arguments.add(_expression());
        if (!_match(',')) {
          break;
        }
      } while (!_check(')'));
    }
    _expect(')');
    return arguments;
  }

  void _expectClosingParenthesis() {
    _match(',');
    _expect(')');
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
    if (!_check(value)) {
      return false;
    }
    _advance();
    return true;
  }

  bool _check(String value) => !_atEnd && _peek().lexeme == value;

  void _expect(String value) {
    if (!_match(value)) {
      _unsupported('Expected "$value" near "${_peek().lexeme}".');
    }
  }

  String _consumeString() {
    final token = _advance();
    if (token.kind != _TokenKind.string) {
      _unsupported('Expected a string literal.');
    }
    return token.lexeme;
  }

  String _consumeIdentifier() {
    final token = _advance();
    if (token.kind != _TokenKind.identifier) {
      _unsupported('Expected an identifier near "${token.lexeme}".');
    }
    return token.lexeme;
  }

  _Token _advance() => _tokens[_index++];

  _Token _peek([int offset = 0]) {
    return _tokens[(_index + offset).clamp(0, _tokens.length - 1)];
  }

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
  var _index = 0;

  List<_Token> scan() {
    final tokens = <_Token>[];
    while (_index < source.length) {
      final character = source[_index];
      if (character.trim().isEmpty) {
        _index++;
        continue;
      }
      if (character == '/' && _characterAt(1) == '/') {
        while (_index < source.length && source[_index] != '\n') {
          _index++;
        }
        continue;
      }
      if (_isLetter(character)) {
        tokens.add(_identifier());
        continue;
      }
      if (_isDigit(character)) {
        tokens.add(_number());
        continue;
      }
      if (character == "'" || character == '"') {
        tokens.add(_Token(_TokenKind.string, _string(character)));
        continue;
      }
      final pair = '$character${_characterAt(1)}';
      if (const {'==', '!=', '<=', '>=', '&&', '||'}.contains(pair)) {
        tokens.add(_Token(_TokenKind.symbol, pair));
        _index += 2;
        continue;
      }
      if ('(){};,.=+-*/!<>'.contains(character)) {
        tokens.add(_Token(_TokenKind.symbol, character));
        _index++;
        continue;
      }
      _unsupported('Unsupported character "$character".');
    }
    tokens.add(const _Token(_TokenKind.end, '<end>'));
    return tokens;
  }

  _Token _identifier() {
    final start = _index++;
    while (_index < source.length &&
        (_isLetter(source[_index]) || _isDigit(source[_index]))) {
      _index++;
    }
    return _Token(_TokenKind.identifier, source.substring(start, _index));
  }

  _Token _number() {
    final start = _index++;
    while (_index < source.length && _isDigit(source[_index])) {
      _index++;
    }
    return _Token(_TokenKind.number, source.substring(start, _index));
  }

  String _string(String quote) {
    _index++;
    final output = StringBuffer();
    while (_index < source.length && source[_index] != quote) {
      if (source[_index] != '\\') {
        output.write(source[_index++]);
        continue;
      }
      _index++;
      if (_index >= source.length) {
        _unsupported('Unterminated string escape.');
      }
      switch (source[_index++]) {
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
    if (_index >= source.length) {
      _unsupported('Unterminated string.');
    }
    _index++;
    return output.toString();
  }

  String _characterAt(int offset) {
    final target = _index + offset;
    return target < source.length ? source[target] : '';
  }

  bool _isLetter(String value) => RegExp(r'[A-Za-z_]').hasMatch(value);
  bool _isDigit(String value) => RegExp(r'[0-9]').hasMatch(value);
}
