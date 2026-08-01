import '../artifacts/models.dart';
import '../runtime/api.dart';

typedef CompilationCacheClock = DateTime Function();

/// Bounded cache of engine-specific compiled modules.
///
/// Cached modules are immutable compilation products only. A caller must still
/// create a request-scoped WASI execution for every invocation.
final class CompiledModuleCache {
  CompiledModuleCache({
    required WasmEngine engine,
    this.maximumEntries = 128,
    this.maximumCachedBytes = 64 * 1024 * 1024,
    CompilationCacheClock? clock,
  }) : _engine = engine,
       _clock = clock ?? DateTime.now {
    if (maximumEntries < 1) {
      throw ArgumentError.value(
        maximumEntries,
        'maximumEntries',
        'must be positive',
      );
    }
    if (maximumCachedBytes < 1) {
      throw ArgumentError.value(
        maximumCachedBytes,
        'maximumCachedBytes',
        'must be positive',
      );
    }
  }

  final WasmEngine _engine;
  final CompilationCacheClock _clock;
  final int maximumEntries;
  final int maximumCachedBytes;
  final Map<_CacheKey, _CacheEntry> _entries = {};
  final Map<_CacheKey, Future<CompiledModule>> _compilations = {};
  int _cachedBytes = 0;

  int get entryCount => _entries.length;
  int get cachedBytes => _cachedBytes;

  /// Returns a compiled module, compiling concurrent cache misses only once.
  Future<CompiledModule> getOrCompile(WorkloadArtifact artifact) {
    final key = _CacheKey(artifact.id, _engine.compatibility);
    final entry = _entries[key];
    if (entry != null) {
      entry.lastUsed = _now();
      return Future.value(entry.module);
    }

    return _compilations.putIfAbsent(
      key,
      () => _compileAndCache(key, artifact),
    );
  }

  /// Removes entries that have not been used for at least [idleFor].
  void evictIdle(Duration idleFor) {
    if (idleFor.isNegative) {
      throw ArgumentError.value(idleFor, 'idleFor', 'must not be negative');
    }

    final now = _now();
    final expired = _entries.entries
        .where((entry) => now.difference(entry.value.lastUsed) >= idleFor)
        .map((entry) => entry.key)
        .toList();
    for (final key in expired) {
      _remove(key);
    }
  }

  Future<CompiledModule> _compileAndCache(
    _CacheKey key,
    WorkloadArtifact artifact,
  ) async {
    try {
      final module = await _engine.compile(artifact.bytes);
      if (artifact.size > maximumCachedBytes) {
        return module;
      }

      _evictFor(artifact.size);
      _entries[key] = _CacheEntry(
        module: module,
        bytes: artifact.size,
        lastUsed: _now(),
      );
      _cachedBytes += artifact.size;
      return module;
    } finally {
      _compilations.remove(key);
    }
  }

  void _evictFor(int incomingBytes) {
    while (_entries.length >= maximumEntries ||
        _cachedBytes + incomingBytes > maximumCachedBytes) {
      final oldest = _entries.entries.reduce(
        (oldest, candidate) =>
            candidate.value.lastUsed.isBefore(oldest.value.lastUsed)
            ? candidate
            : oldest,
      );
      _remove(oldest.key);
    }
  }

  void _remove(_CacheKey key) {
    final entry = _entries.remove(key);
    if (entry != null) {
      _cachedBytes -= entry.bytes;
    }
  }

  DateTime _now() => _clock().toUtc();
}

final class _CacheKey {
  const _CacheKey(this.artifactId, this.compatibility);

  final String artifactId;
  final EngineCompatibility compatibility;

  @override
  bool operator ==(Object other) =>
      other is _CacheKey &&
      artifactId == other.artifactId &&
      compatibility.engine == other.compatibility.engine &&
      compatibility.version == other.compatibility.version &&
      compatibility.wasiVersion == other.compatibility.wasiVersion;

  @override
  int get hashCode => Object.hash(
    artifactId,
    compatibility.engine,
    compatibility.version,
    compatibility.wasiVersion,
  );
}

final class _CacheEntry {
  _CacheEntry({
    required this.module,
    required this.bytes,
    required this.lastUsed,
  });

  final CompiledModule module;
  final int bytes;
  DateTime lastUsed;
}
