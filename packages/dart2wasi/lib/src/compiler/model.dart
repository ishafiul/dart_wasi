part of '../compiler.dart';

enum _Type {
  voidType,
  intType,
  boolType,
  bytesType,
  httpRequestType,
  httpResponseType,
  neverType,
}

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

final class _MemberExpression extends _Expression {
  _MemberExpression(this.receiver, this.member, this.arguments);

  final _Expression receiver;
  final String member;

  /// Null for a property access and non-null for a method invocation.
  final List<_Expression>? arguments;
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

enum _WasiIntrinsic {
  stdoutWriteConstant,
  stdoutWriteBytes,
  stderrWriteConstant,
  stderrWriteBytes,
  stdinReadAll,
  argumentsLength,
  argumentAt,
  environmentContains,
  environmentValueOr,
  httpResponseJson,
  httpResponseText,
  httpResponseBinary,
  exit,
}

final class _IntrinsicExpression extends _Expression {
  _IntrinsicExpression(
    this.intrinsic, {
    this.arguments = const [],
    this.stringArguments = const [],
  });

  final _WasiIntrinsic intrinsic;
  final List<_Expression> arguments;
  final List<String> stringArguments;
}
