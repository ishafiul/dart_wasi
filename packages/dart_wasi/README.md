# dart_wasi

Experimental guest-facing APIs for Dart programs compiled by `dart2wasi`.

The feasibility API provides `Wasi.stdout.write` for constant strings. It is a
compiler-recognized API and is not executable on the Dart VM.
