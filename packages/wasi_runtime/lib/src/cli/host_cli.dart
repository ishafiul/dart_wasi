import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../artifacts/registry.dart';
import '../artifacts/repository.dart';
import '../engine/wasd_engine.dart';
import '../execution/compiled_module_cache.dart';
import '../execution/workload_executor.dart';
import '../http/dispatcher.dart';
import '../http/server.dart';
import '../runtime/api.dart';

/// Local command-line host for inspecting, running, and serving WASI workers.
final class DartWasiHostCli {
  const DartWasiHostCli({this.engine = const WasdEngine()});

  final WasmEngine engine;

  Future<int> run(
    List<String> arguments, {
    IOSink? output,
    IOSink? error,
  }) async {
    final stdoutSink = output ?? stdout;
    final stderrSink = error ?? stderr;
    if (arguments.length < 2) {
      stderrSink.writeln(_usage);
      return 64;
    }

    try {
      return switch (arguments.first) {
        'inspect' when arguments.length == 2 => await _inspect(
          File(arguments[1]),
          stdoutSink,
        ),
        'run' when arguments.length == 2 => await _run(
          File(arguments[1]),
          stdoutSink,
          stderrSink,
        ),
        'serve' => await _serve(
          arguments.skip(1).toList(),
          stdoutSink,
          stderrSink,
        ),
        _ => _usageError(stderrSink),
      };
    } on FileSystemException catch (exception) {
      stderrSink.writeln(exception.message);
      return 66;
    } on Object catch (exception) {
      stderrSink.writeln(exception);
      return 70;
    }
  }

  Future<int> _inspect(File artifactFile, IOSink output) async {
    final bytes = await artifactFile.readAsBytes();
    final module = await engine.compile(bytes);
    final compatibility = engine.compatibility;
    output.writeln('artifact: ${artifactFile.path}');
    output.writeln(
      'engine: ${compatibility.engine} ${compatibility.version} '
      '(${compatibility.wasiVersion})',
    );
    _writeExternalValues(
      output,
      'imports',
      module.imports,
      (value) => '${value.module}.${value.name} (${value.kind.name})',
    );
    _writeExternalValues(
      output,
      'exports',
      module.exports,
      (value) => '${value.name} (${value.kind.name})',
    );
    return 0;
  }

  Future<int> _run(File artifactFile, IOSink output, IOSink error) async {
    final module = await engine.compile(await artifactFile.readAsBytes());
    final result = await module.runWasi();
    output.write(utf8.decode(result.stdout, allowMalformed: true));
    error.write(utf8.decode(result.stderr, allowMalformed: true));
    return result.exitCode;
  }

  Future<int> _serve(
    List<String> arguments,
    IOSink output,
    IOSink error,
  ) async {
    final command = _parseServeArguments(arguments);
    if (command == null) {
      return _usageError(error);
    }

    final bytes = await command.artifact.readAsBytes();
    final registry = WorkloadRegistry(
      engine: engine,
      repository: InMemoryWorkloadRepository(),
    );
    final artifact = await registry.registerArtifact(Uint8List.fromList(bytes));
    await registry.createRevision(
      workloadName: command.workloadName,
      revision: 1,
      artifactId: artifact.id,
    );
    await registry.activate(command.workloadName, 1);
    final dispatcher = WasiHttpDispatcher(
      executor: WorkloadExecutor(
        registry: registry,
        cache: CompiledModuleCache(engine: engine),
      ),
      routes: [
        WasiHttpRoute(
          hostname: command.hostname,
          pathPrefix: command.pathPrefix,
          workloadName: command.workloadName,
        ),
      ],
    );
    final server = await HttpServer.bind(command.bindAddress, command.port);
    WasiHttpServer(dispatcher).serve(server);
    output.writeln(
      'Serving ${command.artifact.path} at '
      'http://${command.bindAddress.address}:${server.port}${command.pathPrefix}',
    );
    await Completer<void>().future;
    return 0;
  }
}

void _writeExternalValues<T>(
  IOSink output,
  String label,
  List<T> values,
  String Function(T value) format,
) {
  output.writeln('$label:');
  if (values.isEmpty) {
    output.writeln('  (none)');
    return;
  }
  for (final value in values) {
    output.writeln('  ${format(value)}');
  }
}

int _usageError(IOSink error) {
  error.writeln(_usage);
  return 64;
}

const _usage = '''Usage:
  dart_wasi_host inspect <worker.wasm>
  dart_wasi_host run <worker.wasm>
  dart_wasi_host serve <worker.wasm> [--host <hostname>] [--bind <address>] [--port <port>] [--path-prefix <path>] [--workload <name>]''';

_ServeCommand? _parseServeArguments(List<String> arguments) {
  if (arguments.isEmpty) {
    return null;
  }
  var hostname = 'localhost';
  var bindAddress = InternetAddress.loopbackIPv4;
  var port = 8080;
  var pathPrefix = '/';
  var workloadName = 'worker';
  for (var index = 1; index < arguments.length; index += 2) {
    if (index + 1 >= arguments.length) {
      return null;
    }
    final value = arguments[index + 1];
    switch (arguments[index]) {
      case '--host':
        hostname = value;
      case '--bind':
        final parsedAddress = InternetAddress.tryParse(value);
        if (parsedAddress == null) {
          return null;
        }
        bindAddress = parsedAddress;
      case '--port':
        port = int.tryParse(value) ?? -1;
      case '--path-prefix':
        pathPrefix = value;
      case '--workload':
        workloadName = value;
      default:
        return null;
    }
  }
  if (hostname.isEmpty ||
      port < 0 ||
      port > 65535 ||
      !pathPrefix.startsWith('/')) {
    return null;
  }
  return _ServeCommand(
    artifact: File(arguments.first),
    hostname: hostname,
    bindAddress: bindAddress,
    port: port,
    pathPrefix: pathPrefix,
    workloadName: workloadName,
  );
}

final class _ServeCommand {
  const _ServeCommand({
    required this.artifact,
    required this.hostname,
    required this.bindAddress,
    required this.port,
    required this.pathPrefix,
    required this.workloadName,
  });

  final File artifact;
  final String hostname;
  final InternetAddress bindAddress;
  final int port;
  final String pathPrefix;
  final String workloadName;
}
