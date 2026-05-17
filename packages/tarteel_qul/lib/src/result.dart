import 'package:flutter/foundation.dart';

/// Why a [MushafResult] failed. Lets a consumer branch on the cause without
/// string-matching a message.
enum MushafFailureKind {
  /// A supplied database is missing an expected table or column, carries an
  /// unrecognised value, or `pages`/`words` is empty — the layout cannot be
  /// trusted to render.
  schema,

  /// A database failed to open, or a per-page font failed to load — an
  /// I/O-level fault rather than a structural one.
  dataAccess,

  /// A page number or [AyahKey] fell outside the loaded layout's bounds.
  outOfRange,
}

/// A structured failure surfaced by the engine instead of a thrown exception.
@immutable
class MushafFailure {
  const MushafFailure(this.kind, this.message);

  final MushafFailureKind kind;
  final String message;

  @override
  String toString() => 'MushafFailure(${kind.name}): $message';
}

/// Result of an engine operation that can fail at a real boundary (opening a
/// database, validating its schema, an out-of-range coordinate lookup).
sealed class MushafResult<T> {
  const MushafResult();

  const factory MushafResult.ok(T value) = MushafOk<T>;

  const factory MushafResult.err(MushafFailure failure) = MushafErr<T>;

  bool get isOk => this is MushafOk<T>;

  bool get isErr => this is MushafErr<T>;

  T? get valueOrNull => switch (this) {
    MushafOk<T>(:final value) => value,
    MushafErr<T>() => null,
  };

  MushafFailure? get failureOrNull => switch (this) {
    MushafOk<T>() => null,
    MushafErr<T>(:final failure) => failure,
  };

  R fold<R>({
    required R Function(T value) ok,
    required R Function(MushafFailure failure) err,
  }) => switch (this) {
    MushafOk<T>(:final value) => ok(value),
    MushafErr<T>(:final failure) => err(failure),
  };
}

final class MushafOk<T> extends MushafResult<T> {
  const MushafOk(this.value);

  final T value;
}

final class MushafErr<T> extends MushafResult<T> {
  const MushafErr(this.failure);

  final MushafFailure failure;
}
