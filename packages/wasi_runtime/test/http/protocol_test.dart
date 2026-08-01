import 'dart:convert';

import 'package:test/test.dart';
import 'package:wasi_runtime/wasi_runtime.dart';

void main() {
  group('HTTP-over-WASI protocol', () {
    test('request envelope preserves metadata, headers, and binary body', () {
      final request = WasiHttpRequest(
        method: 'POST',
        path: '/items/42',
        query: 'draft=true',
        headers: const [
          WasiHttpHeader('content-type', 'application/octet-stream'),
          WasiHttpHeader('x-trace', 'abc'),
        ],
        body: const [0, 1, 127, 128, 255],
      );

      final decoded = WasiHttpProtocol.decodeRequest(
        WasiHttpProtocol.encodeRequest(request),
      );

      expect(decoded.method, 'POST');
      expect(decoded.path, '/items/42');
      expect(decoded.query, 'draft=true');
      expect(
        decoded.headers.map((header) => '${header.name}:${header.value}'),
        const ['content-type:application/octet-stream', 'x-trace:abc'],
      );
      expect(decoded.body, const [0, 1, 127, 128, 255]);
    });

    test('response envelope preserves status, headers, and text body', () {
      final response = WasiHttpResponse(
        status: 201,
        headers: const [WasiHttpHeader('content-type', 'application/json')],
        body: utf8.encode('{"created":true}'),
      );

      final decoded = WasiHttpProtocol.decodeResponse(
        WasiHttpProtocol.encodeResponse(response),
      );

      expect(decoded.status, 201);
      expect(decoded.header('Content-Type'), 'application/json');
      expect(utf8.decode(decoded.body), '{"created":true}');
    });

    test('unsupported versions fail with a stable protocol exception', () {
      final envelope = WasiHttpProtocol.encodeResponse(
        WasiHttpResponse(status: 204),
      );
      envelope[4] = 99;

      expect(
        () => WasiHttpProtocol.decodeResponse(envelope),
        throwsA(
          isA<WasiHttpProtocolException>().having(
            (error) => error.message,
            'message',
            contains('Unsupported HTTP-over-WASI protocol version 99'),
          ),
        ),
      );
    });

    test('truncated envelopes fail without leaking range errors', () {
      expect(
        () => WasiHttpProtocol.decodeRequest(const [0x44, 0x57]),
        throwsA(isA<WasiHttpProtocolException>()),
      );
    });

    test('body and envelope limits are enforced before execution', () {
      expect(
        () => WasiHttpProtocol.encodeRequest(
          WasiHttpRequest(
            method: 'POST',
            path: '/',
            body: List.filled(WasiHttpProtocol.maximumBodyBytes + 1, 0),
          ),
        ),
        throwsA(isA<WasiHttpProtocolException>()),
      );
    });
  });
}
