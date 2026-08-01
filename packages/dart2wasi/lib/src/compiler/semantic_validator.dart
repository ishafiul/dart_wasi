part of '../compiler.dart';

final class _ProgramSemantics {
  const _ProgramSemantics(this.functions);

  final Map<_Function, _FunctionSemantics> functions;
}

final class _FunctionSemantics {
  const _FunctionSemantics({
    required this.localIndices,
    required this.localTypes,
  });

  final Map<String, int> localIndices;
  final Map<String, _Type> localTypes;
}

final class _SemanticValidator {
  _SemanticValidator(this._program);

  final _Program _program;
  late final Map<String, _Function> _functions;

  _ProgramSemantics validate() {
    _functions = _collectFunctions();
    _validateEntrypoint();
    final semantics = <_Function, _FunctionSemantics>{};
    for (final function in _program.functions) {
      semantics[function] = _validateFunction(function);
    }
    return _ProgramSemantics(Map.unmodifiable(semantics));
  }

  Map<String, _Function> _collectFunctions() {
    const reservedNames = {
      _fdWriteImport,
      _fdReadImport,
      _argsSizesGetImport,
      _argsGetImport,
      _environSizesGetImport,
      _environGetImport,
      _procExitImport,
    };
    final functions = <String, _Function>{};
    for (final function in _program.functions) {
      if (reservedNames.contains(function.name)) {
        _unsupported(
          'Function name "${function.name}" is reserved by the WASI runtime.',
        );
      }
      if (functions.containsKey(function.name)) {
        _unsupported('Duplicate function "${function.name}".');
      }
      functions[function.name] = function;
    }
    return functions;
  }

  void _validateEntrypoint() {
    final main = _functions['main'];
    if (main == null ||
        main.returnType != _Type.voidType ||
        main.parameters.isNotEmpty) {
      _unsupported('Exactly one void main() entrypoint is required.');
    }
  }

  _FunctionSemantics _validateFunction(_Function function) {
    final localIndices = <String, int>{};
    final localTypes = <String, _Type>{};
    for (var index = 0; index < function.parameters.length; index++) {
      final parameter = function.parameters[index];
      _addLocal(
        parameter.name,
        parameter.type,
        index,
        localIndices,
        localTypes,
      );
    }
    _collectLocalDeclarations(
      function.body,
      function.parameters.length,
      localIndices,
      localTypes,
    );
    final context = _ValidationContext(
      function: function,
      functions: _functions,
      localTypes: {
        for (final parameter in function.parameters)
          parameter.name: parameter.type,
      },
    );
    _validateStatements(function.body, context);
    if (function.returnType != _Type.voidType &&
        !_definitelyTerminates(function.body)) {
      _unsupported(
        'Function "${function.name}" must return '
        '${_typeName(function.returnType)} value on every path.',
      );
    }
    return _FunctionSemantics(
      localIndices: Map.unmodifiable(localIndices),
      localTypes: Map.unmodifiable(localTypes),
    );
  }

  int _collectLocalDeclarations(
    List<_Statement> statements,
    int nextIndex,
    Map<String, int> localIndices,
    Map<String, _Type> localTypes,
  ) {
    var index = nextIndex;
    for (final statement in statements) {
      switch (statement) {
        case _VariableStatement(:final name, :final type):
          _addLocal(name, type, index++, localIndices, localTypes);
        case _IfStatement(:final thenBody, :final elseBody):
          index = _collectLocalDeclarations(
            thenBody,
            index,
            localIndices,
            localTypes,
          );
          if (elseBody != null) {
            index = _collectLocalDeclarations(
              elseBody,
              index,
              localIndices,
              localTypes,
            );
          }
        case _WhileStatement(:final body):
          index = _collectLocalDeclarations(
            body,
            index,
            localIndices,
            localTypes,
          );
        default:
          break;
      }
    }
    return index;
  }

  void _addLocal(
    String name,
    _Type type,
    int index,
    Map<String, int> localIndices,
    Map<String, _Type> localTypes,
  ) {
    if (localIndices.containsKey(name)) {
      _unsupported('Duplicate parameter or local "$name".');
    }
    localIndices[name] = index;
    localTypes[name] = type;
  }

  void _validateStatements(
    List<_Statement> statements,
    _ValidationContext context,
  ) {
    for (final statement in statements) {
      switch (statement) {
        case _VariableStatement(:final name, :final type, :final value):
          _requireType(value, type, context, 'Initializer for "$name"');
          context.localTypes[name] = type;
        case _AssignStatement(:final name, :final value):
          final type = context.localTypes[name];
          if (type == null) {
            _unsupported('Unknown local "$name".');
          }
          _requireType(value, type, context, 'Assignment to "$name"');
        case _ExpressionStatement(:final value):
          _expressionType(value, context);
        case _ReturnStatement(:final value):
          _validateReturn(value, context);
        case _IfStatement(:final condition, :final thenBody, :final elseBody):
          _requireType(condition, _Type.boolType, context, 'If condition');
          _validateStatements(thenBody, context.child());
          if (elseBody != null) {
            _validateStatements(elseBody, context.child());
          }
        case _WhileStatement(:final condition, :final body):
          _requireType(condition, _Type.boolType, context, 'While condition');
          _validateStatements(body, context.child());
      }
    }
  }

  void _validateReturn(_Expression? value, _ValidationContext context) {
    final returnType = context.function.returnType;
    if (returnType == _Type.voidType) {
      if (value != null) {
        _unsupported(
          'Void function "${context.function.name}" cannot return a value.',
        );
      }
      return;
    }
    if (value == null) {
      _unsupported(
        'Function "${context.function.name}" must return '
        '${_typeName(returnType)} value.',
      );
    }
    _requireType(value, returnType, context, 'Return value');
  }

  void _requireType(
    _Expression expression,
    _Type expected,
    _ValidationContext context,
    String subject,
  ) {
    final actual = _expressionType(expression, context);
    if (actual != expected && actual != _Type.neverType) {
      _unsupported(
        '$subject must be ${_typeName(expected)}, not ${_typeName(actual)}.',
      );
    }
  }

  _Type _expressionType(_Expression expression, _ValidationContext context) {
    return switch (expression) {
      _NumberExpression() => _Type.intType,
      _BooleanExpression() => _Type.boolType,
      _VariableExpression(:final name) =>
        context.localTypes[name] ?? _unknownLocal(name),
      _CallExpression(:final name, :final arguments) => _callType(
        name,
        arguments,
        context,
      ),
      _UnaryExpression(:final operator, :final value) => _unaryType(
        operator,
        value,
        context,
      ),
      _BinaryExpression(:final left, :final operator, :final right) =>
        _binaryType(left, operator, right, context),
      _IntrinsicExpression() => _intrinsicType(expression, context),
    };
  }

  _Type _unknownLocal(String name) {
    _unsupported('Unknown local "$name".');
  }

  _Type _callType(
    String name,
    List<_Expression> arguments,
    _ValidationContext context,
  ) {
    final function = context.functions[name];
    if (function == null) {
      _unsupported('Unknown function "$name".');
    }
    if (arguments.length != function.parameters.length) {
      _unsupported(
        'Function "$name" expects ${function.parameters.length} arguments, '
        'but received ${arguments.length}.',
      );
    }
    for (var index = 0; index < arguments.length; index++) {
      _requireType(
        arguments[index],
        function.parameters[index].type,
        context,
        'Argument ${index + 1} of "$name"',
      );
    }
    return function.returnType;
  }

  _Type _unaryType(
    String operator,
    _Expression value,
    _ValidationContext context,
  ) {
    final requiredType = operator == '!' ? _Type.boolType : _Type.intType;
    _requireType(value, requiredType, context, 'Operand of "$operator"');
    return requiredType;
  }

  _Type _binaryType(
    _Expression left,
    String operator,
    _Expression right,
    _ValidationContext context,
  ) {
    if (operator == '&&' || operator == '||') {
      _requireType(
        left,
        _Type.boolType,
        context,
        'Left operand of "$operator"',
      );
      _requireType(
        right,
        _Type.boolType,
        context,
        'Right operand of "$operator"',
      );
      return _Type.boolType;
    }
    _requireType(left, _Type.intType, context, 'Left operand of "$operator"');
    _requireType(right, _Type.intType, context, 'Right operand of "$operator"');
    return const {'==', '!=', '<', '>', '<=', '>='}.contains(operator)
        ? _Type.boolType
        : _Type.intType;
  }

  _Type _intrinsicType(
    _IntrinsicExpression expression,
    _ValidationContext context,
  ) {
    switch (expression.intrinsic) {
      case _WasiIntrinsic.stdoutWriteConstant:
      case _WasiIntrinsic.stderrWriteConstant:
        return _Type.voidType;
      case _WasiIntrinsic.stdoutWriteBytes:
      case _WasiIntrinsic.stderrWriteBytes:
        _requireType(
          expression.arguments.single,
          _Type.bytesType,
          context,
          'writeBytes argument',
        );
        return _Type.voidType;
      case _WasiIntrinsic.stdinReadAll:
      case _WasiIntrinsic.argumentAt:
      case _WasiIntrinsic.environmentValueOr:
        if (expression.intrinsic == _WasiIntrinsic.argumentAt) {
          _requireType(
            expression.arguments.single,
            _Type.intType,
            context,
            'Argument index',
          );
        }
        return _Type.bytesType;
      case _WasiIntrinsic.argumentsLength:
        return _Type.intType;
      case _WasiIntrinsic.environmentContains:
        return _Type.boolType;
      case _WasiIntrinsic.exit:
        _requireType(
          expression.arguments.single,
          _Type.intType,
          context,
          'Exit code',
        );
        return _Type.neverType;
    }
  }

  bool _definitelyTerminates(List<_Statement> statements) {
    for (final statement in statements) {
      if (_statementTerminates(statement)) {
        return true;
      }
    }
    return false;
  }

  bool _statementTerminates(_Statement statement) {
    return switch (statement) {
      _ReturnStatement() => true,
      _ExpressionStatement(
        value: _IntrinsicExpression(intrinsic: _WasiIntrinsic.exit),
      ) =>
        true,
      _IfStatement(:final thenBody, :final elseBody) =>
        elseBody != null &&
            _definitelyTerminates(thenBody) &&
            _definitelyTerminates(elseBody),
      _ => false,
    };
  }

  String _typeName(_Type type) => switch (type) {
    _Type.voidType => 'void',
    _Type.intType => 'int',
    _Type.boolType => 'bool',
    _Type.bytesType => 'WasiBytes',
    _Type.neverType => 'Never',
  };
}

final class _ValidationContext {
  const _ValidationContext({
    required this.function,
    required this.functions,
    required this.localTypes,
  });

  final _Function function;
  final Map<String, _Function> functions;
  final Map<String, _Type> localTypes;

  _ValidationContext child() {
    return _ValidationContext(
      function: function,
      functions: functions,
      localTypes: Map.of(localTypes),
    );
  }
}
