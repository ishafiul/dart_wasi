import 'dart:typed_data';

/// Engine version information recorded with derived artifact metadata.
final class EngineCompatibility {
  const EngineCompatibility({
    required this.engine,
    required this.version,
    required this.wasiVersion,
  });

  final String engine;
  final String version;
  final String wasiVersion;
}

/// Engine-neutral WebAssembly import or export kind.
enum WasmExternalKind { function, global, memory, table, tag }

/// Metadata for an imported WebAssembly value.
final class WasmImport {
  const WasmImport({
    required this.module,
    required this.name,
    required this.kind,
  });

  final String module;
  final String name;
  final WasmExternalKind kind;
}

/// Metadata for an exported WebAssembly value.
final class WasmExport {
  const WasmExport({required this.name, required this.kind});

  final String name;
  final WasmExternalKind kind;
}

/// Input used to create a request-scoped WASI Preview 1 context.
final class WasiExecutionOptions {
  const WasiExecutionOptions({
    this.arguments = const [],
    this.environment = const {},
    this.stdin = const [],
    this.preopens = const {},
    this.files = const {},
  });

  final List<String> arguments;
  final Map<String, String> environment;
  final List<int> stdin;
  final Map<String, String> preopens;
  final Map<String, Uint8List> files;
}

/// Result of running a WASI Preview 1 command module.
final class WasiExecutionResult {
  const WasiExecutionResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;

  /// Bytes written by the guest to WASI stdout.
  final Uint8List stdout;

  /// Bytes written by the guest to WASI stderr.
  final Uint8List stderr;
}

/// Compiles WebAssembly binaries through a replaceable engine adapter.
abstract interface class WasmEngine {
  EngineCompatibility get compatibility;

  bool validate(Uint8List bytes);

  Future<CompiledModule> compile(Uint8List bytes);
}

/// A compiled and validated WebAssembly module.
abstract interface class CompiledModule {
  List<WasmImport> get imports;
  List<WasmExport> get exports;

  Future<WasmInstance> instantiate({
    Map<String, Map<String, HostFunction>> imports = const {},
  });

  Future<WasiExecutionResult> runWasi([
    WasiExecutionOptions options = const WasiExecutionOptions(),
  ]);
}

/// A callable function supplied by the host.
abstract interface class HostFunction {
  Object? call(List<Object?> arguments);
}

/// A live instance of a compiled WebAssembly module.
abstract interface class WasmInstance {
  Object? invoke(String exportName, [List<Object?> arguments = const []]);
}
