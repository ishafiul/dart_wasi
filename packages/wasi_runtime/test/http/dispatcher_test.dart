import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:wasi_runtime/wasi_runtime.dart';

void main() {
  group('WasiHttpDispatcher', () {
    test('routes a matching host and path to its active workload', () async {
      final dispatcher = await _dispatcher(
        response: WasiHttpResponse(status: 201, body: const [1, 2]),
      );

      final response = await dispatcher.dispatch(
        hostname: 'API.example.test',
        request: WasiHttpRequest(method: 'GET', path: '/v1/widgets'),
      );

      expect(response.status, 201);
      expect(response.body, orderedEquals([1, 2]));
    });

    test('returns 404 when no host and path route matches', () async {
      final dispatcher = await _dispatcher();

      final response = await dispatcher.dispatch(
        hostname: 'api.example.test',
        request: WasiHttpRequest(method: 'GET', path: '/missing'),
      );

      expect(response.status, 404);
    });

    test('serves dispatcher responses through a Dart HTTP server', () async {
      final dispatcher = await _dispatcher(
        response: WasiHttpResponse(status: 202, body: const [7, 8]),
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final subscription = WasiHttpServer(dispatcher).serve(server);
      addTearDown(() async {
        await subscription.cancel();
        await server.close(force: true);
      });

      final client = HttpClient()..findProxy = (_) => 'DIRECT';
      addTearDown(client.close);
      final request = await client.getUrl(
        Uri.http('127.0.0.1:${server.port}', '/v1/widgets'),
      );
      request.headers.host = 'api.example.test';
      final response = await request.close();

      expect(response.statusCode, 202);
      expect(
        await response.fold<List<int>>(
          [],
          (body, chunk) => body..addAll(chunk),
        ),
        orderedEquals([7, 8]),
      );
    });

    test(
      'maps guest and protocol failures to documented gateway statuses',
      () async {
        final invalidResponse = await _dispatcher(stdout: const [0]);
        final exited = await _dispatcher(exitCode: 1);
        final trapped = await _dispatcher(error: const WasmTrap('guest trap'));

        expect(
          (await invalidResponse.dispatch(
            hostname: 'api.example.test',
            request: WasiHttpRequest(method: 'GET', path: '/v1'),
          )).status,
          502,
        );
        expect(
          (await exited.dispatch(
            hostname: 'api.example.test',
            request: WasiHttpRequest(method: 'GET', path: '/v1'),
          )).status,
          502,
        );
        expect(
          (await trapped.dispatch(
            hostname: 'api.example.test',
            request: WasiHttpRequest(method: 'GET', path: '/v1'),
          )).status,
          502,
        );
      },
    );

    test('maps timeout and cancellation at the execution boundary', () async {
      final pending = await _dispatcher(pending: true);

      final timedOut = await pending.dispatch(
        hostname: 'api.example.test',
        request: WasiHttpRequest(method: 'GET', path: '/v1'),
        timeout: Duration.zero,
      );
      final cancellation = WasiRequestCancellation()..cancel();
      final cancelled = await pending.dispatch(
        hostname: 'api.example.test',
        request: WasiHttpRequest(method: 'GET', path: '/v1'),
        cancellation: cancellation,
      );

      expect(timedOut.status, 504);
      expect(cancelled.status, 499);
    });

    test(
      'applies one shared concurrency limit across workload route aliases',
      () async {
        final gate = Completer<void>();
        final started = Completer<void>();
        final dispatcher = await _dispatcher(
          routes: [
            WasiHttpRoute(
              hostname: 'api.example.test',
              pathPrefix: '/v1',
              workloadName: 'worker',
            ),
            WasiHttpRoute(
              hostname: 'api.example.test',
              pathPrefix: '/alias',
              workloadName: 'worker',
            ),
          ],
          onRun: (_) async {
            started.complete();
            await gate.future;
            return _resultFor(WasiHttpResponse(status: 200));
          },
        );

        final first = dispatcher.dispatch(
          hostname: 'api.example.test',
          request: WasiHttpRequest(method: 'GET', path: '/v1'),
        );
        await started.future;
        final overloaded = await dispatcher.dispatch(
          hostname: 'api.example.test',
          request: WasiHttpRequest(method: 'GET', path: '/alias'),
        );
        gate.complete();

        expect(overloaded.status, 503);
        expect((await first).status, 200);
      },
    );
  });
}

Future<WasiHttpDispatcher> _dispatcher({
  WasiHttpResponse? response,
  List<int>? stdout,
  int exitCode = 0,
  Object? error,
  bool pending = false,
  List<WasiHttpRoute>? routes,
  Future<WasiExecutionResult> Function(WasiExecutionOptions)? onRun,
}) async {
  final engine = _FakeEngine(
    onRun:
        onRun ??
        (_) {
          if (error != null) {
            return Future.error(error);
          }
          if (pending) {
            return Completer<WasiExecutionResult>().future;
          }
          return Future.value(
            _resultFor(
              response ?? WasiHttpResponse(status: 200),
              stdout: stdout,
              exitCode: exitCode,
            ),
          );
        },
  );
  final registry = WorkloadRegistry(
    engine: engine,
    repository: InMemoryWorkloadRepository(),
  );
  final artifact = await registry.registerArtifact(Uint8List.fromList([1]));
  await registry.createRevision(
    workloadName: 'worker',
    revision: 1,
    artifactId: artifact.id,
  );
  await registry.activate('worker', 1);
  return WasiHttpDispatcher(
    executor: WorkloadExecutor(
      registry: registry,
      cache: CompiledModuleCache(engine: engine),
    ),
    routes:
        routes ??
        [
          WasiHttpRoute(
            hostname: 'api.example.test',
            pathPrefix: '/v1',
            workloadName: 'worker',
          ),
        ],
  );
}

WasiExecutionResult _resultFor(
  WasiHttpResponse response, {
  List<int>? stdout,
  int exitCode = 0,
}) => WasiExecutionResult(
  exitCode: exitCode,
  stdout: Uint8List.fromList(
    stdout ?? WasiHttpProtocol.encodeResponse(response),
  ),
  stderr: Uint8List(0),
);

final class _FakeEngine implements WasmEngine {
  const _FakeEngine({required this.onRun});

  final Future<WasiExecutionResult> Function(WasiExecutionOptions) onRun;

  @override
  EngineCompatibility get compatibility => const EngineCompatibility(
    engine: 'fake',
    version: '1.0.0',
    wasiVersion: 'preview1',
  );

  @override
  Future<CompiledModule> compile(Uint8List bytes) async => _FakeModule(onRun);

  @override
  bool validate(Uint8List bytes) => true;
}

final class _FakeModule implements CompiledModule {
  const _FakeModule(this._onRun);

  final Future<WasiExecutionResult> Function(WasiExecutionOptions) _onRun;

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
  ]) => _onRun(options);
}
