import 'dart:io';

import '../compiler.dart';

/// Command-line adapter for compiling one supported Dart guest to WASI.
final class Dart2WasiCli {
  const Dart2WasiCli({this.compiler = const MinimalDartToWasiCompiler()});

  final DartToWasiCompiler compiler;

  Future<int> run(List<String> arguments, {IOSink? error}) async {
    final stderrSink = error ?? stderr;
    final command = _parseCompileArguments(arguments);
    if (command == null) {
      stderrSink.writeln(_usage);
      return 64;
    }

    try {
      final output = await compiler.compile(command.entrypoint.absolute.uri);
      await command.output.writeAsBytes(output, flush: true);
      return 0;
    } on UnsupportedDartFeatureException catch (exception) {
      stderrSink.writeln(exception.message);
      return 65;
    } on FileSystemException catch (exception) {
      stderrSink.writeln(exception.message);
      return 66;
    }
  }
}

const _usage = 'Usage: dart2wasi compile <entrypoint.dart> -o <output.wasm>';

_CompileCommand? _parseCompileArguments(List<String> arguments) {
  if (arguments.length == 3 &&
      arguments[0] == 'compile' &&
      arguments[1] != '-o') {
    return null;
  }
  if (arguments.length == 4 &&
      arguments[0] == 'compile' &&
      arguments[2] == '-o') {
    return _CompileCommand(File(arguments[1]), File(arguments[3]));
  }
  // Keep the original compact invocation usable while scripts migrate.
  if (arguments.length == 2) {
    return _CompileCommand(File(arguments[0]), File(arguments[1]));
  }
  return null;
}

final class _CompileCommand {
  const _CompileCommand(this.entrypoint, this.output);

  final File entrypoint;
  final File output;
}
