# dart2wasi

Experimental compiler research for turning a deliberately small subset of Dart
into a standard WASI Preview 1 command module.

The first milestone is a Dart program that prints through
`wasi_snapshot_preview1.fd_write` when executed by `wasd`.

No compiler implementation exists yet.
