import 'dart:typed_data';

import 'package:wasd/wasd.dart' as wasd;

import '../errors.dart';
import '../runtime/api.dart';

/// WebAssembly/WASI engine backed exclusively by the public `wasd` API.
final class WasdEngine implements WasmEngine {
  const WasdEngine();

  @override
  EngineCompatibility get compatibility => const EngineCompatibility(
    engine: 'wasd',
    version: '0.3.0',
    wasiVersion: 'preview1',
  );

  @override
  bool validate(Uint8List bytes) {
    final ownedBytes = Uint8List.fromList(bytes);
    return wasd.WebAssembly.validate(ownedBytes.buffer);
  }

  @override
  Future<CompiledModule> compile(Uint8List bytes) async {
    final ownedBytes = Uint8List.fromList(bytes);
    if (!wasd.WebAssembly.validate(ownedBytes.buffer)) {
      throw const WasmValidationException(
        'The WebAssembly module failed validation.',
      );
    }

    try {
      final module = await wasd.WebAssembly.compile(ownedBytes.buffer);
      return _WasdCompiledModule(module);
    } on wasd.CompileError catch (error) {
      throw WasmValidationException(error.message, cause: error);
    } on Object catch (error) {
      throw WasmValidationException(
        'The WebAssembly module could not be compiled.',
        cause: error,
      );
    }
  }
}

final class _WasdCompiledModule implements CompiledModule {
  _WasdCompiledModule(this._module)
    : imports = List.unmodifiable(
        wasd.Module.imports(_module).map(
          (descriptor) => WasmImport(
            module: descriptor.module,
            name: descriptor.name,
            kind: _externalKind(descriptor.kind),
          ),
        ),
      ),
      exports = List.unmodifiable(
        wasd.Module.exports(_module).map(
          (descriptor) => WasmExport(
            name: descriptor.name,
            kind: _externalKind(descriptor.kind),
          ),
        ),
      );

  final wasd.Module _module;

  @override
  final List<WasmImport> imports;

  @override
  final List<WasmExport> exports;

  @override
  Future<WasmInstance> instantiate({
    Map<String, Map<String, HostFunction>> imports = const {},
  }) async {
    try {
      final instance = await wasd.WebAssembly.instantiateModule(
        _module,
        _wasdImports(imports),
      );
      return _WasdInstance(instance);
    } on wasd.LinkError catch (error) {
      throw WasmLinkException(error.message, cause: error);
    } on wasd.RuntimeError catch (error) {
      _throwExecutionFailure(error);
    } on Object catch (error) {
      if (error is WasmException) {
        rethrow;
      }
      throw WasmInstantiationException(
        'The WebAssembly module could not be instantiated.',
        cause: error,
      );
    }
  }

  @override
  Future<WasiExecutionResult> runWasi([
    WasiExecutionOptions options = const WasiExecutionOptions(),
  ]) async {
    final wasi = wasd.WASI(
      args: List.unmodifiable(options.arguments),
      env: Map.unmodifiable(options.environment),
      stdinData: List.unmodifiable(options.stdin),
      preopens: Map.unmodifiable(options.preopens),
      files: Map.unmodifiable(options.files),
      returnOnExit: true,
      version: wasd.WASIVersion.preview1,
    );

    try {
      final instance = await wasd.WebAssembly.instantiateModule(
        _module,
        wasi.imports,
      );
      return WasiExecutionResult(exitCode: wasi.start(instance));
    } on wasd.LinkError catch (error) {
      throw WasmLinkException(error.message, cause: error);
    } on wasd.RuntimeError catch (error) {
      _throwExecutionFailure(error);
    } on Object catch (error) {
      if (error is WasmException) {
        rethrow;
      }
      throw WasmInstantiationException(
        'The WASI command could not be instantiated or started.',
        cause: error,
      );
    }
  }
}

final class _WasdInstance implements WasmInstance {
  const _WasdInstance(this._instance);

  final wasd.Instance _instance;

  @override
  Object? invoke(String exportName, [List<Object?> arguments = const []]) {
    final export = _instance.exports[exportName];
    if (export is! wasd.FunctionImportExportValue) {
      throw WasmExportException(
        'Export "$exportName" is missing or is not a function.',
      );
    }

    try {
      return export.ref(List.unmodifiable(arguments));
    } on wasd.RuntimeError catch (error) {
      _throwExecutionFailure(error);
    } on Object catch (error) {
      if (error is WasmException) {
        rethrow;
      }
      throw WasmTrap('Guest execution failed.', cause: error);
    }
  }
}

wasd.Imports _wasdImports(Map<String, Map<String, HostFunction>> imports) => {
  for (final module in imports.entries)
    module.key: {
      for (final value in module.value.entries)
        value.key: wasd.ImportExportKind.function((arguments) {
          try {
            return value.value.call(arguments);
          } on Object catch (error) {
            throw WasmHostException(
              'Host function "${module.key}.${value.key}" failed.',
              cause: error,
            );
          }
        }),
    },
};

WasmExternalKind _externalKind(wasd.ImportExportKind kind) => switch (kind) {
  wasd.ImportExportKind.function => WasmExternalKind.function,
  wasd.ImportExportKind.global => WasmExternalKind.global,
  wasd.ImportExportKind.memory => WasmExternalKind.memory,
  wasd.ImportExportKind.table => WasmExternalKind.table,
  wasd.ImportExportKind.tag => WasmExternalKind.tag,
};

Never _throwExecutionFailure(wasd.RuntimeError error) {
  final cause = error.cause;
  if (cause is WasmHostException) {
    throw cause;
  }
  throw WasmTrap(error.message, cause: error);
}
