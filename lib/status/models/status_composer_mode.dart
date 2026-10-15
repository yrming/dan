/// How a status draft relates to an existing status.
enum StatusComposerMode {
  /// Compose a new, independent status.
  compose,

  /// Reply to the source status.
  reply,

  /// Repost the source status.
  repost,
}
