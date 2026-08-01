import 'package:test/test.dart';
import 'package:wasi_runtime/wasi_runtime.dart';

void main() {
  group('WasiTelemetry', () {
    test('bounds malformed UTF-8 logs after redaction', () {
      final telemetry = WasiTelemetry(
        maximumGuestLogBytes: 5,
        redactions: [RegExp('secret')],
      );

      telemetry.recordGuestStderr('request-1', [
        115,
        101,
        99,
        114,
        101,
        116,
        255,
      ]);

      expect(telemetry.guestLogs.single.correlationId, 'request-1');
      expect(telemetry.guestLogs.single.message, '[REDA');
      expect(telemetry.guestLogs.single.truncated, isTrue);
    });

    test('classifies platform failures into stable categories', () {
      expect(
        classifyWasiFailure(const WasmValidationException('bad module')),
        WasiFailureKind.compiler,
      );
      expect(
        classifyWasiFailure(const WasiHttpProtocolException('bad envelope')),
        WasiFailureKind.protocol,
      );
      expect(
        classifyWasiFailure(const WasmTrap('guest trap')),
        WasiFailureKind.guest,
      );
      expect(
        classifyWasiFailure(const WasmLinkException('missing import')),
        WasiFailureKind.engine,
      );
      expect(
        classifyWasiFailure(NoActiveRevisionException('worker')),
        WasiFailureKind.host,
      );
    });
  });
}
