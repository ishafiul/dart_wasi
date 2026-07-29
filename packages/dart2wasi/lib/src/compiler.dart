import 'dart:typed_data';

/// Experimental boundary for a compiler that produces a WASI Preview 1 module
/// from a supported subset of Dart.
abstract interface class DartToWasiCompiler {
  Future<Uint8List> compile(Uri entrypoint);
}

/// A Dart program uses syntax or libraries outside the supported guest subset.
final class UnsupportedDartFeatureException implements Exception {
  const UnsupportedDartFeatureException(this.message);

  final String message;

  @override
  String toString() => 'UnsupportedDartFeatureException: $message';
}
