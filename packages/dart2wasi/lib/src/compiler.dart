library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_wasi/dart_wasi.dart';

part 'compiler/model.dart';
part 'compiler/parser.dart';
part 'compiler/semantic_validator.dart';
part 'compiler/wasm_encoder.dart';
part 'compiler/wasm_module_writer.dart';

/// Guest SDK version understood by this compiler.
const int supportedDartWasiGuestApiVersion = dartWasiGuestApiVersion;

/// Experimental boundary for a compiler that produces a WASI Preview 1 module
/// from a supported subset of Dart.
abstract interface class DartToWasiCompiler {
  Future<Uint8List> compile(Uri entrypoint);
}

/// Compiler for the deliberately restricted Dart WASI proof-of-concept subset.
final class MinimalDartToWasiCompiler implements DartToWasiCompiler {
  const MinimalDartToWasiCompiler();

  @override
  Future<Uint8List> compile(Uri entrypoint) async {
    if (!entrypoint.isScheme('file')) {
      throw const UnsupportedDartFeatureException(
        'Only file entrypoints are supported.',
      );
    }
    return compileSource(await File.fromUri(entrypoint).readAsString());
  }

  /// Compiles [source] using the supported PRD 4 and PRD 5 guest subset.
  Uint8List compileSource(String source) {
    final program = _SubsetParser(source).parse();
    final semantics = _SemanticValidator(program).validate();
    return _WasiModuleWriter(program, semantics).write();
  }
}

/// A Dart program uses syntax or libraries outside the supported guest subset.
final class UnsupportedDartFeatureException implements Exception {
  const UnsupportedDartFeatureException(this.message);

  final String message;

  @override
  String toString() => 'UnsupportedDartFeatureException: $message';
}

Never _unsupported(String message) {
  throw UnsupportedDartFeatureException(message);
}
