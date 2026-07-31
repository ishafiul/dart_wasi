/// Version of the experimental Dart guest API contract.
///
/// Only stdout text output is supported during compiler feasibility work.
const int dartWasiGuestApiVersion = 1;

/// Guest APIs lowered by `dart2wasi` to WASI Preview 1 imports.
///
/// This class is a compile-time contract. It is not intended to execute on the
/// Dart VM; `dart2wasi` recognizes its supported calls and generates WASM.
abstract final class Wasi {
  static const stdout = WasiStdout._();
}

/// Standard output available to a WASI guest.
final class WasiStdout {
  const WasiStdout._();

  /// Writes [text] to WASI stdout when lowered by `dart2wasi`.
  void write(String text) {
    throw UnsupportedError(
      'Wasi.stdout.write can only run in a dart2wasi-compiled guest.',
    );
  }
}
