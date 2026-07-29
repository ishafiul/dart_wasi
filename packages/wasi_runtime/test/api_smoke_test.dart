import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:wasi_runtime/wasi_runtime.dart';

void main() {
  test('engine boundary supports dependency injection', () async {
    final engine = _FakeEngine();
    final module = await engine.compile(Uint8List(0));

    expect(engine.validate(Uint8List(0)), isTrue);
    expect(module.imports, isEmpty);
    expect(module.exports, isEmpty);
  });
}

final class _FakeEngine implements WasmEngine {
  @override
  EngineCompatibility get compatibility => const EngineCompatibility(
    engine: 'fake',
    version: '1',
    wasiVersion: 'preview1',
  );

  @override
  Future<CompiledModule> compile(Uint8List bytes) async => _FakeModule();

  @override
  bool validate(Uint8List bytes) => true;
}

final class _FakeModule implements CompiledModule {
  @override
  List<WasmExport> get exports => const [];

  @override
  List<WasmImport> get imports => const [];

  @override
  Future<WasmInstance> instantiate({
    Map<String, Map<String, HostFunction>> imports = const {},
  }) => throw UnimplementedError();

  @override
  Future<WasiExecutionResult> runWasi([
    WasiExecutionOptions options = const WasiExecutionOptions(),
  ]) => throw UnimplementedError();
}
