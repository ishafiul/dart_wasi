/// Version of the experimental Dart guest API contract.
const int dartWasiGuestApiVersion = 1;

/// Exit status used when the guest SDK detects invalid runtime data or limits.
const int dartWasiGuestRuntimeErrorExitCode = 70;

/// Version of the HTTP request/response envelope carried on stdin/stdout.
const int dartWasiHttpProtocolVersion = 1;

const String _compilerOnlyMessage =
    'This API can only run in a dart2wasi-compiled guest.';

/// Guest APIs lowered by `dart2wasi` to WASI Preview 1 imports.
///
/// These APIs describe a compile-time contract. They intentionally throw when
/// executed on the normal Dart VM.
abstract final class Wasi {
  static const stdout = WasiOutput._();
  static const stderr = WasiOutput._();
  static const stdin = WasiInput._();
  static const arguments = WasiArguments._();
  static const environment = WasiEnvironment._();

  /// Ends the guest command with [code].
  ///
  /// Version 1 accepts values from 0 through 255.
  static Never exit(int code) => throw UnsupportedError(_compilerOnlyMessage);
}

/// Opaque bytes owned by one compiled guest execution.
///
/// Version 1 allows this value to be stored, passed to supported functions,
/// returned, and written to a [WasiOutput]. It does not expose general list or
/// string operations.
final class WasiBytes {
  const WasiBytes._();
}

/// HTTP request decoded by a generated `fetch` entry-point adapter.
///
/// Text fields remain opaque UTF-8 bytes because the experimental compiler
/// does not provide general runtime `String` operations.
final class WasiHttpRequest {
  const WasiHttpRequest._();

  WasiBytes get method => throw UnsupportedError(_compilerOnlyMessage);
  WasiBytes get path => throw UnsupportedError(_compilerOnlyMessage);
  WasiBytes get query => throw UnsupportedError(_compilerOnlyMessage);
  WasiBytes get body => throw UnsupportedError(_compilerOnlyMessage);
  int get headerCount => throw UnsupportedError(_compilerOnlyMessage);

  WasiBytes headerNameAt(int index) {
    throw UnsupportedError(_compilerOnlyMessage);
  }

  WasiBytes headerValueAt(int index) {
    throw UnsupportedError(_compilerOnlyMessage);
  }
}

/// HTTP response returned by a supported guest `fetch` function.
final class WasiHttpResponse {
  const WasiHttpResponse._();

  /// Creates a UTF-8 JSON response with `application/json` content type.
  static WasiHttpResponse json(int status, String body) {
    throw UnsupportedError(_compilerOnlyMessage);
  }

  /// Creates a UTF-8 text response with `text/plain; charset=utf-8` content
  /// type.
  static WasiHttpResponse text(int status, String body) {
    throw UnsupportedError(_compilerOnlyMessage);
  }

  /// Creates a response that preserves [body] bytes exactly.
  ///
  /// [contentType] must be a compile-time UTF-8 string literal.
  static WasiHttpResponse binary(
    int status,
    WasiBytes body,
    String contentType,
  ) {
    throw UnsupportedError(_compilerOnlyMessage);
  }
}

/// Standard output or standard error available to a WASI guest.
final class WasiOutput {
  const WasiOutput._();

  /// Writes a compile-time UTF-8 string literal.
  void write(String text) => throw UnsupportedError(_compilerOnlyMessage);

  /// Writes [bytes] without decoding or changing them.
  void writeBytes(WasiBytes bytes) {
    throw UnsupportedError(_compilerOnlyMessage);
  }
}

/// Standard input available to a WASI guest.
final class WasiInput {
  const WasiInput._();

  /// Reads stdin through EOF into guest-owned bytes.
  ///
  /// Version 1 accepts at most 16 KiB. Exceeding that limit ends the guest with
  /// [dartWasiGuestRuntimeErrorExitCode].
  WasiBytes readAll() => throw UnsupportedError(_compilerOnlyMessage);
}

/// Command arguments supplied by the WASI host.
final class WasiArguments {
  const WasiArguments._();

  /// Number of arguments supplied by the host.
  int get length => throw UnsupportedError(_compilerOnlyMessage);

  /// Returns the UTF-8 bytes for the argument at [index].
  ///
  /// An invalid index ends the guest with
  /// [dartWasiGuestRuntimeErrorExitCode].
  WasiBytes at(int index) => throw UnsupportedError(_compilerOnlyMessage);
}

/// Environment entries supplied by the WASI host.
final class WasiEnvironment {
  const WasiEnvironment._();

  /// Whether an entry with the compile-time UTF-8 [name] exists.
  bool contains(String name) => throw UnsupportedError(_compilerOnlyMessage);

  /// Returns an entry's bytes or the compile-time UTF-8 [fallback].
  ///
  /// Both [name] and [fallback] must be string literals in SDK version 1.
  WasiBytes valueOr(String name, String fallback) {
    throw UnsupportedError(_compilerOnlyMessage);
  }
}
