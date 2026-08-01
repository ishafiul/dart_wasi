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
    final output = _BoundedOutput(options.maximumOutputBytes);
    final wasi = wasd.WASI(
      args: List.unmodifiable(options.arguments),
      env: Map.unmodifiable(options.environment),
      stdinData: List.unmodifiable(options.stdin),
      preopens: Map.unmodifiable(options.preopens),
      files: Map.unmodifiable(options.files),
      returnOnExit: true,
      stdoutSink: output.addStdout,
      stderrSink: output.addStderr,
      version: wasd.WASIVersion.preview1,
    );

    try {
      final instance = await wasd.WebAssembly.instantiateModule(
        _module,
        wasi.imports,
      );
      final exitCode = wasi.start(instance);
      if (output.exceeded) {
        throw WasiOutputLimitException(
          maximumBytes: options.maximumOutputBytes!,
        );
      }
      return WasiExecutionResult(
        exitCode: exitCode,
        stdout: output.stdout,
        stderr: output.stderr,
      );
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

final class _BoundedOutput {
  _BoundedOutput(this._maximumBytes);

  final int? _maximumBytes;
  final BytesBuilder _stdout = BytesBuilder(copy: false);
  final BytesBuilder _stderr = BytesBuilder(copy: false);
  int _writtenBytes = 0;
  bool exceeded = false;

  Uint8List get stdout => _stdout.toBytes();
  Uint8List get stderr => _stderr.toBytes();

  void addStdout(Uint8List bytes) => _add(_stdout, bytes);
  void addStderr(Uint8List bytes) => _add(_stderr, bytes);

  void _add(BytesBuilder destination, Uint8List bytes) {
    final maximumBytes = _maximumBytes;
    if (maximumBytes == null) {
      destination.add(bytes);
      return;
    }
    final remaining = maximumBytes - _writtenBytes;
    if (remaining <= 0) {
      exceeded = exceeded || bytes.isNotEmpty;
      return;
    }
    final retained = bytes.length <= remaining ? bytes.length : remaining;
    if (retained > 0) {
      destination.add(Uint8List.sublistView(bytes, 0, retained));
      _writtenBytes += retained;
    }
    if (retained != bytes.length) {
      exceeded = true;
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
