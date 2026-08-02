import 'dart:io';

import 'package:dart2wasi/dart2wasi.dart';
import 'package:wasi_runtime/wasi_runtime.dart';

/// Starts a small multi-endpoint HTTP API backed by Dart-authored WASI workers.
///
/// Run with `dart run examples/http_api_server.dart`, then call:
///
/// - `GET /health`
/// - `POST /api/echo`
/// - `GET /api/info`
Future<void> main() async {
  const hostname = 'localhost';
  const port = 8080;
  final engine = const WasdEngine();
  final registry = WorkloadRegistry(
    engine: engine,
    repository: InMemoryWorkloadRepository(),
  );
  await _registerWorkers(registry);

  final dispatcher = WasiHttpDispatcher(
    executor: WorkloadExecutor(
      registry: registry,
      cache: CompiledModuleCache(engine: engine),
    ),
    routes: [
      for (final host in const ['localhost', '127.0.0.1']) ...[
        WasiHttpRoute(
          hostname: host,
          pathPrefix: '/health',
          workloadName: 'health',
        ),
        WasiHttpRoute(
          hostname: host,
          pathPrefix: '/api/echo',
          workloadName: 'echo',
        ),
        WasiHttpRoute(
          hostname: host,
          pathPrefix: '/api/info',
          workloadName: 'info',
        ),
      ],
    ],
  );
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  WasiHttpServer(dispatcher).serve(server);
  print('HTTP API listening on http://$hostname:$port');
}

Future<void> _registerWorkers(WorkloadRegistry registry) async {
  const compiler = MinimalDartToWasiCompiler();
  for (final worker in const ['health', 'echo', 'info']) {
    final bytes = await compiler.compile(
      File('examples/http_api/$worker.dart').absolute.uri,
    );
    final artifact = await registry.registerArtifact(bytes);
    await registry.createRevision(
      workloadName: worker,
      revision: 1,
      artifactId: artifact.id,
    );
    await registry.activate(worker, 1);
  }
}
