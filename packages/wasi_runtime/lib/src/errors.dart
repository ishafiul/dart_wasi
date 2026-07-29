/// Base class for stable platform failures reported around the Wasm engine.
abstract class WasmException implements Exception {
  const WasmException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

/// The bytes are not a valid module accepted by the selected engine.
final class WasmValidationException extends WasmException {
  const WasmValidationException(super.message, {super.cause});
}

/// A module could not be instantiated with the supplied imports.
final class WasmInstantiationException extends WasmException {
  const WasmInstantiationException(super.message, {super.cause});
}

/// Imports could not be linked to a module.
final class WasmLinkException extends WasmException {
  const WasmLinkException(super.message, {super.cause});
}

/// Guest execution trapped.
final class WasmTrap extends WasmException {
  const WasmTrap(super.message, {super.cause});
}

/// A requested export is absent or has the wrong kind.
final class WasmExportException extends WasmException {
  const WasmExportException(super.message, {super.cause});
}

/// A Dart host callback failed while servicing a guest import.
final class WasmHostException extends WasmException {
  const WasmHostException(super.message, {super.cause});
}

/// Base class for artifact and workload-registry failures.
abstract class WorkloadException implements Exception {
  const WorkloadException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class ArtifactTooLargeException extends WorkloadException {
  const ArtifactTooLargeException({
    required this.actualBytes,
    required this.maximumBytes,
  }) : super('Artifact contains $actualBytes bytes; maximum is $maximumBytes.');

  final int actualBytes;
  final int maximumBytes;
}

final class ArtifactNotFoundException extends WorkloadException {
  ArtifactNotFoundException(String artifactId)
    : super('Artifact "$artifactId" was not found.');
}

final class ArtifactConflictException extends WorkloadException {
  ArtifactConflictException(String artifactId)
    : super('Artifact ID "$artifactId" already refers to different bytes.');
}

final class InvalidWorkloadNameException extends WorkloadException {
  InvalidWorkloadNameException(String name)
    : super('Workload name "$name" is invalid.');
}

final class RevisionNotFoundException extends WorkloadException {
  RevisionNotFoundException(String workloadName, int revision)
    : super('Revision $revision of workload "$workloadName" was not found.');
}

final class RevisionConflictException extends WorkloadException {
  RevisionConflictException(String workloadName, int revision)
    : super(
        'Revision $revision of workload "$workloadName" already refers to '
        'different content.',
      );
}

final class NoRollbackTargetException extends WorkloadException {
  NoRollbackTargetException(String workloadName)
    : super('Workload "$workloadName" has no previous active revision.');
}
